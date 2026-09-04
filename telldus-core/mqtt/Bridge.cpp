//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "mqtt/Bridge.h"

#include <mosquitto.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <vector>

#include "client/telldus-core.h"
#include "mqtt/Commands.h"
#include "mqtt/Discovery.h"

namespace TelldusMqtt {

namespace {

const char *kBridgeUniqueId = "telldus_bridge";
const char *kTelldusSocketPath = "/tmp/TelldusClient";

const int kAllQueriedMethods =
	TELLSTICK_TURNON | TELLSTICK_TURNOFF | TELLSTICK_BELL | TELLSTICK_DIM |
	TELLSTICK_UP | TELLSTICK_DOWN | TELLSTICK_STOP;

// Matches tdtool's DATA_LENGTH (telldus-core/tdtool/main.cpp): protocol,
// model and single-dataType values all fit comfortably in this.
const int kSensorFieldLength = 20;

const int kAllSensorDataTypes =
	TELLSTICK_TEMPERATURE | TELLSTICK_HUMIDITY | TELLSTICK_RAINRATE | TELLSTICK_RAINTOTAL |
	TELLSTICK_WINDDIRECTION | TELLSTICK_WINDAVERAGE | TELLSTICK_WINDGUST;

std::string releaseToString(char *value) {
	std::string result = value != nullptr ? value : "";
	if (value != nullptr) {
		tdReleaseString(value);
	}
	return result;
}

}  // namespace

Bridge::Bridge(const Config &config)
	: config_(config),
	  mosq_(nullptr),
	  stopRequested_(false),
	  deviceEventCallbackId_(-1),
	  deviceChangeEventCallbackId_(-1),
	  sensorEventCallbackId_(-1),
	  rawEventCallbackId_(-1) {
}

Bridge::~Bridge() {
}

void Bridge::requestStop() {
	stopRequested_ = true;
}

bool Bridge::waitForTelldusDaemon(int timeoutSeconds) const {
	struct stat st;
	for (int elapsed = 0; elapsed < timeoutSeconds; ++elapsed) {
		if (stat(kTelldusSocketPath, &st) == 0) {
			return true;
		}
		sleep(1);
	}
	return stat(kTelldusSocketPath, &st) == 0;
}

Device Bridge::fetchDevice(int deviceId) const {
	Device device;
	device.id = deviceId;
	device.name = releaseToString(tdGetName(deviceId));
	device.protocol = releaseToString(tdGetProtocol(deviceId));
	device.model = releaseToString(tdGetModel(deviceId));
	device.deviceType = tdGetDeviceType(deviceId);
	device.methods = tdMethods(deviceId, kAllQueriedMethods);
	return device;
}

void Bridge::enumerateDevices() {
	int count = tdGetNumberOfDevices();
	std::lock_guard<std::mutex> lock(devicesMutex_);
	devices_.clear();
	for (int i = 0; i < count; ++i) {
		int deviceId = tdGetDeviceId(i);
		devices_[deviceId] = fetchDevice(deviceId);
	}
}

void Bridge::seedSensors() {
	char protocol[kSensorFieldLength];
	char model[kSensorFieldLength];
	int id = 0;
	int dataTypes = 0;

	int status = tdSensor(protocol, kSensorFieldLength, model, kSensorFieldLength, &id, &dataTypes);
	while (status == TELLSTICK_SUCCESS) {
		for (int bit = 1; bit <= kAllSensorDataTypes; bit <<= 1) {
			if (!(dataTypes & bit & kAllSensorDataTypes)) {
				continue;
			}
			char value[kSensorFieldLength] = {0};
			int timestamp = 0;
			if (tdSensorValue(protocol, model, id, bit, value, kSensorFieldLength, &timestamp) != TELLSTICK_SUCCESS) {
				continue;
			}
			Sensor sensor;
			sensor.protocol = protocol;
			sensor.model = model;
			sensor.id = id;
			sensor.dataType = bit;
			std::lock_guard<std::mutex> lock(sensorsMutex_);
			sensors_[sensorObjectId(sensor)] = SensorState{sensor, value};
		}
		status = tdSensor(protocol, kSensorFieldLength, model, kSensorFieldLength, &id, &dataTypes);
	}
}

void Bridge::publishRetained(const std::string &topic, const std::string &payload) {
	mosquitto_publish(mosq_, nullptr, topic.c_str(), static_cast<int>(payload.size()),
		payload.empty() ? nullptr : payload.data(), config_.qos, true);
}

void Bridge::publishRaw(const std::string &topic, const std::string &payload) {
	mosquitto_publish(mosq_, nullptr, topic.c_str(), static_cast<int>(payload.size()),
		payload.empty() ? nullptr : payload.data(), config_.qos, false);
}

void Bridge::subscribeCommandTopics() {
	mosquitto_subscribe(mosq_, nullptr, (config_.topicPrefix + "/device/+/set").c_str(), config_.qos);
	mosquitto_subscribe(mosq_, nullptr, (config_.topicPrefix + "/device/+/brightness/set").c_str(), config_.qos);
	mosquitto_subscribe(mosq_, nullptr, (config_.topicPrefix + "/device/+/cover/set").c_str(), config_.qos);
}

void Bridge::publishDiscovery(const Device &device) {
	Component component = selectComponent(device);
	if (component == Component::Unknown) {
		return;
	}
	std::string payload = buildDiscoveryPayload(config_, device, kBridgeUniqueId);
	publishRetained(discoveryConfigTopic(config_, component, device.id), payload);
}

void Bridge::retractDiscovery(const Device &device) {
	Component component = selectComponent(device);
	if (component == Component::Unknown) {
		return;
	}
	publishRetained(discoveryConfigTopic(config_, component, device.id), "");
}

void Bridge::publishSeedState(const Device &device) {
	int lastSent = tdLastSentCommand(device.id, TELLSTICK_TURNON | TELLSTICK_TURNOFF | TELLSTICK_DIM);
	if (lastSent == TELLSTICK_TURNON) {
		publishRetained(deviceStateTopic(config_, device.id), "ON");
	} else if (lastSent == TELLSTICK_TURNOFF) {
		publishRetained(deviceStateTopic(config_, device.id), "OFF");
	} else if (lastSent == TELLSTICK_DIM) {
		std::string level = releaseToString(tdLastSentValue(device.id));
		publishRetained(deviceStateTopic(config_, device.id), "ON");
		publishRetained(deviceBrightnessTopic(config_, device.id), level);
	}
	// Any other result (e.g. TELLSTICK_ERROR_METHOD_NOT_SUPPORTED, or no
	// history yet) means the bridge has never seen this device change
	// state: publish nothing rather than guess.
}

void Bridge::publishSensorDiscovery(const Sensor &sensor) {
	std::string payload = buildSensorDiscoveryPayload(config_, sensor, kBridgeUniqueId);
	if (payload.empty()) {
		return;
	}
	publishRetained(sensorDiscoveryConfigTopic(config_, sensor), payload);
}

void Bridge::publishSensorState(const Sensor &sensor, const std::string &value) {
	publishRetained(sensorStateTopic(config_, sensor), value);
}

void Bridge::onConnect(int rc) {
	if (rc != 0) {
		fprintf(stderr, "telldus-mqtt: connection to broker failed: %s\n", mosquitto_strerror(rc));
		return;
	}
	fprintf(stderr, "telldus-mqtt: connected to %s:%d\n", config_.brokerHost.c_str(), config_.brokerPort);
	publishRetained(config_.statusTopic(), "online");
	subscribeCommandTopics();

	std::vector<Device> snapshot;
	{
		std::lock_guard<std::mutex> lock(devicesMutex_);
		snapshot.reserve(devices_.size());
		for (const auto &entry : devices_) {
			snapshot.push_back(entry.second);
		}
	}
	for (const auto &device : snapshot) {
		publishDiscovery(device);
		publishSeedState(device);
	}

	std::vector<SensorState> sensorSnapshot;
	{
		std::lock_guard<std::mutex> lock(sensorsMutex_);
		sensorSnapshot.reserve(sensors_.size());
		for (const auto &entry : sensors_) {
			sensorSnapshot.push_back(entry.second);
		}
	}
	for (const auto &state : sensorSnapshot) {
		publishSensorDiscovery(state.sensor);
		publishSensorState(state.sensor, state.lastValue);
	}
}

void Bridge::onMessage(const std::string &topic, const std::string &payload) {
	dispatchCommand(config_, topic, payload);
}

void Bridge::onDeviceEvent(int deviceId, int method, const std::string &data) {
	switch (method) {
		case TELLSTICK_TURNON:
			publishRetained(deviceStateTopic(config_, deviceId), "ON");
			break;
		case TELLSTICK_TURNOFF:
			publishRetained(deviceStateTopic(config_, deviceId), "OFF");
			break;
		case TELLSTICK_DIM:
			publishRetained(deviceStateTopic(config_, deviceId), "ON");
			publishRetained(deviceBrightnessTopic(config_, deviceId), data);
			break;
		default:
			// TELLSTICK_BELL, TELLSTICK_UP/DOWN/STOP, group/scene methods:
			// no retained state topic in the Phase 11 topic scheme.
			break;
	}
}

void Bridge::onDeviceChangeEvent(int deviceId, int changeEvent, int changeType) {
	(void)changeType;
	switch (changeEvent) {
		case TELLSTICK_DEVICE_ADDED:
		case TELLSTICK_DEVICE_CHANGED: {
			Device device = fetchDevice(deviceId);
			{
				std::lock_guard<std::mutex> lock(devicesMutex_);
				devices_[deviceId] = device;
			}
			publishDiscovery(device);
			publishSeedState(device);
			break;
		}
		case TELLSTICK_DEVICE_REMOVED: {
			Device device;
			device.id = deviceId;
			{
				std::lock_guard<std::mutex> lock(devicesMutex_);
				auto it = devices_.find(deviceId);
				if (it != devices_.end()) {
					device = it->second;
					devices_.erase(it);
				}
			}
			retractDiscovery(device);
			break;
		}
		default:
			// TELLSTICK_DEVICE_STATE_CHANGED is already covered by the
			// tdRegisterDeviceEvent callback.
			break;
	}
}

void Bridge::onSensorEvent(const std::string &protocol, const std::string &model, int id, int dataType,
		const std::string &value) {
	Sensor sensor;
	sensor.protocol = protocol;
	sensor.model = model;
	sensor.id = id;
	sensor.dataType = dataType;

	bool firstSighting;
	{
		std::lock_guard<std::mutex> lock(sensorsMutex_);
		std::string key = sensorObjectId(sensor);
		firstSighting = sensors_.find(key) == sensors_.end();
		sensors_[key] = SensorState{sensor, value};
	}
	if (firstSighting) {
		publishSensorDiscovery(sensor);
	}
	publishSensorState(sensor, value);
}

void Bridge::onRawDeviceEvent(const std::string &data) {
	publishRaw(config_.topicPrefix + "/raw", data);
}

void Bridge::onConnectTrampoline(struct mosquitto *mosq, void *obj, int rc) {
	(void)mosq;
	static_cast<Bridge *>(obj)->onConnect(rc);
}

void Bridge::onMessageTrampoline(struct mosquitto *mosq, void *obj, const struct mosquitto_message *msg) {
	(void)mosq;
	if (msg == nullptr || msg->topic == nullptr) {
		return;
	}
	std::string payload;
	if (msg->payload != nullptr && msg->payloadlen > 0) {
		payload.assign(static_cast<const char *>(msg->payload), static_cast<size_t>(msg->payloadlen));
	}
	static_cast<Bridge *>(obj)->onMessage(msg->topic, payload);
}

void Bridge::onDeviceEventTrampoline(int deviceId, int method, const char *data, int callbackId, void *context) {
	(void)callbackId;
	static_cast<Bridge *>(context)->onDeviceEvent(deviceId, method, data != nullptr ? data : "");
}

void Bridge::onDeviceChangeEventTrampoline(int deviceId, int changeEvent, int changeType, int callbackId,
		void *context) {
	(void)callbackId;
	static_cast<Bridge *>(context)->onDeviceChangeEvent(deviceId, changeEvent, changeType);
}

void Bridge::onSensorEventTrampoline(const char *protocol, const char *model, int id, int dataType,
		const char *value, int timestamp, int callbackId, void *context) {
	(void)timestamp;
	(void)callbackId;
	static_cast<Bridge *>(context)->onSensorEvent(
		protocol != nullptr ? protocol : "",
		model != nullptr ? model : "",
		id, dataType,
		value != nullptr ? value : "");
}

void Bridge::onRawDeviceEventTrampoline(const char *data, int controllerId, int callbackId, void *context) {
	(void)controllerId;
	(void)callbackId;
	static_cast<Bridge *>(context)->onRawDeviceEvent(data != nullptr ? data : "");
}

int Bridge::run() {
	fprintf(stderr, "telldus-mqtt: waiting for telldusd at %s\n", kTelldusSocketPath);
	if (!waitForTelldusDaemon(30)) {
		fprintf(stderr, "telldus-mqtt: telldusd never appeared at %s, giving up\n", kTelldusSocketPath);
		return 1;
	}

	tdInit();
	enumerateDevices();
	seedSensors();

	deviceEventCallbackId_ = tdRegisterDeviceEvent(&Bridge::onDeviceEventTrampoline, this);
	deviceChangeEventCallbackId_ = tdRegisterDeviceChangeEvent(&Bridge::onDeviceChangeEventTrampoline, this);
	sensorEventCallbackId_ = tdRegisterSensorEvent(&Bridge::onSensorEventTrampoline, this);
	if (config_.rawEvents) {
		rawEventCallbackId_ = tdRegisterRawDeviceEvent(&Bridge::onRawDeviceEventTrampoline, this);
	}

	mosquitto_lib_init();
	mosq_ = mosquitto_new(config_.clientId.c_str(), true, this);
	if (mosq_ == nullptr) {
		fprintf(stderr, "telldus-mqtt: mosquitto_new failed\n");
		mosquitto_lib_cleanup();
		return 1;
	}

	std::string offline = "offline";
	mosquitto_will_set(mosq_, config_.statusTopic().c_str(), static_cast<int>(offline.size()),
		offline.data(), config_.qos, true);

	if (!config_.username.empty()) {
		mosquitto_username_pw_set(mosq_, config_.username.c_str(),
			config_.password.empty() ? nullptr : config_.password.c_str());
	}
	if (!config_.tlsCa.empty()) {
		mosquitto_tls_set(mosq_, config_.tlsCa.c_str(), nullptr, nullptr, nullptr, nullptr);
	}

	mosquitto_connect_callback_set(mosq_, &Bridge::onConnectTrampoline);
	mosquitto_message_callback_set(mosq_, &Bridge::onMessageTrampoline);
	mosquitto_reconnect_delay_set(mosq_, 1, 30, true);

	int rc = mosquitto_connect_async(mosq_, config_.brokerHost.c_str(), config_.brokerPort, 60);
	if (rc != MOSQ_ERR_SUCCESS) {
		fprintf(stderr, "telldus-mqtt: connect setup failed: %s\n", mosquitto_strerror(rc));
		mosquitto_destroy(mosq_);
		mosquitto_lib_cleanup();
		return 1;
	}

	mosquitto_loop_start(mosq_);

	while (!stopRequested_) {
		usleep(200000);
	}

	fprintf(stderr, "telldus-mqtt: shutting down\n");
	publishRetained(config_.statusTopic(), "offline");
	mosquitto_disconnect(mosq_);
	mosquitto_loop_stop(mosq_, false);
	mosquitto_destroy(mosq_);
	mosquitto_lib_cleanup();

	if (deviceEventCallbackId_ >= 0) {
		tdUnregisterCallback(deviceEventCallbackId_);
	}
	if (deviceChangeEventCallbackId_ >= 0) {
		tdUnregisterCallback(deviceChangeEventCallbackId_);
	}
	if (sensorEventCallbackId_ >= 0) {
		tdUnregisterCallback(sensorEventCallbackId_);
	}
	if (rawEventCallbackId_ >= 0) {
		tdUnregisterCallback(rawEventCallbackId_);
	}
	tdClose();
	return 0;
}

}  // namespace TelldusMqtt
