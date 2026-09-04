#ifndef TESTS_MQTT_JSONTEST_H_
#define TESTS_MQTT_JSONTEST_H_

#include <cppunit/TestFixture.h>
#include <cppunit/extensions/HelperMacros.h>

class JsonTest : public CPPUNIT_NS :: TestFixture
{
	CPPUNIT_TEST_SUITE (JsonTest);
	CPPUNIT_TEST (escapesQuotesAndBackslashes);
	CPPUNIT_TEST (escapesControlCharacters);
	CPPUNIT_TEST (buildsObjectWithMixedFieldTypes);
	CPPUNIT_TEST (buildsNestedObjectViaAddRaw);
	CPPUNIT_TEST_SUITE_END ();

public:
	void setUp (void) {}
	void tearDown (void) {}

protected:
	void escapesQuotesAndBackslashes(void);
	void escapesControlCharacters(void);
	void buildsObjectWithMixedFieldTypes(void);
	void buildsNestedObjectViaAddRaw(void);
};

#endif  // TESTS_MQTT_JSONTEST_H_
