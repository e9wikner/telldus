# Phase 4: Config Compatibility - Research

**Researched:** 2026-05-15
**Domain:** Linux configuration path modernization, state directory migration, runtime path overrides, and config reload behavior
**Confidence:** HIGH

## Summary

Phase 4 modernizes Telldus Core's Linux configuration infrastructure so existing `tellstick.conf` files work on modern Linux without device re-pairing. Research confirms three primary changes are needed:

1. **State directory migration:** The default `STATE_INSTALL_DIR` is `/var/state`, a deprecated path that does not exist on modern Arch Linux or Debian/Raspberry Pi OS. It must change to `/var/lib/telldus`.
2. **Runtime path flexibility:** Config and state paths are compile-time constants with no runtime override. Environment variables (`TELLDUS_CONFIG_FILE`, `TELLDUS_STATE_DIR`) are needed for Docker and non-standard installs.
3. **Daemon startup resilience:** The daemon does not auto-create its state directory, and does not auto-reload the stable config when it changes on disk.

The `SettingsConfuse.cpp` file already handles missing configs gracefully (logs warning, continues with zero devices) and returns `TELLSTICK_ERROR_PERMISSION_DENIED` on write failures. These existing behaviors should be preserved and extended.

**Primary recommendation:** Update `service/CMakeLists.txt` default state path, add thin env-var path resolution to `SettingsConfuse.cpp`, auto-create the state directory at daemon startup, and add inotify-based config auto-reload.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-04-01:** Runtime state file lives at `/var/lib/telldus/telldus-core.conf` (replaces `/var/state`).
- **D-04-02:** Daemon auto-creates `/var/lib/telldus` on startup if missing.
- **D-04-03:** For v1, run as root with state file `644` and directory `755`. Dedicated `telldus` user deferred.
- **D-04-04:** State path configurable at compile-time via `STATE_INSTALL_DIR` and at runtime via `TELLDUS_STATE_DIR`.
- **D-04-05:** Stable config defaults to `/etc/tellstick.conf` (compile-time via `CONFIG_PATH`) and overridable at runtime via `TELLDUS_CONFIG_FILE`.
- **D-04-06:** Missing config at startup starts with zero devices and logs a warning. Daemon does not fail to start.
- **D-04-07:** Daemon watches stable config for changes and reloads automatically (debounced).
- **D-04-08:** Var config (`telldus-core.conf`) is internal state — does NOT auto-reload.
- **D-04-09:** Preserve original write behavior — daemon may write to `tellstick.conf` on device changes. Bind-mounted configs must be writable.
- **D-04-10:** Write failures return `TELLSTICK_ERROR_PERMISSION_DENIED`. No silent data loss.
- **D-04-11:** Same strict behavior for var config writes.
- **D-04-12:** No backup before writing to `tellstick.conf`. Preserve original v1 behavior.
- **D-04-13:** Linux-only v1. Non-Linux paths remain untouched.

### Agent's Discretion
- Exact inotify implementation (inotify, fanotify, or stat polling) based on portability.
- Auto-reload debounce interval based on filesystem behavior.
- Env var override implementation location (in `SettingsConfuse.cpp` or thin wrapper).

### Deferred Ideas (OUT OF SCOPE)
- Dockerfile creation — belongs to Phase 5.
- Dedicated `telldus` system user — v2 hardening.
- Script path configurability (`SCRIPT_PATH`) — v2.
- Windows/macOS/FreeBSD path modernization — out of scope for v1.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONF-01 | Existing `tellstick.conf` files remain compatible | Verified: `SettingsConfuse.cpp` uses libconfuse with identical grammar; no format changes needed |
| CONF-02 | Runtime state remains separate from user-provided config | Verified: `VAR_CONFIG_FILE` is separate from `CONFIG_FILE`; writes go to different paths |
| CONF-04 | No v1 workflow requires re-pairing or re-learning | Verified: config parsing is unchanged; only paths and reload behavior are modified |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Config path resolution | `SettingsConfuse.cpp` | `config.h` (compile-time defaults) | Runtime env vars checked first, fall back to compile-time constants |
| State directory creation | `main_unix.cpp` (startup) | `SettingsConfuse.cpp` (lazy on first write) | Directory creation at startup is cleaner; lazy creation is acceptable fallback |
| Config auto-reload | `TelldusMain.cpp` event loop | `Settings` (re-read on signal) | Event loop owns file watching; Settings owns re-parsing |
| Config write failures | `SettingsConfuse.cpp` | Client API (`tdAddDevice`, etc.) | `fopen` failure returns `TELLSTICK_ERROR_PERMISSION_DENIED` to caller |

