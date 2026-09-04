#ifndef MQTTTESTS_H
#define MQTTTESTS_H

#include "JsonTest.h"
#include "DiscoveryTest.h"
#include "SensorDiscoveryTest.h"

namespace MqttTests {
	inline void setup() {
		CPPUNIT_TEST_SUITE_REGISTRATION (JsonTest);
		CPPUNIT_TEST_SUITE_REGISTRATION (DiscoveryTest);
		CPPUNIT_TEST_SUITE_REGISTRATION (SensorDiscoveryTest);
	}
}
#endif // MQTTTESTS_H
