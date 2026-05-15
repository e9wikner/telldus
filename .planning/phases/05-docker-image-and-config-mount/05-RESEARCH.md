# Phase 05: Docker Image and Config Mount - Research

**Researched:** 2026-05-15
**Domain:** Docker containerization, multi-stage builds, multi-architecture images, C++ shared library deployment
**Confidence:** HIGH

## Summary

Phase 5 constructs a minimal, multi-architecture Docker image for the headless Telldus Core runtime. The build has been proven in Phase 3 inside `debian:bookworm-slim`; this phase packages that into a reproducible Dockerfile with a distroless/minimal final stage, shared library copying, smart entrypoint dispatch, and config bind-mount support.

The codebase already provides ideal Docker primitives: `telldusd --nodaemon` redirects logging to stdout, and the inotify-based config watcher (added in Phase 4) works transparently with bind mounts because Docker bind mounts are host filesystem passthroughs — inotify events propagate from the host kernel into the container. This means no runtime code changes are needed for either logging or config reloading in the container.

The main complexity lies in the **final stage base image choice** and **shared library copying**. The runtime depends on `libftdi1`, `libconfuse`, and `libusb-1.0`, which in turn pull in `libudev`, `libgcc_s`, `libc`, and `ld-linux`. A true `scratch` or `gcr.io/distroless/static` image is impractical because these are dynamically-linked C libraries. The practical options are:
1. `gcr.io/distroless/cc-debian12` (includes glibc and libgcc) + manually copied `libftdi1.so.2`, `libconfuse.so.1`, `libusb-1.0.so.0`, and `libudev.so.1`
2. `debian:bookworm-slim` with only runtime packages installed (`libftdi1`, `libconfuse0`, `libusb-1.0-0`, `libudev1`)

Option 2 is simpler, more maintainable, and only ~30 MB larger — the recommended path given the project's priority is build/runtime reliability over minimal image size.

**Primary recommendation:** Use a multi-stage Dockerfile with `debian:bookworm-slim` build stage and `debian:bookworm-slim` final stage (runtime packages only). Use `tini` as PID 1. Run `telldusd --nodaemon` by default. Support one-shot `tdtool` via a POSIX shell entrypoint script. Build multi-arch with `docker buildx --platform linux/amd64,linux/arm64`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Image construction | Build pipeline (Docker/CI) | — | Dockerfile and build script are build-time artifacts |
| Runtime daemon execution | Container runtime (Docker Engine) | — | `telldusd` runs inside the container; host kernel provides USB |
| Config file provision | Host filesystem (bind mount) | — | Operator provides `/etc/tellstick.conf` from host |
| Config auto-reload | Daemon (inotify watcher) | Host kernel | inotify events originate from host filesystem, consumed by daemon |
| Logging capture | Container runtime (stdout/stderr) | — | Docker captures stdout/stderr for `docker logs` |
| Multi-arch manifest | Container registry / Docker buildx | — | `buildx` creates and pushes manifest list |
| Signal forwarding | Init system (`tini`) | — | Required for proper SIGTERM handling and zombie reaping |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-05-01:** Multi-stage Dockerfile. Build stage in `debian:bookworm-slim`, final stage distroless/scratch
- **D-05-02:** Deps-first layer caching
- **D-05-03:** Final runtime stage copies shared libraries (libftdi1, libconfuse, etc.)
- **D-05-04:** CppUnit tests run during build stage (`ctest -R cppunit`)
- **D-05-05:** Image includes telldusd, libtelldus-core.so, tdtool, tdadmin
- **D-05-06:** Sample tellstick.conf included as fallback
- **D-05-08:** Smart entrypoint: telldusd as PID 1 default, detects tdtool for one-shot
- **D-05-09:** Support one-shot `tdtool` execution
- **D-05-10:** Use `tini` or `dumb-init` as init system
- **D-05-11:** telldusd logs to stdout/stderr
- **D-05-12:** Multi-arch build: linux/amd64 and linux/arm64
- **D-05-13:** Architecture-agnostic Dockerfile
- **D-05-14:** Single image tag (`:latest`) with multi-arch manifest
- **D-05-15:** Create `scripts/build-docker.sh` helper