## Standard Stack

### Core
| Component | Current Default | New Default | Purpose | Verification |
|-----------|---------------|-------------|---------|------------|
| `SYSCONF_INSTALL_DIR` | `/etc` | `/etc` (unchanged) | Stable config directory | `CMakeLists.txt` line 101 |
| `STATE_INSTALL_DIR` | `/var/state` | `/var/lib/telldus` | Runtime state directory | Modern Linux FHS; `/var/state` absent on Arch/Debian |
| `CONFIG_FILE` | `/etc/tellstick.conf` | `/etc/tellstick.conf` (or `TELLDUS_CONFIG_FILE`) | Device/controller definitions | `SettingsConfuse.cpp` line 29 |
| `VAR_CONFIG_FILE` | `/var/state/telldus-core.conf` | `/var/lib/telldus/telldus-core.conf` (or `TELLDUS_STATE_DIR`) | Device on/off/dim state | `SettingsConfuse.cpp` line 30 |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `inotify` (Linux) | Watch `tellstick.conf` for changes | Auto-reload per D-04-07 |
| `mkdir -p` equivalent (`std::filesystem` or `mkdir`) | Create state directory | Daemon startup per D-04-02 |
| `getenv(3)` | Read `TELLDUS_CONFIG_FILE`, `TELLDUS_STATE_DIR` | Runtime override per D-04-04, D-04-05 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `inotify` | `stat` polling every N seconds | Polling is simpler but has latency and CPU cost; inotify is standard on modern Linux |
| `std::filesystem::create_directories` | `mkdir(2)` with parent creation loop | `std::filesystem` requires C++17; `mkdir -p` shell-out is ugly; manual `mkdir` loop is acceptable in C++98/03 codebase |
| Env var override in `SettingsConfuse.cpp` | CMake compile-time only | Without runtime override, every Docker test requires recompilation; env vars are the standard container pattern |

## Architecture Patterns

### Pattern 1: Compile-Time Default + Runtime Override
**What:** Use CMake `CACHE PATH` for compile-time defaults, then check `getenv()` at runtime in `SettingsConfuse.cpp`. Fall back to compile-time constant if env var is absent.
**When to use:** Any path that needs to differ between native and Docker without recompilation.
**Example:**
```cpp
// In SettingsConfuse.cpp or helper
const char* getConfigFilePath() {
    const char* env = getenv("TELLDUS_CONFIG_FILE");
    return env ? env : CONFIG_FILE;
}
```

### Pattern 2: State Directory Auto-Creation at Startup
**What:** In `main_unix.cpp` before daemonizing, ensure the state directory exists with correct permissions.
**When to use:** Any daemon that writes to a path that may not exist on fresh systems or minimal containers.
**Example:**
```cpp
// In main_unix.cpp or TelldusMain::start()
const char* stateDir = getenv("TELLDUS_STATE_DIR") ? getenv("TELLDUS_STATE_DIR") : "/var/lib/telldus";
// create with 0755 if missing
```

### Pattern 3: Debounced inotify Config Reload
**What:** Add an inotify watch on the stable config file. When `IN_MODIFY` or `IN_CLOSE_WRITE` fires, set a timer/debounce. After 500ms of no further events, signal `Settings` to re-read.
**When to use:** User edits config file and expects daemon to pick up changes without restart.
**Where to integrate:** `TelldusMain.cpp` event loop already has `EventHandler` and timers. Add a file descriptor to the event handler set, or use a dedicated thread with `inotify_init1(IN_CLOEXEC | IN_NONBLOCK)`.

### Anti-Patterns to Avoid
- **Changing config file grammar:** The libconfuse opts arrays in `readConfig()` must not change. Existing user configs must parse identically.
- **Replacing compile-time constants entirely:** Keep `CONFIG_FILE` and `VAR_CONFIG_FILE` as fallbacks so builds without env vars still work.
- **Auto-creating the stable config directory:** `/etc` is owned by the OS. The daemon should NOT auto-create `/etc`; only the state directory under `/var/lib`.
- **Reloading var config:** `telldus-core.conf` is daemon-owned state. Reloading it externally would cause state races. Only stable config reloads per D-04-08.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config file watching | Manual `stat()` polling loop | `inotify` on Linux | Kernel-native; zero CPU when idle; standard since Linux 2.6.13 |
| Directory creation | Shell-out to `mkdir -p` | `mkdir()` with parent loop or `std::filesystem` if C++17 available | Avoids shell injection; portable within the process |
| Path override mechanism | Command-line arg parsing in daemon | Environment variables | Matches Docker/container conventions; simpler than adding a new CLI parser to the daemon |

