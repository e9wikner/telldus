//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_COMMANDS_H_
#define TELLDUS_CORE_MQTT_COMMANDS_H_

#include <string>

#include "mqtt/Config.h"

namespace TelldusMqtt {

// Matches an inbound MQTT topic against the device command topics
// (<prefix>/device/<id>/set, /brightness/set, /cover/set) and, if it
// matches, dispatches the payload to the corresponding td* call
// (tdTurnOn/tdTurnOff/tdDim/tdUp/tdDown/tdStop/tdBell).
//
// Returns true if the topic was recognized as a command topic (regardless
// of whether the payload was valid or the underlying td* call succeeded).
bool dispatchCommand(const Config &config, const std::string &topic, const std::string &payload);

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_COMMANDS_H_
