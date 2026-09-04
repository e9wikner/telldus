//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "mqtt/Discovery.h"

#include "client/telldus-core.h"
#include "mqtt/Json.h"

namespace TelldusMqtt {

Component selectComponent(const Device &device) {
	if (device.deviceType == TELLSTICK_TYPE_GROUP) {
		return Component::Switch;
	}
	if (device.methods & (TELLSTICK_UP | TELLSTICK_DOWN | TELLSTICK_STOP)) {
		return Component::Cover;
	}
	if (device.methods & TELLSTICK_DIM) {
		return Component::Light;
	}
	if (device.methods & (TELLSTICK_TURNON | TELLSTICK_TURNOFF)) {
		return Component::Switch;
	}
	if (device.methods & TELLSTICK_BELL) {
		return Component::Button;
	}
	return Component::Unknown;
}

std::string componentName(Component component) {
	switch (component) {
		case Component::Cover:
			return "cover";
		case Component::Light:
			return "light";
		case Component::Switch:
			return "switch";
		case Component::Button:
			return "button";
		case Component::Unknown:
		default:
			return "";
	}
}

std::string deviceStateTopic(const Config &config, int deviceId) {
	return config.topicPrefix + "/device/" + std::to_string(deviceId) + "/state";
}

std::string deviceBrightnessTopic(const Config &config, int deviceId) {
	return config.topicPrefix + "/device/" + std::to_string(deviceId) + "/brightness";
}

std::string deviceSetTopic(const Config &config, int deviceId) {
	return config.topicPrefix + "/device/" + std::to_string(deviceId) + "/set";
}

std::string deviceBrightnessSetTopic(const Config &config, int deviceId) {
	return config.topicPrefix + "/device/" + std::to_string(deviceId) + "/brightness/set";
}

std::string deviceCoverSetTopic(const Config &config, int deviceId) {
	return config.topicPrefix + "/device/" + std::to_string(deviceId) + "/cover/set";
}

std::string discoveryConfigTopic(const Config &config, Component component, int deviceId) {
	return config.discoveryPrefix + "/" + componentName(component) + "/telldus/" +
		std::to_string(deviceId) + "/config";
}

namespace {

std::string uniqueId(int deviceId) {
	return "telldus_" + std::to_string(deviceId);
}

JsonObject buildDeviceBlock(const Device &device, const std::string &bridgeUniqueId) {
	JsonObject identifiers;
	// Home Assistant accepts either a string or a list for "identifiers";
	// a single-element array is the least surprising for future multi-id use.
	std::string idsArray = "[\"" + JsonObject::escape(uniqueId(device.id)) + "\"]";

	JsonObject deviceBlock;
	deviceBlock.addRaw("identifiers", idsArray);
	deviceBlock.addString("name", device.name);
	deviceBlock.addString("manufacturer", device.protocol);
	deviceBlock.addString("model", device.model);
	deviceBlock.addString("via_device", bridgeUniqueId);
	return deviceBlock;
}

}  // namespace

std::string buildDiscoveryPayload(const Config &config, const Device &device, const std::string &bridgeUniqueId) {
	Component component = selectComponent(device);
	if (component == Component::Unknown) {
		return "";
	}

	JsonObject payload;
	payload.addString("name", device.name);
	payload.addString("unique_id", uniqueId(device.id));
	payload.addString("availability_topic", config.statusTopic());
	payload.addString("payload_available", "online");
	payload.addString("payload_not_available", "offline");
	payload.addRaw("device", buildDeviceBlock(device, bridgeUniqueId).str());

	switch (component) {
		case Component::Cover:
			payload.addString("command_topic", deviceCoverSetTopic(config, device.id));
			payload.addString("payload_open", "OPEN");
			payload.addString("payload_close", "CLOSE");
			payload.addString("payload_stop", "STOP");
			payload.addBool("optimistic", true);
			break;
		case Component::Light:
			payload.addString("command_topic", deviceSetTopic(config, device.id));
			payload.addString("state_topic", deviceStateTopic(config, device.id));
			payload.addString("payload_on", "ON");
			payload.addString("payload_off", "OFF");
			payload.addString("brightness_command_topic", deviceBrightnessSetTopic(config, device.id));
			payload.addString("brightness_state_topic", deviceBrightnessTopic(config, device.id));
			payload.addInt("brightness_scale", 255);
			break;
		case Component::Switch:
			payload.addString("command_topic", deviceSetTopic(config, device.id));
			payload.addString("state_topic", deviceStateTopic(config, device.id));
			payload.addString("payload_on", "ON");
			payload.addString("payload_off", "OFF");
			payload.addString("state_on", "ON");
			payload.addString("state_off", "OFF");
			break;
		case Component::Button:
			payload.addString("command_topic", deviceSetTopic(config, device.id));
			payload.addString("payload_press", "PRESS");
			break;
		case Component::Unknown:
			break;
	}

	return payload.str();
}

std::string sensorTypeName(int dataType) {
	switch (dataType) {
		case TELLSTICK_TEMPERATURE:
			return "temperature";
		case TELLSTICK_HUMIDITY:
			return "humidity";
		case TELLSTICK_RAINRATE:
			return "rainrate";
		case TELLSTICK_RAINTOTAL:
			return "raintotal";
		case TELLSTICK_WINDDIRECTION:
			return "winddirection";
		case TELLSTICK_WINDAVERAGE:
			return "windaverage";
		case TELLSTICK_WINDGUST:
			return "windgust";
		default:
			return "";
	}
}

std::string sensorObjectId(const Sensor &sensor) {
	return sensor.protocol + "_" + sensor.model + "_" + std::to_string(sensor.id) + "_" +
		sensorTypeName(sensor.dataType);
}

std::string sensorStateTopic(const Config &config, const Sensor &sensor) {
	return config.topicPrefix + "/sensor/" + sensor.protocol + "/" + sensor.model + "/" +
		std::to_string(sensor.id) + "/" + sensorTypeName(sensor.dataType);
}

std::string sensorDiscoveryConfigTopic(const Config &config, const Sensor &sensor) {
	return config.discoveryPrefix + "/sensor/telldus/" + sensorObjectId(sensor) + "/config";
}

namespace {

// Groups every dataType of one physical sensor (protocol/model/id) under a
// single HA device, distinct from the per-measurement unique_id.
std::string sensorDeviceIdentifier(const Sensor &sensor) {
	return "telldus_sensor_" + sensor.protocol + "_" + sensor.model + "_" + std::to_string(sensor.id);
}

JsonObject buildSensorDeviceBlock(const Sensor &sensor, const std::string &bridgeUniqueId) {
	std::string idsArray = "[\"" + JsonObject::escape(sensorDeviceIdentifier(sensor)) + "\"]";

	JsonObject deviceBlock;
	deviceBlock.addRaw("identifiers", idsArray);
	deviceBlock.addString("name", sensor.protocol + " " + sensor.model + " " + std::to_string(sensor.id));
	deviceBlock.addString("manufacturer", sensor.protocol);
	deviceBlock.addString("model", sensor.model);
	deviceBlock.addString("via_device", bridgeUniqueId);
	return deviceBlock;
}

}  // namespace

std::string buildSensorDiscoveryPayload(const Config &config, const Sensor &sensor,
		const std::string &bridgeUniqueId) {
	std::string type = sensorTypeName(sensor.dataType);
	if (type.empty()) {
		return "";
	}

	JsonObject payload;
	payload.addString("name", type);
	payload.addString("unique_id", "telldus_" + sensorObjectId(sensor));
	payload.addString("state_topic", sensorStateTopic(config, sensor));
	payload.addString("availability_topic", config.statusTopic());
	payload.addString("payload_available", "online");
	payload.addString("payload_not_available", "offline");

	// device_class / unit_of_measurement / state_class, per the
	// MQTT-DESIGN.md Phase 13 sensor mapping table.
	switch (sensor.dataType) {
		case TELLSTICK_TEMPERATURE:
			payload.addString("device_class", "temperature");
			payload.addString("unit_of_measurement", "\xc2\xb0" "C");
			break;
		case TELLSTICK_HUMIDITY:
			payload.addString("device_class", "humidity");
			payload.addString("unit_of_measurement", "%");
			break;
		case TELLSTICK_RAINRATE:
			payload.addString("device_class", "precipitation_intensity");
			payload.addString("unit_of_measurement", "mm/h");
			break;
		case TELLSTICK_RAINTOTAL:
			payload.addString("device_class", "precipitation");
			payload.addString("unit_of_measurement", "mm");
			payload.addString("state_class", "total_increasing");
			break;
		case TELLSTICK_WINDDIRECTION:
			payload.addString("unit_of_measurement", "\xc2\xb0");
			break;
		case TELLSTICK_WINDAVERAGE:
		case TELLSTICK_WINDGUST:
			payload.addString("device_class", "wind_speed");
			payload.addString("unit_of_measurement", "m/s");
			break;
		default:
			break;
	}

	payload.addRaw("device", buildSensorDeviceBlock(sensor, bridgeUniqueId).str());
	return payload.str();
}

}  // namespace TelldusMqtt
