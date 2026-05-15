# Phase 05: Docker Image and Config Mount - Context

**Gathered:** 2026-05-15T08:50:00Z
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 builds a minimal Docker image containing the headless Telldus Core runtime (`telldusd`, `libtelldus-core.so`, `tdtool`, `tdadmin`) and accepts a bind-mounted `/etc/tellstick.conf`. The image is multi-architecture (`amd64` + `arm64`) to support both the Arch Linux development host and Raspberry Pi OS/Debian `aarch64` deployment target.

This phase does not implement containerized daemon runtime with USB passthrough (Phase 6), hardware verification (Phase 7), or operator documentation (Phase 8). It focuses on image construction, config mount behavior, and build reproducibility.

</domain>

<decisions>
## Implementation Decisions

### Dockerfile Build Strategy
- **D-05-01:** Multi-stage Dockerfile. Build stage compiles inside `debian:bookworm-slim` (proven in Phase 3); final stage copies only runtime artifacts.
- **D-05-02:** Deps-first, source-last layer caching. Install Debian packages and run CMake configure in early layers (cacheable), then `COPY` source and build in later layers. Source changes invalidate only the build layer, not dependency installation.
- **D-05-03:** Final runtime stage uses a distroless or scratch base. The planner must handle shared library copying (libftdi1, libconfuse, and their dependencies) into the minimal final image.
- **D-05-04:** CppUnit tests run during the build stage (`ctest -R cppunit`). The build fails if tests fail, ensuring only verified binaries reach the final image.

### Image Contents Boundary
- **D-05-05:** Image includes `telldusd`, `libtelldus-core.so`, `tdtool`, and `tdadmin`. This is the full headless runtime plus verification/admin tools.
- **D-05-06:** Image includes a sample `tellstick.conf` at `/etc/tellstick.conf` as reference and fallback. A bind mount overwrites it when the operator provides their own config.
- **D-05-07:** Test binaries (CppUnit `TestRunner`) are stripped from the final image. Tests run during build; the final image contains only production binaries.

### Container Entrypoint
- **D-05-08:** Direct binary entrypoint with smart dispatch. The container runs `telldusd` as PID 1 by default, but detects if the first argument is `tdtool` and dispatches to it for one-shot commands.
- **D-05-09:** Support one-shot `tdtool` execution. Example: `docker run --rm telldus tdtool --list` should work. The real use case for `tdtool` requiring a running daemon is `docker exec <container> tdtool --list`.
- **D-05-10:** Use `tini` or `dumb-init` as the init system. Provides proper SIGTERM forwarding and zombie reaping. The entrypoint script or binary runs under the init system.
- **D-05-11:** `telldusd` logs to stdout/stderr inside the container. Docker captures logs via `docker logs`. The planner must adjust or verify the daemon's logging mechanism to write to stdout.

### Multi-Architecture Build Scope
- **D-05-12:** Dockerfile supports multi-architecture builds for `linux/amd64` and `linux/arm64`. Matches both the Arch Linux development host and Raspberry Pi OS/Debian `aarch64` deployment target.
- **D-05-13:** Architecture-agnostic Dockerfile. No `ARG TARGETARCH` or platform-specific RUN commands. The build dependencies and CMake preset are already cross-platform (proven in Phase 3).
- **D-05-14:** Single image tag (`:latest`) with a multi-arch manifest. Docker resolves the correct architecture automatically on pull.
- **D-05-15:** Create `scripts/build-docker.sh` helper script. Encapsulates `docker buildx` with platform flags, builder setup, and tagging. Makes multi-arch builds reproducible for operators and CI.