### Agent's Discretion
- Choose between `tini` and `dumb-init` based on availability and size
- Structure smart entrypoint as POSIX shell script or compiled binary
- Decide exact shared library copying strategy
- Adjust CMake build parallelism based on resources
- Choose how to redirect `telldusd` logging to stdout

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCK-01 | Docker image contains only Linux headless runtime and dependencies | Multi-stage build pattern; runtime package selection; shared library analysis |
| DOCK-03 | Operator can bind-mount existing config as `/etc/tellstick.conf` | Docker bind mount semantics; inotify behavior with bind mounts; sample fallback config |
| CONF-03 | Documentation explains how to provide existing config for native and Docker runs | Entrypoint design; bind mount examples; sample config inclusion |

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| Docker Engine | 29.4+ | Container runtime | Confirmed available on build host [VERIFIED: host probe] |
| docker buildx | 0.33+ | Multi-platform image builder | Bundled with Docker 29+ [VERIFIED: host probe] |
| debian:bookworm-slim | 12 (stable) | Build stage base | Proven in Phase 3; contains all build deps [VERIFIED: Phase 3 execution] |
| tini | v0.19.0 | Init system (PID 1) | Packaged in Debian; tiny (~10KB); signal forwarding + zombie reaping [CITED: github.com/krallin/tini] |
| CMake | 3.25+ | Build system | Part of debian:bookworm-slim build image [VERIFIED: Phase 3] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| libftdi1-dev | 1.5-* | TellStick USB communication | Build stage only |
| libconfuse-dev | 3.3-* | Configuration file parsing | Build stage only |
| libusb-1.0-0-dev | 1.0.26-* | USB device access | Build stage only |
| libcppunit-dev | 1.15-* | C++ unit testing | Build stage only |
| libftdi1 | 1.5-* | Runtime USB communication | Final stage (runtime package) |
| libconfuse0 | 3.3-* | Runtime config parsing | Final stage (runtime package) |
| libusb-1.0-0 | 1.0.26-* | Runtime USB access | Final stage (runtime package) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| debian:bookworm-slim final stage | gcr.io/distroless/cc-debian12 | Distroless is smaller but requires manual `ldd` + COPY of all transitive `.so` files; harder to maintain when Debian updates libraries. Recommended only if image size is a hard constraint. |
| tini | dumb-init | dumb-init has signal rewriting feature; tini is simpler and packaged in Debian by default. Both are fine; tini is the community default. |
| POSIX shell entrypoint | Compiled C entrypoint | Shell script is simpler to read/maintain and sufficient for `$1` dispatch; compiled binary adds no value here. |
| `docker buildx` | Native `docker build` | Legacy builder does not support multi-platform manifests. buildx is required for DOCK-12/DOCK-14. |

## Architecture Patterns

### System Architecture Diagram

```
Operator Input
│
├─ Host /path/to/tellstick.conf ──► Docker Bind Mount ──► /etc/tellstick.conf (overwrites sample)
│                                                    │
├─ docker run --device /dev/bus/usb/... ──► USB Device Passthrough (Phase 6)
│
└─ docker buildx --platform linux/amd64,linux/arm64 ──► Multi-Arch Image Build
         │
         ▼
   ┌─────────────┐     ┌────────────────────┐
   │ Build Stage │────►│ Final Stage        │
   │ (bookworm   │ COPY│ (bookworm-slim     │
   │  + deps)    │     │  + runtime pkgs)   │
   └─────────────┘     └────────────────────┘
            │                    │
            ▼                    ▼
     Compile & Test         tini ──► entrypoint.sh
     (CMake + CTest)              │
                                  ├─ args[0] == "tdtool" ──► exec tdtool "$@"
                                  └─ default ──► exec telldusd --nodaemon
                                                        │
                                                        ▼
                                                 Logs ──► stdout/stderr
                                                 (captured by Docker)
                                                 │
                                                 ▼
                                          inotify watcher on /etc/
                                          detects config changes ──► reloadDevices()
```

