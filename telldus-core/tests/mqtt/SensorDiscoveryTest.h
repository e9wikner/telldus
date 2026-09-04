#ifndef TESTS_MQTT_SENSORDISCOVERYTEST_H_
#define TESTS_MQTT_SENSORDISCOVERYTEST_H_

#include <cppunit/TestFixture.h>
#include <cppunit/extensions/HelperMacros.h>

class SensorDiscoveryTest : public CPPUNIT_NS :: TestFixture
{
	CPPUNIT_TEST_SUITE (SensorDiscoveryTest);
	CPPUNIT_TEST (mapsKnownDataTypesToTopicSegments);
	CPPUNIT_TEST (unknownDataTypeYieldsEmptyName);
	CPPUNIT_TEST (buildsSensorStateTopic);
	CPPUNIT_TEST (buildsSensorDiscoveryConfigTopic);
	CPPUNIT_TEST (objectIdIsStableAcrossCalls);
	CPPUNIT_TEST (objectIdDiffersByDataType);
	CPPUNIT_TEST (discoveryPayloadOmittedForUnrecognizedDataType);
	CPPUNIT_TEST (temperaturePayloadCarriesDeviceClassAndUnit);
	CPPUNIT_TEST (rainTotalPayloadCarriesStateClass);
	CPPUNIT_TEST (windDirectionPayloadHasUnitButNoDeviceClass);
	CPPUNIT_TEST_SUITE_END ();

public:
	void setUp (void) {}
	void tearDown (void) {}

protected:
	void mapsKnownDataTypesToTopicSegments(void);
	void unknownDataTypeYieldsEmptyName(void);
	void buildsSensorStateTopic(void);
	void buildsSensorDiscoveryConfigTopic(void);
	void objectIdIsStableAcrossCalls(void);
	void objectIdDiffersByDataType(void);
	void discoveryPayloadOmittedForUnrecognizedDataType(void);
	void temperaturePayloadCarriesDeviceClassAndUnit(void);
	void rainTotalPayloadCarriesStateClass(void);
	void windDirectionPayloadHasUnitButNoDeviceClass(void);
};

#endif  // TESTS_MQTT_SENSORDISCOVERYTEST_H_