### Agent's Discretion
- The agent may choose between `tini` and `dumb-init` based on availability in the base image and size.
- The agent may structure the smart entrypoint as a POSIX shell script or a small compiled binary — whichever is simpler and handles signal forwarding correctly through the init system.
- The agent may decide the exact shared library copying strategy for the distroless/scratch final stage (e.g., `ldd` + COPY, or static linking if feasible).
- The agent may adjust the CMake build parallelism based on available resources, as long as the build remains reliable.
- The agent may choose how to redirect `telldusd` logging to stdout (e.g., symlink `/var/log/telldus` to `/dev/stdout`, patch Log.cpp, or run with appropriate flags).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Maps Phase 5 to DOCK-01, DOCK-03, CONF-03
- `.planning/ROADMAP.md` — Defines Phase 5 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Prior Phase Context
- `.planning/phases/01-headless-build-boundary/01-CONTEXT.md` — Build boundary decisions
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` — Arch build, CMake presets, test strategy
- `.planning/phases/03-raspberry-pi-portability/03-CONTEXT.md` — Debian/aarch64 build verification, multi-arch Docker buildx
- `.planning/phases/04-config-compatibility/04-CONTEXT.md` — Config path flexibility, runtime state directory, auto-reload behavior

### Codebase Maps
- `.planning/codebase/STACK.md` — Build systems, dependencies, and component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client/headless architecture and logging
- `.planning/codebase/INTEGRATIONS.md` — Hardware, IPC, and platform integration boundaries

### Source Entry Points
- `telldus-core/CMakeLists.txt` — Core project root with build options (`BUILD_TDTOOL`, `BUILD_TDADMIN`, `ENABLE_TESTING`, `FTDI_ENGINE`)
- `telldus-core/service/CMakeLists.txt` — Daemon target and Linux runtime dependencies
- `telldus-core/client/CMakeLists.txt` — Shared C API library target
- `telldus-core/tdtool/CMakeLists.txt` — CLI target
- `telldus-core/service/SettingsConfuse.cpp` — Linux config parsing and file I/O paths
- `telldus-core/service/config.h.in` — CMake-generated config paths (`CONFIG_PATH`, `VAR_CONFIG_PATH`)
- `telldus-core/service/tellstick.conf` — Example stable config file (to include as sample)
- `CMakePresets.json` — Headless preset with `FTDI_ENGINE=libftdi`, `ENABLE_TESTING=TRUE`
- `scripts/install-debian-deps.sh` — Debian dependency installer (reusable for build stage)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CMakePresets.json`: Existing `headless` preset is architecture-agnostic and defines the exact build configuration needed for the Docker build stage.
- `scripts/install-debian-deps.sh`: Already contains the full Debian package list for build dependencies. Can be reused in the Dockerfile build stage.
- `telldus-core/service/tellstick.conf`: Example config file can be copied into the image as the sample/fallback config.
- Phase 3 already proved the full build, test, and smoke-test cycle works inside `debian:bookworm-slim` via `docker buildx --platform linux/arm64`.

### Established Patterns
- Multi-stage Docker builds: deps installed first, source copied later for layer caching.
- `docker buildx` with QEMU user-mode emulation for `linux/arm64` builds (proven in Phase 3, but single-threaded builds are more reliable under QEMU).
- CMake presets control build configuration in a version-controlled, reproducible way.
- The daemon writes to `CONFIG_FILE` (stable config) and `VAR_CONFIG_FILE` (runtime state) at paths defined in `config.h`.

### Integration Points
- The Dockerfile build stage must integrate with `scripts/install-debian-deps.sh` for dependency installation.
- The final stage must copy runtime artifacts from the build stage: `telldusd`, `libtelldus-core.so`, `tdtool`, `tdadmin`, and sample `tellstick.conf`.
- The entrypoint must integrate with `tini`/`dumb-init` for signal handling and support both daemon mode and one-shot `tdtool` mode.
- Config bind mount integrates with Phase 4 decisions: the daemon auto-creates `/var/lib/telldus`, starts with zero devices if config is missing, and watches the config file for changes.
- The `scripts/build-docker.sh` helper must integrate with Phase 8 documentation (Docker build/run instructions).

</code_context>

<specifics>
## Specific Ideas

- The user specifically requested "Dockerfile with efficient layer caching" during Phase 4 discussion — this is now locked as D-05-02.
- Phase 3 discovered that QEMU arm64 builds can segfault under parallel compilation; single-threaded builds (`--parallel 1`) are the reliable path. However, the user chose architecture-agnostic Dockerfile (D-05-13), so any parallelism adjustment should be runtime/environmental, not Dockerfile-conditional.
- Distroless/scratch final stage is ambitious with shared library dependencies (libftdi1, libconfuse, libusb-1.0-0). The planner should evaluate whether `debian:bookworm-slim` minus build tools is more practical, or whether explicit `.so` copying to a minimal base works reliably.
- The daemon's current logging mechanism (via `Log.cpp`) may write to syslog or files. Redirecting to stdout/stderr may require a code adjustment or a symlink strategy.
- The smart entrypoint for one-shot `tdtool` could be a small POSIX shell script that checks `$1` and either `exec tdtool "$@"` or `exec telldusd "$@"` (under `tini`).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-Docker Image and Config Mount*
*Context gathered: 2026-05-15T08:50:00Z*
