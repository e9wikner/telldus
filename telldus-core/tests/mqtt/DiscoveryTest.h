#ifndef TESTS_MQTT_DISCOVERYTEST_H_
#define TESTS_MQTT_DISCOVERYTEST_H_

#include <cppunit/TestFixture.h>
#include <cppunit/extensions/HelperMacros.h>

class DiscoveryTest : public CPPUNIT_NS :: TestFixture
{
	CPPUNIT_TEST_SUITE (DiscoveryTest);
	CPPUNIT_TEST (selectsCoverForUpDownStop);
	CPPUNIT_TEST (selectsLightForDim);
	CPPUNIT_TEST (selectsSwitchForOnOff);
	CPPUNIT_TEST (selectsButtonForBellOnly);
	CPPUNIT_TEST (groupAlwaysSelectsSwitchEvenWithDimMethods);
	CPPUNIT_TEST (unknownForUnrecognizedMethods);
	CPPUNIT_TEST (buildsDeviceTopics);
	CPPUNIT_TEST (buildsDiscoveryConfigTopic);
	CPPUNIT_TEST (discoveryPayloadOmittedForUnknownComponent);
	CPPUNIT_TEST_SUITE_END ();

public:
	void setUp (void) {}
	void tearDown (void) {}

protected:
	void selectsCoverForUpDownStop(void);
	void selectsLightForDim(void);
	void selectsSwitchForOnOff(void);
	void selectsButtonForBellOnly(void);
	void groupAlwaysSelectsSwitchEvenWithDimMethods(void);
	void unknownForUnrecognizedMethods(void);
	void buildsDeviceTopics(void);
	void buildsDiscoveryConfigTopic(void);
	void discoveryPayloadOmittedForUnknownComponent(void);
};

#endif  // TESTS_MQTT_DISCOVERYTEST_H_
