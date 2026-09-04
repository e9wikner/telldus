//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#include "mqtt/Commands.h"

#include <cstdio>
#include <stdexcept>

#include "client/telldus-core.h"

namespace TelldusMqtt {

namespace {

bool stripPrefix(const std::string &value, const std::string &prefix, std::string *rest) {
	if (value.compare(0, prefix.size(), prefix) != 0) {
		return false;
	}
	*rest = value.substr(prefix.size());
	return true;
}

// Splits "<id>/<suffix>" into (id, suffix). Returns false if <id> is not a
// plain non-negative integer or there is no '/' after it.
bool splitIdAndSuffix(const std::string &value, int *deviceId, std::string *suffix) {
	size_t slash = value.find('/');
	if (slash == std::string::npos || slash == 0) {
		return false;
	}
	std::string idPart = value.substr(0, slash);
	for (char c : idPart) {
		if (c < '0' || c > '9') {
			return false;
		}
	}
	try {
		*deviceId = std::stoi(idPart);
	} catch (const std::exception &) {
		return false;
	}
	*suffix = value.substr(slash + 1);
	return true;
}

void dispatchSetPayload(int deviceId, const std::string &payload) {
	if (payload == "ON") {
		tdTurnOn(deviceId);
	} else if (payload == "OFF") {
		tdTurnOff(deviceId);
	} else if (payload == "TOGGLE") {
		int lastSent = tdLastSentCommand(deviceId, TELLSTICK_TURNON | TELLSTICK_TURNOFF);
		if (lastSent == TELLSTICK_TURNON) {
			tdTurnOff(deviceId);
		} else {
			tdTurnOn(deviceId);
		}
	} else if (payload == "PRESS") {
		tdBell(deviceId);
	} else {
		fprintf(stderr, "telldus-mqtt: unknown payload '%s' for device %d\n", payload.c_str(), deviceId);
	}
}

void dispatchBrightnessPayload(int deviceId, const std::string &payload) {
	int level;
	try {
		level = std::stoi(payload);
	} catch (const std::exception &) {
		fprintf(stderr, "telldus-mqtt: invalid brightness '%s' for device %d\n", payload.c_str(), deviceId);
		return;
	}
	if (level < 0) {
		level = 0;
	} else if (level > 255) {
		level = 255;
	}
	tdDim(deviceId, static_cast<unsigned char>(level));
}

void dispatchCoverPayload(int deviceId, const std::string &payload) {
	if (payload == "OPEN") {
		tdUp(deviceId);
	} else if (payload == "CLOSE") {
		tdDown(deviceId);
	} else if (payload == "STOP") {
		tdStop(deviceId);
	} else {
		fprintf(stderr, "telldus-mqtt: unknown cover payload '%s' for device %d\n", payload.c_str(), deviceId);
	}
}

}  // namespace

bool dispatchCommand(const Config &config, const std::string &topic, const std::string &payload) {
	std::string rest;
	if (!stripPrefix(topic, config.topicPrefix + "/device/", &rest)) {
		return false;
	}

	int deviceId = 0;
	std::string suffix;
	if (!splitIdAndSuffix(rest, &deviceId, &suffix)) {
		return false;
	}

	if (suffix == "set") {
		dispatchSetPayload(deviceId, payload);
	} else if (suffix == "brightness/set") {
		dispatchBrightnessPayload(deviceId, payload);
	} else if (suffix == "cover/set") {
		dispatchCoverPayload(deviceId, payload);
	} else {
		return false;
	}
	return true;
}

}  // namespace TelldusMqtt