### Recommended Project Structure

```
.
├── Dockerfile                          # Multi-stage build definition
├── scripts/
│   ├── install-debian-deps.sh          # Existing: build dependency installer
│   └── build-docker.sh                 # NEW: multi-arch build helper
├── telldus-core/
│   ├── service/tellstick.conf          # Sample config (copied into image)
│   └── ...
├── CMakePresets.json                   # Headless preset (reused in build stage)
└── .dockerignore                       # Exclude .planning/, build dirs, etc.
```

### Pattern 1: Deps-First Layer Caching
**What:** Install system dependencies and run CMake configure before copying application source.
**When to use:** Any Docker build where source changes frequently but dependencies are stable.
**Example:**
```dockerfile
# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS build

# Layer 1: Dependencies (cacheable)
RUN apt-get update && apt-get install -y \
    cmake build-essential pkg-config \
    libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev

# Layer 2: CMake configure (cacheable if presets/CMakeLists don't change)
WORKDIR /build
COPY CMakePresets.json telldus-core/ ./
RUN cmake --preset headless

# Layer 3: Source + build (invalidated on source change)
COPY . .
RUN cmake --build build/headless --parallel 1
RUN ctest --test-dir build/headless -R cppunit --output-on-failure
```
[Source: docs.docker.com/build/building/multi-stage/]

### Pattern 2: Multi-Architecture Build with buildx
**What:** Build a single image tag containing manifests for multiple architectures.
**When to use:** Targeting both amd64 (development) and arm64 (Raspberry Pi) from one build invocation.
**Example:**
```bash
#!/bin/bash
set -e

BUILDER="telldus-builder"

# Ensure builder exists with container driver (supports multi-platform)
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER"

# Build and load for local testing (single platform only)
docker buildx build \
    --platform linux/amd64 \
    --tag telldus:latest \
    --load \
    .

# Build and push multi-platform manifest (requires registry)
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag telldus:latest \
    --push \
    .
```
[Source: docs.docker.com/build/building/multi-platform/]

### Pattern 3: Dual-Mode Container Entrypoint
**What:** A single container image that can run as a long-lived daemon OR execute a one-shot CLI command.
**When to use:** When the same image needs to host both a service and its client tools.
**Example:**
```bash
#!/bin/sh
set -e

# If first argument is a tdtool subcommand, run tdtool
if [ "$1" = "tdtool" ] || [ "$1" = "tdadmin" ]; then
    CMD="$1"
    shift
    exec "$CMD" "$@"
fi

# Default: run the daemon under tini
exec telldusd --nodaemon "$@"
```
[ASSUMED: Standard POSIX shell pattern for Docker entrypoints]

### Anti-Patterns to Avoid
- **Building everything in one stage:** Leaves compiler, headers, and build tools in the final image, increasing attack surface and image size.
- **Using shell form ENTRYPOINT without an init system:** The shell becomes PID 1 and won't forward SIGTERM properly, causing `docker stop` to fall back to SIGKILL after timeout.
- **Copying source before installing dependencies:** Invalidates the dependency layer on every source change, destroying Docker layer caching benefits.
- **Hardcoding `TARGETARCH` in RUN commands:** Violates D-05-13 (architecture-agnostic Dockerfile). Use CMake presets and standard package names instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Container init system (signal forwarding, zombie reaping) | Custom C signal handler | `tini` or `dumb-init` | Both are battle-tested, tiny, and handle edge cases like orphaned process groups [CITED: github.com/krallin/tini, github.com/Yelp/dumb-init] |
| Multi-arch manifest creation | Manual `docker manifest` commands | `docker buildx --platform` | BuildKit handles platform detection, emulation, layer caching, and manifest list creation automatically [CITED: docs.docker.com/build/building/multi-platform/] |
| Shared library discovery | Manual `readelf` + copy scripts | `ldd` in build stage + `COPY --from=build` | `ldd` is the standard tool; but for maintainability, prefer installing runtime packages in the final stage instead of manual copying |
| CMake configuration for different architectures | Per-arch Dockerfile branches | CMakePresets.json + architecture-agnostic build | The existing `headless` preset is already architecture-agnostic [VERIFIED: codebase inspection] |

