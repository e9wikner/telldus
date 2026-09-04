//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_CONFIG_H_
#define TELLDUS_CORE_MQTT_CONFIG_H_

#include <string>

namespace TelldusMqtt {

class Config {
public:
	static Config fromEnvironment();

	std::string brokerHost = "localhost";
	int brokerPort = 1883;
	std::string username;
	std::string password;
	std::string clientId = "telldus-mqtt";
	std::string tlsCa;
	std::string topicPrefix = "telldus";
	std::string discoveryPrefix = "homeassistant";
	int qos = 1;
	bool debug = false;
	// Publishes tdRegisterRawDeviceEvent frames to <prefix>/raw (non-retained),
	// for debugging unrecognized devices. Default off (MQTT-DESIGN.md Phase 12).
	bool rawEvents = false;

	std::string statusTopic() const;
};

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_CONFIG_H_
