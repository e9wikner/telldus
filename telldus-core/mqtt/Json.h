//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_JSON_H_
#define TELLDUS_CORE_MQTT_JSON_H_

#include <string>
#include <utility>
#include <vector>

namespace TelldusMqtt {

// Minimal write-only JSON object builder. Values are inserted in the order
// they are added. Only what Home Assistant discovery payloads need: string,
// int, bool fields and nested objects (added as pre-built JSON text).
class JsonObject {
public:
	JsonObject &addString(const std::string &key, const std::string &value);
	JsonObject &addInt(const std::string &key, int value);
	JsonObject &addBool(const std::string &key, bool value);
	// value must already be valid JSON (e.g. the str() of a nested JsonObject).
	JsonObject &addRaw(const std::string &key, const std::string &value);

	std::string str() const;

	static std::string escape(const std::string &value);

private:
	std::vector<std::pair<std::string, std::string> > fields_;
};

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_JSON_H_