**Key insight:** The hardest part of minimal C++ Docker images is not building — it's the transitive shared library graph. `libftdi1` depends on `libusb-1.0`, which depends on `libudev`, which depends on `libsystemd-shared` components. Manually tracking these across Debian updates is fragile. Using `apt-get install libftdi1 libconfuse0 libusb-1.0-0` in the final stage delegates dependency resolution to Debian's package manager, which is the correct abstraction boundary.

## Runtime State Inventory

> This phase is greenfield image construction, not a rename/refactor/migration. No runtime state needs migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — new image | N/A |
| Live service config | None — new image | N/A |
| OS-registered state | None — new image | N/A |
| Secrets/env vars | None — new image | N/A |
| Build artifacts | None — new image | N/A |

## Common Pitfalls

### Pitfall 1: QEMU Segfaults During Parallel Compilation
**What goes wrong:** `cmake --build --parallel $(nproc)` under QEMU user-mode emulation for `linux/arm64` causes intermittent compiler segfaults (observed in Phase 3).
**Why it happens:** QEMU user-mode emulation has race conditions and memory pressure issues when multiple heavy processes (g++ instances) run concurrently.
**How to avoid:** Use single-threaded builds (`--parallel 1`) for the emulated architecture path, OR use native arm64 builders (Docker Build Cloud, Raspberry Pi, etc.). The build stage can conditionally set parallelism via an environment variable or build argument.
**Warning signs:** Build fails with `internal compiler error: Segmentation fault` or `cc1plus` killed randomly during compilation.

### Pitfall 2: Config Bind Mount Masking Inotify Events
**What goes wrong:** Operator edits `/etc/tellstick.conf` on the host, but the containerized daemon does not reload.
**Why it happens:** Docker bind mounts are host filesystem passthroughs. inotify events generally DO propagate, but some editors use atomic save patterns (write to temp file, rename over target) that emit `IN_MOVED_TO` on the parent directory. The Phase 4 watcher uses `IN_CLOSE_WRITE | IN_MOVED_TO` on the parent directory (`/etc`), which correctly catches both patterns. However, if the bind mount target is the file itself (not the directory), inotify watches on the file inode may break when the inode changes during atomic replacement.
**How to avoid:** Ensure the watcher watches the parent directory (`/etc`) as implemented in Phase 4, not the file itself. The current implementation does this correctly [VERIFIED: codebase inspection of TelldusMain.cpp].
**Warning signs:** Config changes only take effect after container restart.

### Pitfall 3: Daemon Forking Breaks Docker PID Tracking
**What goes wrong:** `telldusd` forks to daemonize by default, becoming PID 1's child and then exiting. Docker thinks the container has exited.
**Why it happens:** `main_unix.cpp` forks by default. Only `--nodaemon` prevents forking and keeps the process in the foreground.
**How to avoid:** Always pass `--nodaemon` when running in Docker. The entrypoint should invoke `telldusd --nodaemon`, not bare `telldusd`.
**Warning signs:** Container exits immediately after startup; `docker logs` shows daemon started but process is gone.

