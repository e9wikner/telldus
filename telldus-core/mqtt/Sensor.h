//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_SENSOR_H_
#define TELLDUS_CORE_MQTT_SENSOR_H_

#include <string>

namespace TelldusMqtt {

// Identifies one measurement stream from a sensor. A single physical sensor
// (protocol/model/id) can report several dataTypes (e.g. temperature and
// humidity); each is addressed as its own MQTT topic and HA entity, per
// MQTT-DESIGN.md Phase 12. Sensors are never in tellstick.conf — this is
// built at runtime as packets arrive (or seeded from tdSensor() at startup).
struct Sensor {
	std::string protocol;
	std::string model;
	int id = 0;
	int dataType = 0;
};

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_SENSOR_H_
