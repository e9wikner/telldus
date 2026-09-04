#include "SensorDiscoveryTest.h"

#include "client/telldus-core.h"
#include "mqtt/Discovery.h"

using TelldusMqtt::Config;
using TelldusMqtt::Sensor;

void SensorDiscoveryTest :: mapsKnownDataTypesToTopicSegments (void) {
	CPPUNIT_ASSERT_EQUAL(std::string("temperature"), TelldusMqtt::sensorTypeName(TELLSTICK_TEMPERATURE));
	CPPUNIT_ASSERT_EQUAL(std::string("humidity"), TelldusMqtt::sensorTypeName(TELLSTICK_HUMIDITY));
	CPPUNIT_ASSERT_EQUAL(std::string("rainrate"), TelldusMqtt::sensorTypeName(TELLSTICK_RAINRATE));
	CPPUNIT_ASSERT_EQUAL(std::string("raintotal"), TelldusMqtt::sensorTypeName(TELLSTICK_RAINTOTAL));
	CPPUNIT_ASSERT_EQUAL(std::string("winddirection"), TelldusMqtt::sensorTypeName(TELLSTICK_WINDDIRECTION));
	CPPUNIT_ASSERT_EQUAL(std::string("windaverage"), TelldusMqtt::sensorTypeName(TELLSTICK_WINDAVERAGE));
	CPPUNIT_ASSERT_EQUAL(std::string("windgust"), TelldusMqtt::sensorTypeName(TELLSTICK_WINDGUST));
}

void SensorDiscoveryTest :: unknownDataTypeYieldsEmptyName (void) {
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"a dataType with no bit set matches nothing",
		std::string(""),
		TelldusMqtt::sensorTypeName(0)
	);
}

void SensorDiscoveryTest :: buildsSensorStateTopic (void) {
	Config config;
	config.topicPrefix = "telldus";

	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "F824";
	sensor.id = 4;
	sensor.dataType = TELLSTICK_TEMPERATURE;

	CPPUNIT_ASSERT_EQUAL(
		std::string("telldus/sensor/oregon/F824/4/temperature"),
		TelldusMqtt::sensorStateTopic(config, sensor)
	);
}

void SensorDiscoveryTest :: buildsSensorDiscoveryConfigTopic (void) {
	Config config;
	config.discoveryPrefix = "homeassistant";

	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "F824";
	sensor.id = 4;
	sensor.dataType = TELLSTICK_HUMIDITY;

	CPPUNIT_ASSERT_EQUAL(
		std::string("homeassistant/sensor/telldus/oregon_F824_4_humidity/config"),
		TelldusMqtt::sensorDiscoveryConfigTopic(config, sensor)
	);
}

void SensorDiscoveryTest :: objectIdIsStableAcrossCalls (void) {
	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "F824";
	sensor.id = 4;
	sensor.dataType = TELLSTICK_TEMPERATURE;

	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"the registry key and the discovery object_id must never drift apart",
		TelldusMqtt::sensorObjectId(sensor),
		TelldusMqtt::sensorObjectId(sensor)
	);
}

void SensorDiscoveryTest :: objectIdDiffersByDataType (void) {
	Sensor temperature;
	temperature.protocol = "oregon";
	temperature.model = "F824";
	temperature.id = 4;
	temperature.dataType = TELLSTICK_TEMPERATURE;

	Sensor humidity = temperature;
	humidity.dataType = TELLSTICK_HUMIDITY;

	CPPUNIT_ASSERT_MESSAGE(
		"one physical sensor reporting two dataTypes must get two distinct entities",
		TelldusMqtt::sensorObjectId(temperature) != TelldusMqtt::sensorObjectId(humidity)
	);
}

void SensorDiscoveryTest :: discoveryPayloadOmittedForUnrecognizedDataType (void) {
	Config config;
	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "F824";
	sensor.id = 4;
	sensor.dataType = 0;

	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"unrecognized dataType publishes no discovery payload",
		std::string(""),
		TelldusMqtt::buildSensorDiscoveryPayload(config, sensor, "telldus_bridge")
	);
}

void SensorDiscoveryTest :: temperaturePayloadCarriesDeviceClassAndUnit (void) {
	Config config;
	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "F824";
	sensor.id = 4;
	sensor.dataType = TELLSTICK_TEMPERATURE;

	std::string payload = TelldusMqtt::buildSensorDiscoveryPayload(config, sensor, "telldus_bridge");
	CPPUNIT_ASSERT_MESSAGE("temperature payload must be non-empty", !payload.empty());
	CPPUNIT_ASSERT(payload.find("\"device_class\":\"temperature\"") != std::string::npos);
	CPPUNIT_ASSERT(payload.find("\"unit_of_measurement\":\"\xc2\xb0" "C\"") != std::string::npos);
	CPPUNIT_ASSERT(payload.find("\"unique_id\":\"telldus_oregon_F824_4_temperature\"") != std::string::npos);
}

void SensorDiscoveryTest :: rainTotalPayloadCarriesStateClass (void) {
	Config config;
	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "PCR800";
	sensor.id = 2;
	sensor.dataType = TELLSTICK_RAINTOTAL;

	std::string payload = TelldusMqtt::buildSensorDiscoveryPayload(config, sensor, "telldus_bridge");
	CPPUNIT_ASSERT(payload.find("\"device_class\":\"precipitation\"") != std::string::npos);
	CPPUNIT_ASSERT(payload.find("\"unit_of_measurement\":\"mm\"") != std::string::npos);
	CPPUNIT_ASSERT(payload.find("\"state_class\":\"total_increasing\"") != std::string::npos);
}

void SensorDiscoveryTest :: windDirectionPayloadHasUnitButNoDeviceClass (void) {
	Config config;
	Sensor sensor;
	sensor.protocol = "oregon";
	sensor.model = "WGR800";
	sensor.id = 5;
	sensor.dataType = TELLSTICK_WINDDIRECTION;

	std::string payload = TelldusMqtt::buildSensorDiscoveryPayload(config, sensor, "telldus_bridge");
	CPPUNIT_ASSERT_MESSAGE(
		"wind direction has no HA device_class in the mapping table",
		payload.find("\"device_class\"") == std::string::npos
	);
	CPPUNIT_ASSERT(payload.find("\"unit_of_measurement\":\"\xc2\xb0\"") != std::string::npos);
}
