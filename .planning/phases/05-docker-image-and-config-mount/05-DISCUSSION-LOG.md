# Phase 05: Docker Image and Config Mount - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 05-Docker Image and Config Mount
**Areas discussed:** Dockerfile build strategy, Image contents boundary, Container entrypoint, Multi-architecture build scope

---

## Dockerfile Build Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-stage | Build inside the Dockerfile using proven debian:bookworm-slim base, then copy only runtime artifacts to a clean final stage | ✓ |
| Native build + COPY | Build on Arch host, then COPY compiled binaries into a slim runtime image | |
| You decide | Let the planner/researcher pick the most practical approach | |

**User's choice:** Multi-stage
**Notes:** Phase 3 already proved the full build works inside debian:bookworm-slim. Multi-stage keeps build tools out of the runtime image.

---

### Layer Caching

| Option | Description | Selected |
|--------|-------------|----------|
| Deps-first, source-last | Install Debian packages and run CMake configure in early layers (cacheable), then COPY source code and build in later layers | ✓ |
| Single COPY-then-build | Copy the full repo once and build everything in one RUN layer | |
| You decide | Let the planner structure layers for optimal caching | |

**User's choice:** Deps-first, source-last
**Notes:** User specifically requested efficient layer caching during Phase 4 discussion.

---

### Final Stage Base Image

| Option | Description | Selected |
|--------|-------------|----------|
| debian:bookworm-slim | Same base, just without build tools. Easiest library compatibility. | |
| Distroless or scratch | Smaller attack surface, but requires shared library copying or static linking | ✓ |
| You decide | Let the planner pick based on shared library dependencies | |

**User's choice:** Distroless or scratch
**Notes:** User wants minimal attack surface. Planner must handle libftdi1, libconfuse, and dependency copying.

---

### Tests in Docker Build

| Option | Description | Selected |
|--------|-------------|----------|
| Run tests in build stage | ctest -R cppunit runs during build. Guarantees verified binaries. | ✓ |
| Skip tests in Dockerfile | Faster image builds. Tests run separately on native builds. | |
| You decide | Let the planner decide based on build time vs validation needs | |

**User's choice:** Run tests in build stage
**Notes:** Build fails if tests fail, ensuring only verified binaries reach the final image.

---

## Image Contents Boundary

### Include tdtool

| Option | Description | Selected |
|--------|-------------|----------|
| Include tdtool | Image self-sufficient for smoke tests and Phase 6 verification | ✓ |
| Runtime-only | Only telldusd + libtelldus-core.so. tdtool runs from host or separate container | |
| You decide | Let the planner weigh image size vs Phase 6 convenience | |

**User's choice:** Include tdtool
**Notes:** Makes the image immediately usable for verification without needing a separate client container.

---

### Include tdadmin

| Option | Description | Selected |
|--------|-------------|----------|
| Include tdadmin | Admin tool available inside container for permission setup | ✓ |
| Skip tdadmin | Matches the headless preset. USB permissions are host-managed. | |
| You decide | Let the planner decide based on whether tdadmin adds value inside a container | |

**User's choice:** Include tdadmin
**Notes:** Admin tool available for runtime permissions if needed.

---

### Sample tellstick.conf

| Option | Description | Selected |
|--------|-------------|----------|
| Include sample config | Reference config in image as documentation and fallback. Bind mount overwrites it. | ✓ |
| No default config | Image starts empty-config if unmounted. Forces explicit configuration. | |
| You decide | Let the planner decide based on operator experience and image size | |

**User's choice:** Include sample config
**Notes:** Provides a reference config and graceful fallback if operator forgets bind mount.

---

### Test Binaries in Image

| Option | Description | Selected |
|--------|-------------|----------|
| Include test binaries | TestRunner in final image for runtime diagnostics | |
| Strip test binaries | Production binaries only. Tests verified at build time. | ✓ |
| You decide | Let the planner decide based on image size vs diagnostic value | |

**User's choice:** Strip test binaries
**Notes:** Tests already run during build stage. Final image contains only production binaries.

---

## Container Entrypoint

### Startup Wrapper vs Direct Binary

