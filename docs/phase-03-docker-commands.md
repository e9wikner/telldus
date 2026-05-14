# Phase 3 Docker Multi-Arch Build Commands

Verified Docker commands for building, testing, and smoke-testing Telldus Core headless components on `linux/arm64` (Raspberry Pi `aarch64`) using QEMU user-mode emulation.

## Prerequisites

- Docker Engine installed and running
- Docker Buildx available: `docker buildx inspect default`
- QEMU binfmt configured for `aarch64`:
  ```bash
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  ```

## Docker Run: Full Build-Test-Smoke Pipeline

The following single command compiles Telldus Core for `aarch64`, runs CppUnit tests, and validates `tdtool` inside a `debian:bookworm-slim` container:

```bash
docker run --rm --platform linux/arm64 \
  -v $(pwd):/src:ro \
  -e DEBIAN_FRONTEND=noninteractive \
  debian:bookworm-slim \
  bash -c '
    set -e
    apt-get update -qq
    apt-get install -y -q \
      cmake build-essential pkg-config \
      libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
    cp -r /src /work
    cd /work/telldus-core
    cmake -B build/headless \
      -DFORCE_COMPILE_FROM_TRUNK=TRUE \
      -DBUILD_TDTOOL=TRUE \
      -DBUILD_TDADMIN=FALSE \
      -DENABLE_TESTING=TRUE \
      -DFTDI_ENGINE=libftdi
    cmake --build build/headless --parallel $(nproc)
    ctest --test-dir build/headless -R cppunit --output-on-failure
    ./build/headless/tdtool/tdtool --help
  '
```

### Command Breakdown

| Step | Purpose |
|------|---------|
| `--rm` | Remove container after exit |
| `--platform linux/arm64` | Target Raspberry Pi `aarch64` architecture |
| `-v $(pwd):/src:ro` | Mount repository read-only (avoid cache mismatch) |
| `cp -r /src /work` | Copy source to writable directory inside container |
| `cmake -B build/headless ...` | Configure using the existing `headless` preset variables |
| `cmake --build ... --parallel $(nproc)` | Compile using all available QEMU-emulated cores |
| `ctest ... -R cppunit` | Run CppUnit tests |
| `./tdtool --help` | Smoke-test the CLI binary |

### CMake Preset Reuse

The `headless` preset in `CMakePresets.json` is architecture-agnostic and is reused unchanged for Debian/`aarch64` builds. The cache variables above mirror the preset exactly:

- `FORCE_COMPILE_FROM_TRUNK=TRUE`
- `BUILD_TDTOOL=TRUE`
- `BUILD_TDADMIN=FALSE`
- `ENABLE_TESTING=TRUE`
- `FTDI_ENGINE=libftdi`

## Performance Notes

QEMU user-mode emulation for `aarch64` is **5–10× slower** than native `amd64` builds. Plan for longer compilation times and set appropriate timeouts when running in CI:

- A native `amd64` build may take ~2 minutes.
- The equivalent `linux/arm64` emulated build may take 10–20 minutes.
- Use `--parallel $(nproc)` to maximize throughput within the emulator.

## What Is NOT Included Here

A production `Dockerfile` is **out of scope for this phase**. Phase 5 (Docker Image and Config Mount) will create the minimal runtime image with bind-mount support for `/etc/tellstick.conf`.
