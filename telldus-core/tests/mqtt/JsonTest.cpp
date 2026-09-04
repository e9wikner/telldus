#include "JsonTest.h"
#include "mqtt/Json.h"

using TelldusMqtt::JsonObject;

void JsonTest :: escapesQuotesAndBackslashes (void) {
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"quote and backslash",
		std::string("say \\\"hi\\\" \\\\ bye"),
		JsonObject::escape("say \"hi\" \\ bye")
	);
}

void JsonTest :: escapesControlCharacters (void) {
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"newline, tab, and a raw control byte",
		std::string("a\\nb\\tc\\u0001d"),
		JsonObject::escape(std::string("a\nb\tc\x01""d"))
	);
}

void JsonTest :: buildsObjectWithMixedFieldTypes (void) {
	JsonObject obj;
	obj.addString("name", "Switch 1").addInt("brightness_scale", 255).addBool("optimistic", true);
	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"string/int/bool fields in insertion order",
		std::string("{\"name\":\"Switch 1\",\"brightness_scale\":255,\"optimistic\":true}"),
		obj.str()
	);
}

void JsonTest :: buildsNestedObjectViaAddRaw (void) {
	JsonObject device;
	device.addString("name", "Bridge");

	JsonObject entity;
	entity.addString("unique_id", "telldus_3").addRaw("device", device.str());

	CPPUNIT_ASSERT_EQUAL_MESSAGE(
		"nested object embedded verbatim",
		std::string("{\"unique_id\":\"telldus_3\",\"device\":{\"name\":\"Bridge\"}}"),
		entity.str()
	);
}
