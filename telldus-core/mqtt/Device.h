//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_DEVICE_H_
#define TELLDUS_CORE_MQTT_DEVICE_H_

#include <string>

namespace TelldusMqtt {

// Snapshot of a configured Telldus device (tellstick.conf entry), as returned
// by the tdGet* enumeration calls. Never written back — the bridge is
// read-only with respect to device configuration (MQTT-04).
struct Device {
	int id = 0;
	std::string name;
	std::string protocol;
	std::string model;
	int methods = 0;
	int deviceType = 0;
};

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_DEVICE_H_
