//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include <csignal>
#include <cstdio>

#include "mqtt/Bridge.h"
#include "mqtt/Config.h"

namespace {

TelldusMqtt::Bridge *g_bridge = nullptr;

void handleShutdownSignal(int signal) {
	(void)signal;
	if (g_bridge != nullptr) {
		g_bridge->requestStop();
	}
}

}  // namespace

int main() {
	TelldusMqtt::Config config = TelldusMqtt::Config::fromEnvironment();
	fprintf(stderr, "telldus-mqtt: starting, broker=%s:%d topic-prefix=%s discovery-prefix=%s\n",
		config.brokerHost.c_str(), config.brokerPort, config.topicPrefix.c_str(), config.discoveryPrefix.c_str());

	TelldusMqtt::Bridge bridge(config);
	g_bridge = &bridge;

	std::signal(SIGTERM, handleShutdownSignal);
	std::signal(SIGINT, handleShutdownSignal);

	return bridge.run();
}
