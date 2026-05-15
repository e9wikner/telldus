//
// Copyright (C) 2012 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "service/TelldusMain.h"
#include <stdio.h>
#include <list>
#include <memory>
#include <string>

#ifdef _LINUX
#include <sys/inotify.h>
#include <unistd.h>
#include <errno.h>
#include <libgen.h>
#endif

#include "service/config.h"

#include "common/EventHandler.h"
#include "service/ClientCommunicationHandler.h"
#include "service/ConnectionListener.h"
#include "service/ControllerListener.h"
#include "service/ControllerManager.h"
#include "service/DeviceManager.h"
#include "service/EventUpdateManager.h"
#include "service/Log.h"
#include "service/Timer.h"

class TelldusMain::PrivateData {
public:
	TelldusCore::EventHandler eventHandler;
	TelldusCore::EventRef stopEvent, controllerChangeEvent;
};

TelldusMain::TelldusMain(void) {
	d = new PrivateData;
	d->stopEvent = d->eventHandler.addEvent();
	d->controllerChangeEvent = d->eventHandler.addEvent();
}

TelldusMain::~TelldusMain(void) {
	delete d;
}

void TelldusMain::deviceInsertedOrRemoved(int vid, int pid, bool inserted) {
	ControllerChangeEventData *data = new ControllerChangeEventData;
	data->vid = vid;
	data->pid = pid;
	data->inserted = inserted;
	d->controllerChangeEvent->signal(data);
}

void TelldusMain::resume() {
	Log::notice("Came back from suspend");
	ControllerChangeEventData *data = new ControllerChangeEventData;
	data->vid = 0x0;
	data->pid = 0x0;
	data->inserted = true;
	d->controllerChangeEvent->signal(data);
}

void TelldusMain::suspend() {
	Log::notice("Preparing for suspend");
	ControllerChangeEventData *data = new ControllerChangeEventData;
	data->vid = 0x0;
	data->pid = 0x0;
	data->inserted = false;
	d->controllerChangeEvent->signal(data);
}

#ifdef _LINUX
class ConfigWatcher : public TelldusCore::Thread {
public:
	ConfigWatcher(TelldusCore::EventRef event, const std::string &configPath)
		: event_(event), configPath_(configPath), fd_(-1), wd_(-1), stop_(false) {}

	~ConfigWatcher() {
		stop_ = true;
		wait();
		if (fd_ >= 0) {
			close(fd_);
		}
	}

	void stop() { stop_ = true; }

	bool init() {
		fd_ = inotify_init1(IN_CLOEXEC | IN_NONBLOCK);
		if (fd_ < 0) {
			return false;
		}

		// Watch the parent directory to catch both edits and atomic replacements
		std::string dir = configPath_;
		size_t lastSlash = dir.find_last_of('/');
		if (lastSlash != std::string::npos) {
			filename_ = dir.substr(lastSlash + 1);
			dir = dir.substr(0, lastSlash);
		} else {
			filename_ = dir;
			dir = ".";
		}

		wd_ = inotify_add_watch(fd_, dir.c_str(), IN_CLOSE_WRITE | IN_MOVED_TO);
		if (wd_ < 0) {
			close(fd_);
			fd_ = -1;
			return false;
		}
		return true;
	}

protected:
	void run() {
		char buffer[4096];
		while (!stop_) {
			ssize_t len = read(fd_, buffer, sizeof(buffer));
			if (len < 0) {
				if (errno == EAGAIN || errno == EINTR) {
					usleep(100000);  // 100ms
					continue;
				}
				break;
			}

			bool relevant = false;
			for (char *ptr = buffer; ptr < buffer + len; ) {
				struct inotify_event *iev = reinterpret_cast<struct inotify_event *>(ptr);
				if (iev->wd == wd_ && filename_ == iev->name) {
					relevant = true;
				}
				ptr += sizeof(struct inotify_event) + iev->len;
			}

			if (relevant) {
				// Debounce: wait 1 second for writes to settle
				sleep(1);
				// Drain any additional events
				while (read(fd_, buffer, sizeof(buffer)) > 0) {}
				if (!stop_) {
					event_->signal();
				}
			}
		}
	}

private:
	TelldusCore::EventRef event_;
	std::string configPath_;
	std::string filename_;
	int fd_;
	int wd_;
	bool stop_;
};
#endif

