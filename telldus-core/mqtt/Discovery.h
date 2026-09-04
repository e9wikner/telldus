//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_DISCOVERY_H_
#define TELLDUS_CORE_MQTT_DISCOVERY_H_

#include <string>

#include "mqtt/Config.h"
#include "mqtt/Device.h"
#include "mqtt/Sensor.h"

namespace TelldusMqtt {

enum class Component {
	Cover,
	Light,
	Switch,
	Button,
	Unknown,
};

// Component selection from the tdMethods bitmask / deviceType, per the
// MQTT-DESIGN.md Phase 13 mapping table. TELLSTICK_TYPE_GROUP always wins
// (groups are exposed as switches); TELLSTICK_TYPE_SCENE is out of scope
// and returns Unknown, meaning "publish no discovery payload".
Component selectComponent(const Device &device);
std::string componentName(Component component);

// State/command topics, shared by Bridge (publish) and Commands (subscribe/dispatch).
std::string deviceStateTopic(const Config &config, int deviceId);
std::string deviceBrightnessTopic(const Config &config, int deviceId);
std::string deviceSetTopic(const Config &config, int deviceId);
std::string deviceBrightnessSetTopic(const Config &config, int deviceId);
std::string deviceCoverSetTopic(const Config &config, int deviceId);

std::string discoveryConfigTopic(const Config &config, Component component, int deviceId);

// Home Assistant discovery payload for a single device. Empty string if
// selectComponent() returned Unknown (nothing should be published).
std::string buildDiscoveryPayload(const Config &config, const Device &device, const std::string &bridgeUniqueId);

// Sensor dataType -> topic segment, per the MQTT-DESIGN.md Phase 12/13
// mapping table. Empty string means an unrecognized (single-bit) dataType.
std::string sensorTypeName(int dataType);

// Stable identity for a single measurement stream (one Sensor), used both as
// the discovery object_id and as the registry key in Bridge — one function
// so the two never drift apart.
std::string sensorObjectId(const Sensor &sensor);

std::string sensorStateTopic(const Config &config, const Sensor &sensor);
std::string sensorDiscoveryConfigTopic(const Config &config, const Sensor &sensor);

// Home Assistant discovery payload for one sensor measurement. Empty string
// if sensorTypeName() does not recognize the dataType.
std::string buildSensorDiscoveryPayload(const Config &config, const Sensor &sensor, const std::string &bridgeUniqueId);

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_DISCOVERY_H_