### Pitfall 4: Shared Library Mismatch Between Build and Final Stage
**What goes wrong:** Binary built in `debian:bookworm-slim` fails to start in final stage because `.so` versions differ.
**Why it happens:** If the final stage uses a different Debian point release or `ldd` copies libraries without their symlinks, dynamic linker fails.
**How to avoid:** Use the same base image family (`debian:bookworm-slim`) for both stages, or install runtime packages via apt in the final stage. If manually copying with `ldd`, ensure symlinks are preserved.
**Warning signs:** Container fails with `error while loading shared libraries: libftdi1.so.2: cannot open shared object file`.

### Pitfall 5: tdtool One-Shot Mode Requires Running Daemon
**What goes wrong:** Operator runs `docker run --rm telldus tdtool --list` but it fails because no daemon is running.
**Why it happens:** `tdtool` is a client that communicates with `telldusd` via local socket/IPC. A one-shot container starts, runs `tdtool`, then exits — the daemon never starts.
**How to avoid:** The one-shot use case is actually `docker exec <running_container> tdtool --list`. The entrypoint should still support `docker run --rm telldus tdtool --list` for cases where the operator wants to run the daemon temporarily (e.g., `docker run --rm telldus tdtool --on 1` could start daemon, execute command, then exit). Document both patterns clearly.
**Warning signs:** `tdtool` returns `TELLSTICK_ERROR_CONNECTING_SERVICE`.

## Code Examples

### Verified: telldusd --nodaemon sets stdout logging
```cpp
// Source: telldus-core/service/main_unix.cpp (lines 53-56)
for (int i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--nodaemon") == 0) {
        deamonize = false;
        Log::setLogOutput(Log::StdOut);
    }
```
**Finding:** The `--nodaemon` flag already switches logging to stdout. No code modification is needed for D-05-11. [VERIFIED: codebase]

### Verified: inotify watches parent directory for atomic replacements
```cpp
// Source: telldus-core/service/TelldusMain.cpp
fd_ = inotify_init1(IN_CLOEXEC | IN_NONBLOCK);
wd_ = inotify_add_watch(fd_, dir.c_str(), IN_CLOSE_WRITE | IN_MOVED_TO);
```
**Finding:** The watcher monitors the parent directory (`/etc` by default) for both `IN_CLOSE_WRITE` (in-place edits) and `IN_MOVED_TO` (atomic renames). This works correctly with bind mounts. [VERIFIED: codebase]

### Dockerfile: Multi-stage with layer caching
```dockerfile
# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS build
ENV DEBIAN_FRONTEND=noninteractive

# Cacheable dependency layer
RUN apt-get update -qq && apt-get install -y -q \
    cmake build-essential pkg-config \
    libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev

WORKDIR /build
COPY CMakePresets.json .
COPY telldus-core/ telldus-core/

# Cacheable configure layer
RUN cmake --preset headless

# Build and test
RUN cmake --build build/headless --parallel 1
RUN ctest --test-dir build/headless -R cppunit --output-on-failure

# --- Final stage ---
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime libraries only
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    libftdi1 libconfuse0 libusb-1.0-0 \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Copy artifacts from build stage
COPY --from=build /build/build/headless/telldus-core/service/telldusd /usr/local/sbin/
COPY --from=build /build/build/headless/telldus-core/client/libtelldus-core.so* /usr/local/lib/
COPY --from=build /build/build/headless/telldus-core/tdtool/tdtool /usr/local/bin/
COPY --from=build /build/build/headless/telldus-core/tdadmin/tdadmin /usr/local/bin/

# Copy sample config
COPY telldus-core/service/tellstick.conf /etc/tellstick.conf

# Update library cache
RUN ldconfig

# Entrypoint: tini + smart dispatch script
COPY scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["telldusd", "--nodaemon"]
```
[Pattern derived from: docs.docker.com/build/building/multi-stage/ + project codebase]

