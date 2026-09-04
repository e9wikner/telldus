#include "DiscoveryTest.h"

#include "client/telldus-core.h"
#include "mqtt/Discovery.h"

using TelldusMqtt::Component;
using TelldusMqtt::Config;
using TelldusMqtt::Device;

void DiscoveryTest :: selectsCoverForUpDownStop (void) {
	Device device;
	device.methods = TELLSTICK_UP | TELLSTICK_DOWN | TELLSTICK_STOP;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"UP|DOWN|STOP maps to cover",
		static_cast<int>(Component::Cover),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: selectsLightForDim (void) {
	Device device;
	device.methods = TELLSTICK_TURNON | TELLSTICK_TURNOFF | TELLSTICK_DIM;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"DIM (with on/off) maps to light",
		static_cast<int>(Component::Light),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: selectsSwitchForOnOff (void) {
	Device device;
	device.methods = TELLSTICK_TURNON | TELLSTICK_TURNOFF;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"plain on/off maps to switch",
		static_cast<int>(Component::Switch),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: selectsButtonForBellOnly (void) {
	Device device;
	device.methods = TELLSTICK_BELL;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"bell-only maps to button",
		static_cast<int>(Component::Button),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: groupAlwaysSelectsSwitchEvenWithDimMethods (void) {
	Device device;
	device.methods = TELLSTICK_TURNON | TELLSTICK_TURNOFF | TELLSTICK_DIM;
	device.deviceType = TELLSTICK_TYPE_GROUP;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"TELLSTICK_TYPE_GROUP always wins, regardless of methods",
		static_cast<int>(Component::Switch),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: unknownForUnrecognizedMethods (void) {
	Device device;
	device.methods = TELLSTICK_LEARN;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"no recognized method bit means no discovery entity",
		static_cast<int>(Component::Unknown),
		static_cast<int>(TelldusMqtt::selectComponent(device))
	);
}

void DiscoveryTest :: buildsDeviceTopics (void) {
	Config config;
	config.topicPrefix = "telldus";

	CPPUNIT_ASSERT_EQUAL(std::string("telldus/device/3/state"), TelldusMqtt::deviceStateTopic(config, 3));
	CPPUNIT_ASSERT_EQUAL(std::string("telldus/device/3/brightness"), TelldusMqtt::deviceBrightnessTopic(config, 3));
	CPPUNIT_ASSERT_EQUAL(std::string("telldus/device/3/set"), TelldusMqtt::deviceSetTopic(config, 3));
	CPPUNIT_ASSERT_EQUAL(
		std::string("telldus/device/3/brightness/set"),
		TelldusMqtt::deviceBrightnessSetTopic(config, 3)
	);
	CPPUNIT_ASSERT_EQUAL(std::string("telldus/device/3/cover/set"), TelldusMqtt::deviceCoverSetTopic(config, 3));
	CPPUNIT_ASSERT_EQUAL(std::string("telldus/bridge/status"), config.statusTopic());
}

void DiscoveryTest :: buildsDiscoveryConfigTopic (void) {
	Config config;
	config.discoveryPrefix = "homeassistant";
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"<discovery_prefix>/<component>/telldus/<object_id>/config",
		std::string("homeassistant/switch/telldus/7/config"),
		TelldusMqtt::discoveryConfigTopic(config, Component::Switch, 7)
	);
}

void DiscoveryTest :: discoveryPayloadOmittedForUnknownComponent (void) {
	Config config;
	Device device;
	device.id = 9;
	device.methods = TELLSTICK_LEARN;
	device.deviceType = TELLSTICK_TYPE_DEVICE;
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"unrecognized devices publish no discovery payload",
		std::string(""),
		TelldusMqtt::buildDiscoveryPayload(config, device, "telldus_bridge")
	);
}