## Common Pitfalls

### Pitfall 1: `/var/state` Missing on Modern Linux
**What goes wrong:** Daemon starts, tries to open `/var/state/telldus-core.conf`, file missing, `readVarConfig` returns false, daemon continues. Later, `setDeviceState` tries to write to `/var/state/telldus-core.conf`, `fopen` fails, state is lost, function returns false.
**Why it happens:** `/var/state` was historically used by some SysV init scripts but was never part of FHS. Modern Arch and Debian/Raspberry Pi OS do not create it.
**How to avoid:** Change `DEFAULT_STATE_INSTALL_DIR` to `/var/lib/telldus` in `service/CMakeLists.txt`. Ensure the directory is created at startup.
**Warning signs:** Log messages: "Unable to open var config file, /var/state/telldus-core.conf"; state not persisting across daemon restarts.

### Pitfall 2: Environment Variable Override Conflicts with Relative Paths
**What goes wrong:** User sets `TELLDUS_CONFIG_FILE=tellstick.conf` (relative path). Daemon tries to open it relative to its working directory, which may differ between systemd service, Docker container, and manual invocation.
**Why it happens:** `fopen` with relative paths uses `cwd`. Daemons typically `chdir("/")` after forking.
**How to avoid:** Accept both absolute and relative paths, but document that absolute paths are recommended. If the daemon `chdir`s after forking, resolve relative paths before daemonizing.
**Warning signs:** Config file found when running manually but not when started via systemd or Docker.

### Pitfall 3: inotify on Bind-Mounted Files in Docker
**What goes wrong:** User bind-mounts `/host/tellstick.conf` to `/etc/tellstick.conf` in Docker. inotify watch on `/etc/tellstick.conf` does not fire when the host file changes because the inode differs.
**Why it happens:** inotify watches inodes. Bind mounts can cause inode mismatches depending on filesystem and Docker storage driver.
**How to avoid:** Watch the parent directory (`/etc`) for `IN_CLOSE_WRITE` events and filter by filename, or use a periodic stat poll as fallback. Document this limitation.
**Warning signs:** Config changes on host are not reflected in container until restart.

### Pitfall 4: Config Reload Races with Active Writes
**What goes wrong:** `addNode()` writes to `CONFIG_FILE`, then re-reads it. If inotify fires during the write (before fclose), the reload may read a partially written file.
**Why it happens:** `fopen` + `cfg_print` + `fclose` is not atomic. inotify `IN_MODIFY` fires on every `write(2)`.
**How to avoid:** Debounce reloads (e.g., 500ms after last inotify event). The write is fast; a short debounce eliminates race reads.
**Warning signs:** Intermittent parse errors or missing devices after add/remove operations.

## Code Examples

### Verified Current Path Behavior
```cpp
// Source: telldus-core/service/SettingsConfuse.cpp lines 29-30
const char* CONFIG_FILE = CONFIG_PATH "/tellstick.conf";
const char* VAR_CONFIG_FILE = VAR_CONFIG_PATH "/telldus-core.conf";

// CONFIG_PATH and VAR_CONFIG_PATH come from config.h:
// Source: telldus-core/service/config.h.in
#define CONFIG_PATH "@SYSCONF_INSTALL_DIR@"
#define VAR_CONFIG_PATH "@STATE_INSTALL_DIR@"
```

### Verified CMake Defaults
```cmake
# Source: telldus-core/service/CMakeLists.txt lines 101-107
SET(SYSCONF_INSTALL_DIR "/etc" CACHE PATH "The sysconfig install dir (default prefix/etc)")
IF (${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
    SET(DEFAULT_STATE_INSTALL_DIR "/var/spool")
ELSE ()
    SET(DEFAULT_STATE_INSTALL_DIR "/var/state")  # PROBLEM: does not exist on modern Linux
ENDIF ()
SET(STATE_INSTALL_DIR "${DEFAULT_STATE_INSTALL_DIR}" CACHE PATH "The directory to store state information of the devices")
```

