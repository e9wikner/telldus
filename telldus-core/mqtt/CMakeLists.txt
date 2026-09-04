PROJECT(telldus-mqtt)
set(CMAKE_C_FLAGS "-pthread")
set(CMAKE_CXX_FLAGS "-pthread")

INCLUDE_DIRECTORIES(
	${CMAKE_SOURCE_DIR}
	${CMAKE_CURRENT_BINARY_DIR}
)

# Pure logic with no mosquitto/telldus-core-client dependency: config
# parsing, JSON writing, HA component selection and topic construction.
# Built as a separate static library so the test target (tests/mqtt) can
# link it without pulling in libmosquitto or libtelldus-core.
ADD_LIBRARY(TelldusMqttCore STATIC
	Config.cpp
	Discovery.cpp
	Json.cpp
)
SET(telldus-mqtt-core_TARGET TelldusMqttCore PARENT_SCOPE)

FIND_LIBRARY(MOSQUITTO_LIBRARY mosquitto)
INCLUDE(FindPkgConfig)
PKG_SEARCH_MODULE(MOSQUITTO libmosquitto)
INCLUDE_DIRECTORIES(${MOSQUITTO_INCLUDEDIR})

ADD_EXECUTABLE(telldus-mqtt
	main.cpp
	Bridge.cpp
	Commands.cpp
)
ADD_DEPENDENCIES(telldus-mqtt ${telldus-core_TARGET} TelldusMqttCore)

TARGET_LINK_LIBRARIES(telldus-mqtt
	TelldusMqttCore
	${telldus-core_TARGET}
	${MOSQUITTO_LIBRARY}
)

INSTALL(TARGETS telldus-mqtt RUNTIME DESTINATION bin)
