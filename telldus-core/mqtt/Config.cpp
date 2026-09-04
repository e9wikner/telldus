//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "mqtt/Config.h"

#include <cstdlib>
#include <unistd.h>

namespace TelldusMqtt {

namespace {

std::string getEnvOr(const char *name, const std::string &fallback) {
	const char *value = std::getenv(name);
	if (value == nullptr || value[0] == '\0') {
		return fallback;
	}
	return std::string(value);
}

int getEnvIntOr(const char *name, int fallback) {
	const char *value = std::getenv(name);
	if (value == nullptr || value[0] == '\0') {
		return fallback;
	}
	return std::atoi(value);
}

bool getEnvBoolOr(const char *name, bool fallback) {
	const char *value = std::getenv(name);
	if (value == nullptr || value[0] == '\0') {
		return fallback;
	}
	return std::string(value) == "1" || std::string(value) == "true";
}

std::string defaultClientId() {
	char hostname[256] = {0};
	if (gethostname(hostname, sizeof(hostname) - 1) != 0) {
		return "telldus-mqtt";
	}
	return std::string("telldus-mqtt-") + hostname;
}

}  // namespace

Config Config::fromEnvironment() {
	Config config;
	config.brokerHost = getEnvOr("MQTT_BROKER_HOST", "localhost");
	config.brokerPort = getEnvIntOr("MQTT_BROKER_PORT", 1883);
	config.username = getEnvOr("MQTT_USERNAME", "");
	config.password = getEnvOr("MQTT_PASSWORD", "");
	config.clientId = getEnvOr("MQTT_CLIENT_ID", defaultClientId());
	config.tlsCa = getEnvOr("MQTT_TLS_CA", "");
	config.topicPrefix = getEnvOr("MQTT_TOPIC_PREFIX", "telldus");
	config.discoveryPrefix = getEnvOr("MQTT_DISCOVERY_PREFIX", "homeassistant");
	config.qos = getEnvIntOr("MQTT_QOS", 1);
	config.debug = getEnvOr("MQTT_LOG_LEVEL", "") == "debug";
	config.rawEvents = getEnvBoolOr("MQTT_RAW_EVENTS", false);
	return config;
}

std::string Config::statusTopic() const {
	return topicPrefix + "/bridge/status";
}

}  // namespace TelldusMqtt