### Verified Graceful Missing Config Handling
```cpp
// Source: telldus-core/service/SettingsConfuse.cpp lines 409-413
FILE *fp = fopen(CONFIG_FILE, "re");
if (!fp) {
    Log::warning("Unable to open config file, %s", CONFIG_FILE);
    return false;
}
// Settings constructor continues even if readConfig returns false:
// line 38: readConfig(&d->cfg); // d->cfg stays NULL if false
```

### Verified Write Failure Handling
```cpp
// Source: telldus-core/service/SettingsConfuse.cpp lines 105-108
FILE *fp = fopen(CONFIG_FILE, "we");
if (!fp) {
    return TELLSTICK_ERROR_PERMISSION_DENIED;
}
```

### Recommended Env Var Override Pattern
```cpp
// To be added in SettingsConfuse.cpp or helper
static std::string resolveConfigPath() {
    const char* env = getenv("TELLDUS_CONFIG_FILE");
    return env ? std::string(env) : std::string(CONFIG_FILE);
}

static std::string resolveStateDir() {
    const char* env = getenv("TELLDUS_STATE_DIR");
    return env ? std::string(env) : std::string(VAR_CONFIG_PATH);
}
```

### Recommended Directory Creation Pattern
```cpp
// To be added in main_unix.cpp before daemonizing or in TelldusMain::start()
#include <sys/stat.h>

void ensureStateDirectory(const char* path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        if (mkdir(path, 0755) != 0 && errno != EEXIST) {
            Log::warning("Failed to create state directory %s: %s", path, strerror(errno));
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/var/state` as state directory | `/var/lib/telldus` | 2026-05-15 (this phase) | Compatible with modern FHS; works on Arch, Debian, Raspberry Pi OS |
| Compile-time only paths | Compile-time defaults + runtime env overrides | 2026-05-15 (this phase) | Docker bind-mount testing without recompilation |
| No config reload | Debounced inotify auto-reload | 2026-05-15 (this phase) | Users can edit config without restarting daemon |

**Deprecated/outdated:**
- `/var/state` — obsolete path, not created by any modern distro.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `inotify` is available on all target Linux systems (Arch, Debian, Raspberry Pi OS) | Architecture Patterns | Fallback to stat polling is acceptable per agent's discretion |
| A2 | Existing `tellstick.conf` files use only the libconfuse grammar already defined in `readConfig()` | Code Examples | If users have hand-edited configs with syntax extensions, they would fail to parse; but the grammar covers all known Telldus features |
| A3 | The daemon runs with sufficient privileges to create `/var/lib/telldus` (root in v1) | State of the Art | If run as non-root without the directory pre-created, startup would log a warning; this is acceptable for v1 per D-04-03 |
| A4 | `getenv()` is thread-safe for reading in the Settings constructor (called once at startup) | Recommended Env Var Pattern | `getenv()` is not thread-safe with concurrent `setenv`, but Settings reads paths only at construction time before any client threads exist |

## Open Questions

1. **Should inotify watch the file or the directory?**
   - What we know: Watching the file (`/etc/tellstick.conf`) works for direct edits. Watching the directory (`/etc`) catches renames and atomic replacements.
   - What's unclear: Docker bind-mount behavior with inotify.
   - Recommendation: Watch the parent directory for `IN_CLOSE_WRITE` and filter by filename `tellstick.conf`. This handles both direct edits and atomic replacements.

2. **Should state directory creation be in `main_unix.cpp` or `TelldusMain::start()`?**
   - What we know: `TelldusMain::start()` is the cross-platform service entry point. `main_unix.cpp` is Linux-specific.
   - What's unclear: Whether `TelldusMain::start()` is called before or after daemonization (chdir to `/`).
   - Recommendation: Create directory in `main_unix.cpp` before calling `TelldusMain::start()`, or in `TelldusMain::start()` itself before constructing `Settings`. The path string must be resolved before `chdir`.

3. **Should env var overrides apply to the install rules in CMakeLists.txt?**
   - What we know: CMake install rules use `STATE_INSTALL_DIR` and `SYSCONF_INSTALL_DIR` at build time.
   - What's unclear: Whether install-time env vars matter.
   - Recommendation: No. Install rules remain compile-time. Runtime env vars override only the daemon's reading/writing behavior.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `inotify` API | Config auto-reload | ✓ | Linux 2.6.13+ | Stat polling |
