# Phase 2: Arch Native Build - Pattern Map

**Mapped:** 2026-05-14
**Files analyzed:** 10 new/modified files
**Analogs found:** 8 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/install-arch-deps.sh` | utility | batch | `telldus-core/tdadmin/udev.sh` | partial |
| `CMakePresets.json` | config | batch | None | none |
| `telldus-core/CMakeLists.txt` | config | batch | `telldus-core/CMakeLists.txt` | exact |
| `telldus-core/tests/CMakeLists.txt` | config | batch | `telldus-core/tests/CMakeLists.txt` | exact |
| `.gitignore` | config | N/A | `.gitignore` | exact |
| `telldus-core/tdtool/main.cpp` | utility | request-response | `telldus-core/tdtool/main.cpp` | exact |
| `telldus-core/service/SettingsConfuse.cpp` | service | CRUD | `telldus-core/service/SettingsConfuse.cpp` | exact |
| `telldus-core/common/Strings.cpp` | utility | transform | `telldus-core/common/Strings.cpp` | exact |
| `telldus-core/service/TellStick_libftdi.cpp` | service | streaming | `telldus-core/service/TellStick_libftdi.cpp` | exact |
| `telldus-core/client/Client.cpp` | service | request-response | `telldus-core/client/Client.cpp` | exact |

## Pattern Assignments

### `scripts/install-arch-deps.sh` (utility, batch)

**Analog:** `telldus-core/tdadmin/udev.sh` and `rfcmd/build.sh`

**Shell script pattern** (from `udev.sh`, lines 1-9):
```bash
#!/bin/sh

if [ "${ID_VENDOR_ID}" = "1781" ]; then
	if [ "${ACTION}" = "add" ]; then
		@CMAKE_INSTALL_PREFIX@/sbin/tdadmin controller connect --pid=${ID_MODEL_ID} --vid=${ID_VENDOR_ID} --serial=${ID_SERIAL_SHORT}
	elif [ "${ACTION}" = "remove" ]; then
		@CMAKE_INSTALL_PREFIX@/sbin/tdadmin controller disconnect --pid=${ID_MODEL_ID} --vid=${ID_VENDOR_ID} --serial=${ID_SERIAL_SHORT}
	fi
fi
```

**Build script pattern** (from `rfcmd/build.sh`, lines 1-6):
```bash
#!/bin/sh
set -e
make clean || { echo "Warning: make clean failed"; }
make || { echo "make failed"; exit 1; }
make install || { echo "make install failed"; exit 1; }
echo rfcmd built and installed!
```

**Pattern to copy:**
- Use `#!/bin/sh` or `#!/bin/bash` shebang
- Include `set -e` for fail-fast behavior
- Use `||` for graceful handling of optional steps
- Keep scripts standalone executable

---

### `CMakePresets.json` (config, batch)

**Analog:** None exists in codebase.

**Reference pattern:** Use modern CMake preset schema v3+. The existing README (lines 51-56) documents the configure command:
```bash
cmake -S telldus-core -B build/telldus-core-headless \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

**Pattern to create:**
- Map the above configure options into a `configurePresets` entry
- Use `binaryDir` pointing to `build/${presetName}`
- Include cache variables: `FORCE_COMPILE_FROM_TRUNK`, `BUILD_TDTOOL`, `BUILD_TDADMIN`, `ENABLE_TESTING`, `FTDI_ENGINE`

---

### `telldus-core/CMakeLists.txt` (config, batch)

**Analog:** `telldus-core/CMakeLists.txt` (exact)

**Version and option pattern** (lines 12-28):
```cmake
SET(PACKAGE_MAJOR_VERSION 2)
SET(PACKAGE_MINOR_VERSION 1)
SET(PACKAGE_PATCH_VERSION 3)
SET(PACKAGE_VERSION "${PACKAGE_MAJOR_VERSION}.${PACKAGE_MINOR_VERSION}.${PACKAGE_PATCH_VERSION}")
SET(PACKAGE_SUBVERSION "beta1")
SET(PACKAGE_SOVERSION 2)

SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

SET(BUILD_LIBTELLDUS-CORE	TRUE	CACHE BOOL "Build libtelldus-core")
```

**Platform branch pattern** (lines 29-40):
```cmake
IF (WIN32)
	SET(TDADMIN_DEFAULT FALSE)
ELSEIF(APPLE)
	SET(TDADMIN_DEFAULT FALSE)
ELSE (WIN32)
	SET(TDADMIN_DEFAULT TRUE)
ENDIF (WIN32)

IF (CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
	INCLUDE_DIRECTORIES(/usr/local/include)
	LINK_DIRECTORIES(/usr/local/lib)
ENDIF (CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
```

**Subdirectory and testing pattern** (lines 57-81):
```cmake
ADD_SUBDIRECTORY(common)
ADD_SUBDIRECTORY(service)

IF(BUILD_LIBTELLDUS-CORE)
	ADD_SUBDIRECTORY(client)
ENDIF(BUILD_LIBTELLDUS-CORE)

ENABLE_TESTING()
IF(ENABLE_TESTING AND NOT BUILD_LIBTELLDUS-CORE)
	MESSAGE(FATAL_ERROR "ENABLE_TESTING requires BUILD_LIBTELLDUS-CORE")
ENDIF(ENABLE_TESTING AND NOT BUILD_LIBTELLDUS-CORE)
ADD_SUBDIRECTORY(tests)
```

**Compiler flags addition pattern** (from `telldus-core/client/CMakeLists.txt`, lines 107-109):
```cmake
IF (UNIX)
	SET_TARGET_PROPERTIES( ${telldus-core_TARGET} PROPERTIES COMPILE_FLAGS "-fPIC -fvisibility=hidden")
ENDIF (UNIX)
```

**Pattern for adding global warning flags:**
- Add `IF(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")` block after `CMAKE_MINIMUM_REQUIRED`
- Use `ADD_COMPILE_OPTIONS()` for `-Wall -Wextra -Wdeprecated-declarations -Wconversion -Wsign-conversion`
- Or use `SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ...")` to preserve existing flags

---

### `telldus-core/tests/CMakeLists.txt` (config, batch)

**Analog:** `telldus-core/tests/CMakeLists.txt` (exact)

**Test enablement pattern** (lines 1-2):
```cmake
SET(ENABLE_TESTING	FALSE	CACHE BOOL "Enable unit tests")
```

**cpplint filter pattern** (lines 20-22):
```cmake
SET(cpplint_filters
	+whitespace/use_tab_for_indentation,-whitespace/tab,-whitespace/parens,-whitespace/line_length,-whitespace/labels,-runtime/rtti
)
```

**Style test function pattern** (lines 24-30):
```cmake
FUNCTION(ADD_SOURCES TARGET PATH)
	GET_TARGET_PROPERTY(SOURCES ${TARGET} SOURCES)
	FOREACH(SOURCE ${SOURCES})
		LIST(APPEND L ${PATH}/${SOURCE})
	ENDFOREACH()
	ADD_TEST(StyleGuidelines-${TARGET} ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/cpplint.py --filter=${cpplint_filters} ${L})
ENDFUNCTION()
```

**CppUnit test runner pattern** (lines 32-50):
```cmake
IF(ENABLE_TESTING)
	INCLUDE(FindPythonInterp)
	FIND_LIBRARY(CPPUNIT cppunit)
	ADD_SUBDIRECTORY(common)
	ADD_SUBDIRECTORY(service)

	ADD_EXECUTABLE(TestRunner cppunit.cpp)
	TARGET_LINK_LIBRARIES(TestRunner cppunit TelldusCommonTests TelldusServiceTests)
	ADD_DEPENDENCIES(TestRunner TelldusCommonTests TelldusServiceTests)

	ADD_SOURCES(TelldusCommon ${CMAKE_SOURCE_DIR}/common)
	ADD_SOURCES(${telldus-core_TARGET} ${CMAKE_SOURCE_DIR}/client)
	ADD_SOURCES(${telldus-service_TARGET} ${CMAKE_SOURCE_DIR}/service)

	ADD_TEST(cppunit ${CMAKE_CURRENT_BINARY_DIR}/TestRunner)
	IF (UNIX)
		ADD_TEST(cppcheck cppcheck --quiet --error-exitcode=2 ${CMAKE_SOURCE_DIR})
	ENDIF()
ENDIF()
```

**Pattern for test modifications:**
- Change `SET(ENABLE_TESTING FALSE ...)` to `SET(ENABLE_TESTING TRUE ...)` or remove the default
- Keep cpplint filters unchanged (tab indentation project convention)
- Keep cppcheck test registration on Unix
- The `ADD_SOURCES` function registers cpplint as CTest tests

---

### `.gitignore` (config)

**Analog:** `.gitignore` (exact)

**Existing pattern** (lines 1-7):
```
build/
qtcreator-build/
Doxyfile
html/
latex/
CMakeLists.txt.user
*.pyc
```

**Pattern:** `build/` is already present. No change needed unless adding subdir patterns like `build-*/`.

---

### `telldus-core/tdtool/main.cpp` (utility, request-response)

**Analog:** `telldus-core/tdtool/main.cpp` (exact)

**Fixed buffer / strcat pattern** (lines 139-194):
```cpp
char tempvalue[DATA_LENGTH];
tempvalue[0] = 0;
// ...
strcat(tempvalue, DEGREE);
strcat(humidityvalue, "%");
strcat(rainratevalue, " mm/h, ");
strcat(rainvalue, rainratevalue);
```

**Pattern for warning fixes:**
- Replace `strcat` with `strncat` or use `std::string` for buffer-safe concatenation
- Initialize all char buffers with `{0}` instead of `value[0] = 0`
- The `DATA_LENGTH = 20` constant may be too small for some sensor values with units appended

**getopt pattern** (lines 540-558):
```cpp
static struct option long_opts[] = {
	{ "list", 0, 0, 'l' },
	{ "list-sensors", 0, 0, LIST_KV_SENSORS },
	// ...
	{ 0, 0, 0, 0}
};
```

---

### `telldus-core/service/SettingsConfuse.cpp` (service, CRUD)

**Analog:** `telldus-core/service/SettingsConfuse.cpp` (exact)

**const_cast warning pattern** (lines 364-407):
```cpp
cfg_opt_t controller_opts[] = {
	CFG_INT(const_cast<char *>("id"), -1, CFGF_NONE),
	CFG_STR(const_cast<char *>("name"), const_cast<char *>(""), CFGF_NONE),
	CFG_INT(const_cast<char *>("type"), 0, CFGF_NONE),
	CFG_STR(const_cast<char *>("serial"), const_cast<char *>(""), CFGF_NONE),
	CFG_END()
};
```

**Pattern for warning fixes:**
- The `const_cast<char *>` is required because libconfuse C API takes `char*` for string literals
- Comment at line 365 explains: "All the const_cast keywords is to remove the compiler warnings generated by the C++-compiler"
- Modern compilers may still warn about `const_cast` of string literals
- Option: use C-style `char` arrays instead: `char id_str[] = "id"; CFG_INT(id_str, ...)`
- Or suppress with pragma if libconfuse API cannot be changed

**FILE* open pattern** (lines 105-106, 151-152, 198-199, 208-209, 304-305, 351-352):
```cpp
FILE *fp = fopen(CONFIG_FILE, "we");  // e for setting O_CLOEXEC on the file handle
if (!fp) {
	return TELLSTICK_ERROR_PERMISSION_DENIED;
}
```

---

### `telldus-core/common/Strings.cpp` (utility, transform)

**Analog:** `telldus-core/common/Strings.cpp` (exact)

**toupper warning pattern** (lines 102-107):
```cpp
bool TelldusCore::comparei(std::wstring stringA, std::wstring stringB) {
	transform(stringA.begin(), stringA.end(), stringA.begin(), toupper);
	transform(stringB.begin(), stringB.end(), stringB.begin(), toupper);
	return stringA == stringB;
}
```

**Pattern for warning fix:**
- `toupper` without cast causes "deprecated conversion from string constant to char*" or similar
- Fix: `transform(stringA.begin(), stringA.end(), stringA.begin(), static_cast<int(*)(int)>(toupper));`
- Or use lambda: `[](unsigned char c){ return std::toupper(c); }`

**iconv constness pattern** (lines 64-68, 209-213):
```cpp
#ifdef _FREEBSD
	const char *inPointer = inString;
#else
	char *inPointer = inString;
#endif
```

**Pattern:** Linux uses `char *inPointer` for iconv; modern iconv may use `const char*` on some systems. The FreeBSD branch already handles this.

---

### `telldus-core/service/TellStick_libftdi.cpp` (service, streaming)

**Analog:** `telldus-core/service/TellStick_libftdi.cpp` (exact)

**reinterpret_cast pattern** (line 181):
```cpp
processData( reinterpret_cast<char *>(&buf) );
```

**Pattern for warning fix:**
- `buf` is `unsigned char buf[1024]`; passing `&buf` instead of `buf` takes the address of the array
- Fix: `processData( reinterpret_cast<char *>(buf) );` (pass array, not address of array)
- Or: `processData( std::string(reinterpret_cast<char*>(buf), dwBytesRead) );` if processData takes string

**pthread cleanup pattern** (lines 152-153, 324):
```cpp
pthread_mutex_init(&d->eh.eMutex, NULL);
pthread_cond_init(&d->eh.eCondVar, NULL);
// ...
pthread_cond_broadcast(&d->eh.eCondVar);
```

**Pattern:** No corresponding `pthread_mutex_destroy`/`pthread_cond_destroy` in destructor — potential resource leak warning.

---

### `telldus-core/client/Client.cpp` (service, request-response)

**Analog:** `telldus-core/client/Client.cpp` (exact)

**strncpy warning pattern** (lines 215-220, 259-260):
```cpp
if (protocol && protocolLen) {
	strncpy(protocol, TelldusCore::wideToString(p).c_str(), protocolLen);
}
if (model && modelLen) {
	strncpy(model, TelldusCore::wideToString(m).c_str(), modelLen);
}
// ...
if (name && nameLen) {
	strncpy(name, TelldusCore::wideToString(n).c_str(), nameLen);
}
```

**Pattern for warning fix:**
- `strncpy` may not null-terminate if source is longer than `protocolLen`
- Fix: explicitly null-terminate after strncpy, or use `snprintf(protocol, protocolLen, "%s", ...)`
- Example: `strncpy(protocol, ..., protocolLen); protocol[protocolLen - 1] = '\0';`

**Singleton pattern** (lines 28-60):
```cpp
Client *Client::instance = 0;

Client::Client()
	: Thread() {
	d = new PrivateData;
	d->running = true;
	d->sensorCached = false;
	d->controllerCached = false;
	start();
}

Client::~Client(void) {
	stopThread();
	wait();
	{
		TelldusCore::MutexLocker locker(&d->mutex);
	}
	delete d;
}
```

---

## Shared Patterns

### Compiler Warning Flags (Linux)
**Source:** `telldus-core/client/CMakeLists.txt` lines 107-109
**Apply to:** All C++ targets when building on Linux
```cmake
IF (UNIX)
	SET_TARGET_PROPERTIES( ${telldus-core_TARGET} PROPERTIES COMPILE_FLAGS "-fPIC -fvisibility=hidden")
ENDIF (UNIX)
```

**Pattern to add globally in `telldus-core/CMakeLists.txt`:**
```cmake
IF(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
	ADD_COMPILE_OPTIONS(
		-Wall
		-Wextra
		-Wdeprecated-declarations
		-Wconversion
		-Wsign-conversion
		-Werror=deprecated-declarations
		-Werror=return-type
	)
ENDIF()
```

### CppUnit Test Registration
**Source:** `telldus-core/tests/common/CommonTests.h` and `telldus-core/tests/service/ServiceTests.h`
**Apply to:** All new test suites
```cpp
namespace CommonTests {
	inline void setup() {
		CPPUNIT_TEST_SUITE_REGISTRATION (StringsTest);
	}
}
```

### Test Fixture Pattern
**Source:** `telldus-core/tests/common/StringsTest.h`
**Apply to:** All new unit tests
```cpp
class StringsTest : public CPPUNIT_NS :: TestFixture
{
	CPPUNIT_TEST_SUITE (StringsTest);
	CPPUNIT_TEST (formatfTest);
	CPPUNIT_TEST_SUITE_END ();

public:
	void setUp (void);
	void tearDown (void);

protected:
	void formatfTest(void);
};
```

### PIMPL Pattern
**Source:** `telldus-core/service/SettingsConfuse.cpp` lines 18-24, `telldus-core/client/Client.cpp` lines 19-26
**Apply to:** All C++ classes in the codebase
```cpp
class Settings::PrivateData {
public:
	PrivateData()
		: cfg(NULL), var_cfg(NULL) {}
	cfg_t *cfg;
	cfg_t *var_cfg;
};
```

### Copyright Header
**Source:** Most `.cpp` files in `telldus-core/`
**Apply to:** Any new C++ source files
```cpp
//
// Copyright (C) 2012 Telldus Technologies AB. All rights reserved.
//
// Copyright: See COPYING file that comes with this distribution
//
//
```

### Mutex Locking Pattern
**Source:** `telldus-core/service/DeviceManager.cpp` lines 54-64
**Apply to:** All threaded service code
```cpp
{
	TelldusCore::MutexLocker deviceListLocker(&d->lock);
	for (DeviceMap::iterator it = d->devices.begin(); it != d->devices.end(); ++it) {
		{TelldusCore::MutexLocker deviceLocker(it->second);}
		delete(it->second);
	}
}
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `CMakePresets.json` | config | batch | No CMake preset files exist in the repository; modern CMake 3.20+ feature not previously used |
| `scripts/install-arch-deps.sh` | utility | batch | No dependency installation scripts exist; closest is `udev.sh` but it's a udev hook, not a package installer |

## Metadata

**Analog search scope:** `telldus-core/`, `.gitignore`, `rfcmd/`, `scripts/` (searched via glob)
**Files scanned:** 25+ source and CMake files
**Pattern extraction date:** 2026-05-14

### Key Patterns Identified
- All CMake files use older 2.x-style uppercase commands with modern minimum version
- Tests are opt-in via `ENABLE_TESTING` cache variable (default FALSE)
- CppUnit test runner in `cppunit.cpp` uses `CompilerOutputter` and `XmlOutputter`
- Service tests link against `TelldusServiceStatic` (static rebuild of service)
- cpplint filters explicitly prefer tab indentation and disable whitespace checks
- Platform code uses `#ifdef _LINUX` / `#ifdef _WINDOWS` / `#ifdef _MACOSX` preprocessor branches
- PIMPL pattern with raw `PrivateData` pointers is standard across the codebase
- `const_cast<char*>` is used extensively for libconfuse C API compatibility
- `strncpy` without explicit null-termination appears in client string getters
- `reinterpret_cast` used for unsigned char[] to char* conversions in FTDI I/O