| Option | Description | Selected |
|--------|-------------|----------|
| Direct binary | telldusd runs as PID 1. Simplest, most Docker-native. | ✓ |
| Lightweight wrapper | Shell script verifies config, state dir, permissions, then execs telldusd | |
| You decide | Let the planner choose based on daemon self-sufficiency | |

**User's choice:** Direct binary
**Notes:** Daemon auto-creates state dir per Phase 4 decisions. Cleanest approach.

---

### One-shot tdtool Support

| Option | Description | Selected |
|--------|-------------|----------|
| Support one-shot tdtool | Smart entrypoint detects tdtool vs daemon mode | ✓ |
| Daemon-only entrypoint | ENTRYPOINT is telldusd. tdtool used via docker exec. | |
| You decide | Let the planner decide based on complexity vs operator convenience | |

**User's choice:** Support one-shot tdtool
**Notes:** `docker run --rm telldus tdtool --list` should work. Smart dispatch needed.

---

### Init System

| Option | Description | Selected |
|--------|-------------|----------|
| Use tini/dumb-init | Best practice for Docker. Proper SIGTERM forwarding and zombie reaping. | ✓ |
| No init system | Daemon handles signals directly. Simpler image. | |
| You decide | Let the planner decide based on whether telldusd handles SIGTERM correctly | |

**User's choice:** Use tini/dumb-init
**Notes:** Adds ~20KB. Proper signal handling is best practice for Docker containers.

---

### Logging

| Option | Description | Selected |
|--------|-------------|----------|
| Log to stdout/stderr | Docker-native logging. docker logs shows output. | ✓ |
| Log to file inside container | Traditional daemon behavior. Logs lost when container removed. | |
| You decide | Let the planner decide based on daemon's current logging mechanism | |

**User's choice:** Log to stdout/stderr
**Notes:** Planner must adjust or verify daemon logging to write to stdout.

---

## Multi-Architecture Build Scope

### Multi-Architecture Support

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-arch (amd64 + arm64) | One Dockerfile builds both. Matches deployment target and dev host. | ✓ |
| Host architecture only | Build for whatever architecture the host is. Simpler. | |
| You decide | Let the planner decide based on build complexity | |

**User's choice:** Multi-arch (amd64 + arm64)
**Notes:** Phase 3 already proved build on linux/arm64 via docker buildx with QEMU.

---

### Architecture-Specific Dockerfile Code

| Option | Description | Selected |
|--------|-------------|----------|
| Architecture-agnostic | No ARG TARGETARCH or platform-specific RUN commands. | ✓ |
| Minimal platform hints | Add TARGETARCH arg and optional parallelism hints for QEMU arm64. | |
| You decide | Let the planner decide based on whether platform-specific tweaks are needed | |

**User's choice:** Architecture-agnostic
**Notes:** Proven in Phase 3 that the build works cross-platform without changes.

---

### Image Tagging

| Option | Description | Selected |
|--------|-------------|----------|
| Single tag (:latest) | Multi-arch manifest. docker pull resolves correct arch automatically. | ✓ |
| Arch-specific tags | Explicit per-arch tags. More tags to manage. | |
| You decide | Let the planner decide based on deployment and CI needs | |

**User's choice:** Single tag (:latest)
**Notes:** Simplest operator experience. Docker handles architecture resolution.

---

### Build Helper Script

| Option | Description | Selected |
|--------|-------------|----------|
| Helper script | scripts/build-docker.sh wraps buildx with platforms and tags. | ✓ |
| Raw commands in docs | Document exact docker buildx commands. No script maintenance. | |
| You decide | Let the planner decide based on build complexity and documentation strategy | |

**User's choice:** Helper script
**Notes:** Encapsulates buildx setup, platform flags, and tagging for operators and CI.

---

## Agent's Discretion

Areas where the user deferred to the agent's judgment:
- Choice between `tini` and `dumb-init`
- Smart entrypoint implementation (shell script vs small binary)
- Exact shared library copying strategy for distroless/scratch final stage
- How to redirect telldusd logging to stdout/stderr
- CMake build parallelism (respecting QEMU arm64 reliability)

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 05-Docker Image and Config Mount*
*Discussion completed: 2026-05-15*