void TelldusMain::start(void) {
	TelldusCore::EventRef clientEvent = d->eventHandler.addEvent();
	TelldusCore::EventRef dataEvent = d->eventHandler.addEvent();
	TelldusCore::EventRef executeActionEvent = d->eventHandler.addEvent();
	TelldusCore::EventRef janitor = d->eventHandler.addEvent();  // Used for regular cleanups
	Timer supervisor(janitor);  // Tells the janitor to go back to work
	supervisor.setInterval(60);  // Once every minute
	supervisor.start();

	EventUpdateManager eventUpdateManager;
	TelldusCore::EventRef deviceUpdateEvent = eventUpdateManager.retrieveUpdateEvent();
	eventUpdateManager.start();
	ControllerManager controllerManager(dataEvent, deviceUpdateEvent);
	DeviceManager deviceManager(&controllerManager, deviceUpdateEvent);
	deviceManager.setExecuteActionEvent(executeActionEvent);

	ConnectionListener clientListener(L"TelldusClient", clientEvent);

	std::list<ClientCommunicationHandler *> clientCommunicationHandlerList;

	TelldusCore::EventRef handlerEvent = d->eventHandler.addEvent();

#ifdef _MACOSX
	// This is only needed on OS X
	ControllerListener controllerListener(d->controllerChangeEvent);
#endif

#ifdef _LINUX
	TelldusCore::EventRef configReloadEvent = d->eventHandler.addEvent();
	std::string configPath;
	{
		const char *env = getenv("TELLDUS_CONFIG_FILE");
		configPath = env ? env : CONFIG_PATH "/tellstick.conf";
	}
	ConfigWatcher watcher(configReloadEvent, configPath);
	bool watcherOk = watcher.init();
	if (watcherOk) {
		watcher.start();
		Log::notice("Config auto-reload enabled for %s", configPath.c_str());
	} else {
		Log::warning("Config auto-reload not available: inotify initialization failed");
	}
#endif

	while(!d->stopEvent->isSignaled()) {
		if (!d->eventHandler.waitForAny()) {
			continue;
		}
		if (clientEvent->isSignaled()) {
			// New client connection
			TelldusCore::EventDataRef eventDataRef = clientEvent->takeSignal();
			ConnectionListenerEventData *data = dynamic_cast<ConnectionListenerEventData*>(eventDataRef.get());
			if (data) {
				ClientCommunicationHandler *clientCommunication = new ClientCommunicationHandler(data->socket, handlerEvent, &deviceManager, deviceUpdateEvent, &controllerManager);
				clientCommunication->start();
				clientCommunicationHandlerList.push_back(clientCommunication);
			}
		}

		if (d->controllerChangeEvent->isSignaled()) {
			TelldusCore::EventDataRef eventDataRef = d->controllerChangeEvent->takeSignal();
			ControllerChangeEventData *data = dynamic_cast<ControllerChangeEventData*>(eventDataRef.get());
			if (data) {
				controllerManager.deviceInsertedOrRemoved(data->vid, data->pid, "", data->inserted);
			}
		}

		if (dataEvent->isSignaled()) {
			TelldusCore::EventDataRef eventData = dataEvent->takeSignal();
			ControllerEventData *data = dynamic_cast<ControllerEventData*>(eventData.get());
			if (data) {
				deviceManager.handleControllerMessage(*data);
			}
		}

		if (handlerEvent->isSignaled()) {
			handlerEvent->popSignal();
			for ( std::list<ClientCommunicationHandler *>::iterator it = clientCommunicationHandlerList.begin(); it != clientCommunicationHandlerList.end(); ) {
				if ((*it)->isDone()) {
					delete *it;
					it = clientCommunicationHandlerList.erase(it);

				} else {
					++it;
				}
			}
		}
		if (executeActionEvent->isSignaled()) {
			deviceManager.executeActionEvent();
		}
		if (janitor->isSignaled()) {
			// Clear all of them if there is more than one
			while(janitor->isSignaled()) {
				janitor->popSignal();
			}
#ifndef _MACOSX
			controllerManager.queryControllerStatus();
#endif
		}
#ifdef _LINUX
		if (watcherOk && configReloadEvent->isSignaled()) {
			configReloadEvent->popSignal();
			Log::notice("Config file changed, reloading devices");
			deviceManager.reloadDevices();
		}
#endif
	}

#ifdef _LINUX
	if (watcherOk) {
		watcher.stop();
	}
#endif

	supervisor.stop();
}

void TelldusMain::stop(void) {
	d->stopEvent->signal();
}
