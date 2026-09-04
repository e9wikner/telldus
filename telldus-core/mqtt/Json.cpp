//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "mqtt/Json.h"

#include <cstdio>
#include <sstream>

namespace TelldusMqtt {

std::string JsonObject::escape(const std::string &value) {
	std::string out;
	out.reserve(value.size());
	for (char c : value) {
		switch (c) {
			case '"':
				out += "\\\"";
				break;
			case '\\':
				out += "\\\\";
				break;
			case '\n':
				out += "\\n";
				break;
			case '\r':
				out += "\\r";
				break;
			case '\t':
				out += "\\t";
				break;
			default:
				if (static_cast<unsigned char>(c) < 0x20) {
					char buf[8];
					snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned int>(static_cast<unsigned char>(c)));
					out += buf;
				} else {
					out += c;
				}
		}
	}
	return out;
}

JsonObject &JsonObject::addString(const std::string &key, const std::string &value) {
	fields_.emplace_back(key, "\"" + escape(value) + "\"");
	return *this;
}

JsonObject &JsonObject::addInt(const std::string &key, int value) {
	fields_.emplace_back(key, std::to_string(value));
	return *this;
}

JsonObject &JsonObject::addBool(const std::string &key, bool value) {
	fields_.emplace_back(key, value ? "true" : "false");
	return *this;
}

JsonObject &JsonObject::addRaw(const std::string &key, const std::string &value) {
	fields_.emplace_back(key, value);
	return *this;
}

std::string JsonObject::str() const {
	std::ostringstream out;
	out << "{";
	for (size_t i = 0; i < fields_.size(); ++i) {
		if (i > 0) {
			out << ",";
		}
		out << "\"" << escape(fields_[i].first) << "\":" << fields_[i].second;
	}
	out << "}";
	return out.str();
}

}  // namespace TelldusMqtt