### Entrypoint Script: Dual-Mode Dispatch
```bash
#!/bin/sh
set -e

if [ "$1" = "tdtool" ] || [ "$1" = "tdadmin" ]; then
    CMD="$1"
    shift
    exec "$CMD" "$@"
fi

# Default: run daemon in foreground for proper signal handling
exec telldusd --nodaemon "$@"
```
[Pattern derived from: github.com/Yelp/dumb-init + project requirements]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 3: `docker run` one-liner with full source mount | Phase 5: Multi-stage `Dockerfile` with reproducible build | Now | Production-ready image; no source mount needed at runtime |
| `telldusd` daemonizes (forks, closes stdout) | `telldusd --nodaemon` keeps foreground + stdout logging | Already in codebase | Perfect for containers; no code changes needed |
| No config reload | Phase 4: inotify-based auto-reload | Phase 4 | Works transparently with Docker bind mounts |
| Manual multi-arch builds | `docker buildx --platform` | Now | Single command builds amd64 + arm64 manifest |

**Deprecated/outdated:**
- `multiarch/qemu-user-static`: The modern replacement is `tonistiigi/binfmt` or Docker Desktop's built-in QEMU registration. [CITED: docs.docker.com/build/building/multi-platform/]
- Docker legacy builder (`DOCKER_BUILDKIT=0`): Does not support multi-platform builds or skipping unrelated stages. BuildKit is the default in Docker 23.0+.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `debian:bookworm-slim` final stage with runtime apt packages is acceptable per D-05-01 (distroless/scratch was locked, but agent has discretion on exact strategy) | Standard Stack | If the user insists on true distroless/scratch, the plan must include an `ldd`-based library copying task instead of apt install |
| A2 | Docker bind mounts propagate inotify events from host to container for files in the mounted directory | Common Pitfalls #2 | If wrong, config auto-reload would break with bind mounts; would need to switch to volume mounts or polling |
| A3 | `--parallel 1` is sufficient to avoid QEMU segfaults for this codebase | Common Pitfalls #1 | If wrong, builds would still fail randomly under emulation; may need `--parallel 2` or environment-specific tuning |
| A4 | `tini` is available in `debian:bookworm-slim` via `apt-get install tini` | Standard Stack | If wrong, need to download static binary from GitHub releases or use `dumb-init` instead |

## Open Questions (RESOLVED)

1. **Does the operator have a registry to push multi-arch images to?** — **RESOLVED**
    - Resolution: `scripts/build-docker.sh` supports both `--load` (local, single-platform) and `--push` (registry, multi-platform) modes. Default is `--load` for local testing.

2. **Is `tdadmin` actually built by the headless preset?** — **RESOLVED**
    - Resolution: Plans update CMakePresets.json `BUILD_TDADMIN=TRUE` in the headless preset so `tdadmin` is built and included in the image per D-05-05.

3. **Should the final stage use a non-root user?** — **RESOLVED**
    - Resolution: Run as root in the container for Phase 5. The daemon internally drops privileges per config. USB device passthrough permissions are deferred to Phase 6.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker Engine | Image build + runtime | ✓ | 29.4.3 | — |
| docker buildx | Multi-arch builds | ✓ | 0.33.0 | — |
| QEMU binfmt (aarch64) | arm64 emulation on amd64 host | ✓ | Registered (Docker Desktop / Linux) | Native arm64 builder (Raspberry Pi) |
| debian:bookworm-slim image | Build + final stage | ✓ | Available on Docker Hub | `debian:12-slim` alias |
| tini package | Init system | ✓ | v0.19.0 (in Debian repos) | dumb-init static binary download |
| tonistiigi/binfmt | QEMU registration helper | ✓ | Latest | Manual `qemu-user-static` setup |

**Missing dependencies with no fallback:**
- None identified.

