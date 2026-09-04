//
// Copyright (C) 2026 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
#ifndef TELLDUS_CORE_MQTT_BRIDGE_H_
#define TELLDUS_CORE_MQTT_BRIDGE_H_

#include <atomic>
#include <map>
#include <mutex>
#include <string>

#include "mqtt/Config.h"
#include "mqtt/Device.h"
#include "mqtt/Sensor.h"

struct mosquitto;
struct mosquitto_message;

namespace TelldusMqtt {

// Owns the mosquitto connection and the Telldus event registrations, and
// bridges between them. One mutex (devicesMutex_) guards the device
// registry, since Telldus callbacks arrive on the client library's
// CallbackDispatcher thread while mosquitto callbacks arrive on the thread
// started by mosquitto_loop_start() (see MQTT-DESIGN.md "Threading").
class Bridge {
public:
	explicit Bridge(const Config &config);
	~Bridge();

	Bridge(const Bridge &) = delete;
	Bridge &operator=(const Bridge &) = delete;

	// Waits for telldusd's IPC socket, connects to the broker, registers
	// Telldus event callbacks, and blocks until requestStop() is called.
	// Returns a process exit code (0 on clean shutdown, non-zero on fatal
	// startup failure).
	int run();

	// Signal-handler safe: requests the run() loop to exit and clean up.
	void requestStop();

private:
	// A sensor's last-known value, kept so it can be republished (discovery
	// + state) on every broker reconnect without re-querying Telldus.
	struct SensorState {
		Sensor sensor;
		std::string lastValue;
	};

	bool waitForTelldusDaemon(int timeoutSeconds) const;
	void enumerateDevices();
	Device fetchDevice(int deviceId) const;
	void seedSensors();
	void subscribeCommandTopics();
	void publishDiscovery(const Device &device);
	void retractDiscovery(const Device &device);
	void publishSeedState(const Device &device);
	void publishSensorDiscovery(const Sensor &sensor);
	void publishSensorState(const Sensor &sensor, const std::string &value);
	void publishRetained(const std::string &topic, const std::string &payload);
	void publishRaw(const std::string &topic, const std::string &payload);

	void onConnect(int rc);
	void onMessage(const std::string &topic, const std::string &payload);
	void onDeviceEvent(int deviceId, int method, const std::string &data);
	void onDeviceChangeEvent(int deviceId, int changeEvent, int changeType);
	void onSensorEvent(const std::string &protocol, const std::string &model, int id, int dataType,
		const std::string &value);
	void onRawDeviceEvent(const std::string &data);

	static void onConnectTrampoline(struct mosquitto *mosq, void *obj, int rc);
	static void onMessageTrampoline(struct mosquitto *mosq, void *obj, const struct mosquitto_message *msg);
	static void onDeviceEventTrampoline(int deviceId, int method, const char *data, int callbackId, void *context);
	static void onDeviceChangeEventTrampoline(int deviceId, int changeEvent, int changeType, int callbackId,
		void *context);
	static void onSensorEventTrampoline(const char *protocol, const char *model, int id, int dataType,
		const char *value, int timestamp, int callbackId, void *context);
	static void onRawDeviceEventTrampoline(const char *data, int controllerId, int callbackId, void *context);

	Config config_;
	struct mosquitto *mosq_;
	std::mutex devicesMutex_;
	std::map<int, Device> devices_;
	std::mutex sensorsMutex_;
	std::map<std::string, SensorState> sensors_;
	std::atomic<bool> stopRequested_;
	int deviceEventCallbackId_;
	int deviceChangeEventCallbackId_;
	int sensorEventCallbackId_;
	int rawEventCallbackId_;
};

}  // namespace TelldusMqtt

#endif  // TELLDUS_CORE_MQTT_BRIDGE_H_