| `getenv()` | Runtime path override | ✓ | POSIX | None needed |
| `mkdir()` | State directory creation | ✓ | POSIX | None needed |
| `libconfuse` | Config parsing | ✓ | 3.3+ | Already required for build |
| Existing `tellstick.conf` | Validation test | ✓ | User-provided | Use bundled `telldus-core/service/tellstick.conf` as proxy |

**Missing dependencies with no fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | CMake build + shell test scripts + daemon smoke test |
| Config file | `telldus-core/service/CMakeLists.txt` (for path defaults), `telldus-core/service/SettingsConfuse.cpp` (for runtime behavior) |
| Quick run command | `cmake -B build/headless -DSTATE_INSTALL_DIR=/var/lib/telldus ... && cmake --build build/headless` |
| Full suite command | Shell script that launches daemon with overridden paths, verifies config read, state write, and reload |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| CONF-01 | Existing tellstick.conf parses correctly | integration | Shell script: copy sample config, run daemon, list devices with tdtool | ❌ Wave 0 (test script to be created) | ⬜ pending |
| CONF-01 | Config auto-reload picks up edited config | integration | Edit config while daemon runs, verify tdtool lists new device | ❌ Wave 0 | ⬜ pending |
| CONF-02 | State persists in separate file | integration | Turn device on, stop daemon, restart, verify state is on | ❌ Wave 0 | ⬜ pending |
| CONF-04 | No device re-pairing needed | manual | Use existing user config, verify all devices are recognized | ❌ Wave 0 | ⬜ pending |

### Sampling Rate
- **Per task commit:** Build the modified daemon and run a quick smoke test
- **Per wave merge:** Full path override + state persistence + reload verification
- **Phase gate:** Existing config loads correctly; state is separate; reload works; Docker path override works

### Wave 0 Gaps
- [ ] Shell test script for config path override and state persistence
- [ ] Sample realistic `tellstick.conf` with multiple devices and protocols
- [ ] Documentation of env var usage for Docker

*(No test framework gaps — build and shell scripts cover all phase requirements)*

## Security Domain

> This phase touches file system paths and permissions. No network exposure or user input parsing is introduced.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | Partial | Daemon runs as root in v1 (deferred hardening) |
| V5 Input Validation | Partial | Env var paths could be manipulated; sanitize/validate before use |
| V6 Cryptography | No | — |

### Known Threat Patterns for Config Handling

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via env vars (`TELLDUS_CONFIG_FILE=../../etc/shadow`) | Tampering | Do not validate env var paths against a whitelist; document that absolute paths are required |
| World-writable state file (`telldus-core.conf` with 666) | Tampering | Remove `WORLD_WRITE` from install permissions; use 644 for file, 755 for dir |
| Config reload reads attacker-controlled file | Tampering | inotify watches a specific path; attacker needs write access to that path already |

## Sources

### Primary (HIGH confidence)
- `telldus-core/service/SettingsConfuse.cpp` (live read) — verified compile-time path constants, graceful missing-file handling, write failure returns `TELLSTICK_ERROR_PERMISSION_DENIED`
- `telldus-core/service/config.h.in` (live read) — verified CMake template variables `CONFIG_PATH` and `VAR_CONFIG_PATH`
- `telldus-core/service/CMakeLists.txt` (live read) — verified `DEFAULT_STATE_INSTALL_DIR "/var/state"` and install permissions
- `telldus-core/service/tellstick.conf` (live read) — verified example config grammar matches `readConfig()` opts
- `man inotify`, `man 7 inotify` — confirmed API availability and behavior for Linux file watching
- `man getenv`, `man mkdir` — confirmed POSIX API availability

### Secondary (MEDIUM confidence)
- Phase 3 SUMMARY (03-03-SUMMARY.md) — confirms build system works on Debian aarch64; paths are the remaining gap
- Phase 1/2 build logs — confirm zero-warning compilation; changes to `SettingsConfuse.cpp` must maintain this
- FHS 3.0 specification — `/var/lib` is the standard location for variable state information

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Path defaults: HIGH — direct observation of CMakeLists.txt and config.h.in
- Runtime override mechanism: HIGH — standard POSIX `getenv()` pattern
- Config reload: MEDIUM-HIGH — inotify is standard, but integration into TelldusMain event loop requires careful threading
- Existing config compatibility: HIGH — libconfuse grammar is unchanged

**Research date:** 2026-05-15
**Valid until:** 60 days (Linux path conventions are stable; inotify API is stable)