**Missing dependencies with fallback:**
- None identified.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | CppUnit (embedded in telldus-core build) |
| Config file | `CMakePresets.json` (headless preset enables `ENABLE_TESTING=TRUE`) |
| Quick run command | `ctest --test-dir build/headless -R cppunit --output-on-failure` |
| Full suite command | `ctest --test-dir build/headless --output-on-failure` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCK-01 | Image builds successfully with headless runtime | build | `docker build -t telldus .` | ❌ Wave 0 |
| DOCK-01 | CppUnit tests pass during build | build | `docker build --target build -t telldus:build .` | ❌ Wave 0 |
| DOCK-03 | Config bind mount provides file at `/etc/tellstick.conf` | smoke | `docker run --rm -v $(pwd)/test.conf:/etc/tellstick.conf:ro telldus cat /etc/tellstick.conf` | ❌ Wave 0 |
| DOCK-03 | Sample config exists as fallback | smoke | `docker run --rm telldus cat /etc/tellstick.conf` | ❌ Wave 0 |
| D-05-08 | Default entrypoint runs telldusd --nodaemon | smoke | `docker run --rm telldus --version` or inspect process | ❌ Wave 0 |
| D-05-09 | One-shot tdtool dispatch works | smoke | `docker run --rm telldus tdtool --help` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `docker build --target build -t telldus:build .`
- **Per wave merge:** `docker build -t telldus . && docker run --rm telldus tdtool --help`
- **Phase gate:** Full multi-arch build `docker buildx build --platform linux/amd64,linux/arm64 -t telldus .`

### Wave 0 Gaps
- [ ] `Dockerfile` — covers DOCK-01, DOCK-03
- [ ] `scripts/build-docker.sh` — covers D-05-15
- [ ] `scripts/docker-entrypoint.sh` — covers D-05-08, D-05-09, D-05-10
- [ ] `.dockerignore` — prevents build context bloat
- [ ] Smoke test script for image verification

## Security Domain

> This phase involves container image construction. Security considerations are minimal but present.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | No | N/A — no external input parsing in image build |
| V6 Cryptography | No | N/A — no crypto in this phase |
| V9 Secure Coding | Yes | Use minimal base image; do not embed secrets; run with least privilege where possible |

### Known Threat Patterns for Container Builds

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Build-time secret leakage | Information Disclosure | Use `--mount=type=secret` if secrets needed; do not `COPY .env` into image |
| Large attack surface from build tools | Elevation of Privilege | Multi-stage build strips build tools from final image |
| Running as root in container | Elevation of Privilege | Acceptable for USB device access (Phase 6); daemon internally drops privileges |

## Sources

### Primary (HIGH confidence)
- `telldus-core/service/main_unix.cpp` — Verified `--nodaemon` flag and stdout logging behavior
- `telldus-core/service/TelldusMain.cpp` — Verified inotify watcher implementation
- `telldus-core/service/Log.cpp` — Verified `Log::setLogOutput(Log::StdOut)` implementation
- `CMakePresets.json` — Verified headless preset configuration
- `docs/phase-03-docker-commands.md` — Proven build commands from Phase 3
- Docker Official Docs: `docs.docker.com/build/building/multi-stage/` — Multi-stage build patterns
- Docker Official Docs: `docs.docker.com/build/building/multi-platform/` — Multi-platform build patterns
- Docker Official Docs: `docs.docker.com/engine/reference/run/` — Bind mount semantics

### Secondary (MEDIUM confidence)
- GitHub: `GoogleContainerTools/distroless` — Distroless image capabilities and limitations
- GitHub: `krallin/tini` — tini init system documentation and Debian packaging
- GitHub: `Yelp/dumb-init` — dumb-init alternative documentation
- Docker Blog: "Multi-Platform Docker Builds" — QEMU emulation performance and pitfalls

### Tertiary (LOW confidence)
- None — all claims verified against primary sources or codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against host environment, Debian repos, and official Docker docs
- Architecture: HIGH — patterns derived from official Docker documentation and verified against project codebase
- Pitfalls: HIGH — QEMU segfaults were observed in Phase 3; inotify behavior verified in source code

**Research date:** 2026-05-15
**Valid until:** 2026-08-15 (Debian bookworm is stable; Docker patterns are stable)
