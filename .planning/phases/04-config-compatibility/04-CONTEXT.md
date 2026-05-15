# Phase 04: Config Compatibility - Context

**Gathered:** 2026-05-15T00:00:00+02:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 preserves existing `tellstick.conf` behavior and state separation so existing 433 MHz devices keep working without re-pairing, on both native Linux and Docker. It addresses config path hardcoding, runtime state directory deprecation (`/var/state`), write behavior on user-provided configs, and auto-reload behavior.

This phase does not implement Docker runtime (Phase 5), hardware verification (Phase 7), or documentation (Phase 8). It also does not create a Dockerfile — that belongs to Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Runtime State Directory
- **D-04-01:** Runtime state file (`telldus-core.conf`) lives at `/var/lib/telldus/telldus-core.conf`. This replaces the deprecated `/var/state` path that does not exist on modern Arch Linux or Debian/Raspberry Pi OS.
- **D-04-02:** The daemon auto-creates `/var/lib/telldus` on startup if it does not exist. This keeps Docker and native setups working without manual `mkdir` steps.
- **D-04-03:** For v1, run as root with state file `644` and directory `755`. A dedicated `telldus` user is deferred to v2 packaging/service hardening.
- **D-04-04:** State path is configurable at compile-time via CMake `STATE_INSTALL_DIR` (default `/var/lib/telldus`) and overridable at runtime via `TELLDUS_STATE_DIR` environment variable.

### Config Path Flexibility
- **D-04-05:** Stable config (`tellstick.conf`) defaults to `/etc/tellstick.conf` (compile-time via `CONFIG_PATH`) and is overridable at runtime via `TELLDUS_CONFIG_FILE` environment variable.
- **D-04-06:** If the config file is missing at startup, the daemon starts with zero devices and logs a warning. It does not fail to start.
- **D-04-07:** The daemon watches the stable config file for changes and reloads automatically (using inotify or equivalent). This is a v1 convenience for users editing configs.
- **D-04-08:** The var config (`telldus-core.conf`) is internal state owned by the daemon. It does NOT auto-reload.

### Write Behavior on Stable Config
- **D-04-09:** Preserve original behavior — the daemon is allowed to write to `tellstick.conf` when devices are added, removed, or settings change. This means bind-mounted configs in Docker must be writeable.
- **D-04-10:** If a write to `tellstick.conf` fails (e.g., read-only filesystem, permission denied), the operation fails and returns an error to the client (`TELLSTICK_ERROR_PERMISSION_DENIED`). No silent data loss.
- **D-04-11:** Same strict behavior for var config writes — fail and return error if `telldus-core.conf` cannot be written.
- **D-04-12:** No backup is created before writing to `tellstick.conf`. Preserve original behavior for v1 simplicity.

### Cross-Platform Scope
- **D-04-13:** Phase 4 is Linux-only v1. The codebase already uses `#ifdef _LINUX` / `#ifdef _WINDOWS` / `#ifdef _MACOSX` guards and CMake platform branches. Non-Linux config paths remain untouched.

### Claude's Discretion
- The agent may choose the exact inotify implementation (inotify, fanotify, or stat polling) based on portability and complexity.
- The agent may adjust the auto-reload debounce interval based on filesystem behavior.
- The agent may choose whether to implement env var overrides via `getenv()` in `SettingsConfuse.cpp` or via a small wrapper — whatever is least invasive.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Maps Phase 4 to CONF-01, CONF-02, CONF-04
- `.planning/ROADMAP.md` — Defines Phase 4 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Prior Phase Context
- `.planning/phases/01-headless-build-boundary/01-CONTEXT.md` — Build boundary decisions
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` — Arch build, CMake presets, test strategy
- `.planning/phases/03-raspberry-pi-portability/03-CONTEXT.md` — Debian/aarch64 build verification

### Codebase Maps
- `.planning/codebase/STACK.md` — Build systems, dependencies, and component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client/headless architecture and Settings abstraction
- `.planning/codebase/INTEGRATIONS.md` — Hardware, IPC, C API, and platform integration boundaries

### Source Entry Points
- `telldus-core/service/SettingsConfuse.cpp` — Linux config parsing, device state read/write, file I/O
- `telldus-core/service/config.h.in` — CMake-generated config paths (`CONFIG_PATH`, `VAR_CONFIG_PATH`)
- `telldus-core/service/CMakeLists.txt` — CMake install paths for `tellstick.conf` and `telldus-core.conf`
- `telldus-core/service/tellstick.conf` — Example stable config file
- `telldus-core/service/telldus-core.conf` — Empty var config template
- `telldus-core/service/EventUpdateManager.cpp` — References `SCRIPT_PATH` and `config.h`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsConfuse.cpp`: Already handles config read, write, device state persistence, and libconfuse parsing. The file I/O paths (`CONFIG_FILE`, `VAR_CONFIG_FILE`) are compile-time constants derived from `config.h`.
- `config.h.in`: CMake template that receives `SYSCONF_INSTALL_DIR` and `STATE_INSTALL_DIR`. Changing these CMake defaults propagates to the compiled binary.
- `telldus-core.conf`: Empty template installed to `STATE_INSTALL_DIR`. The daemon reads/writes this at runtime.

### Established Patterns
- Config paths are compile-time constants via `config.h`. There is no current runtime override mechanism.
- The daemon writes to `CONFIG_FILE` (stable config) on device add/remove and setting changes.
- The daemon writes to `VAR_CONFIG_FILE` (runtime state) on device state changes (on/off, dim).
- libconfuse is used for both stable and var config parsing. The var config uses `CFGF_TITLE` sections for device IDs.
- `Log::warning()` is used for non-fatal config issues; `TELLSTICK_ERROR_PERMISSION_DENIED` is returned for write failures.

### Integration Points
- `SettingsConfuse.cpp` is the primary integration point. Any env var override logic should live here or in a thin wrapper.
- `CMakeLists.txt` install rules copy `tellstick.conf` to `SYSCONF_INSTALL_DIR` and `telldus-core.conf` to `STATE_INSTALL_DIR`.
- `EventUpdateManager.cpp` references `SCRIPT_PATH` (from `config.h`) for script execution paths. Script path configurability is out of scope for v1.

</code_context>

<specifics>
## Specific Ideas

- `/var/state` does not exist on modern Arch Linux or Debian/Raspberry Pi OS. `/var/lib/telldus` is the standard replacement.
- Auto-creating `/var/lib/telldus` on startup avoids manual setup steps in both Docker and native environments.
- Env var overrides (`TELLDUS_CONFIG_FILE`, `TELLDUS_STATE_DIR`) are important for Docker testing and non-standard installs without recompiling.
- Inotify-based auto-reload should debounce to avoid reloading on every partial write.
- The existing `readConfig()` and `readVarConfig()` functions in `SettingsConfuse.cpp` should be reusable — only the file paths and existence checks need adjustment.

</specifics>

<deferred>
## Deferred Ideas

- **Dockerfile with efficient layer caching** — belongs in Phase 5: Docker Image and Config Mount. The user specifically requested this to avoid rebuilding images for every task.
- **Dedicated `telldus` system user** — security hardening for v2 packaging/systemd service management.
- **Script path configurability (`SCRIPT_PATH`)** — out of scope for v1; could be addressed when event scripting is needed.
- **Windows/macOS/FreeBSD config path modernization** — out of scope for v1 Linux-only.

</deferred>

---

*Phase: 04-Config Compatibility*
*Context gathered: 2026-05-15T00:00:00+02:00*
