---
status: complete
quick_id: 260515-tts
completed: 2026-05-15
---

# Quick Task 260515-tts Summary

## Changes

- Replaced the final Docker image runtime package `libftdi1` with `libftdi1-2`,
  which provides the `libftdi1.so.2` library required by `telldusd`.
- Added `usbutils` to the final image so `docker exec telldus lsusb` works as
  documented in QUICKSTART.
- Fixed Docker entrypoint dispatch so the default `CMD ["telldusd", "--nodaemon"]`
  executes without passing a duplicate `telldusd` argument to the daemon.

## Verification

- `docker buildx build --platform linux/amd64 --tag telldus:latest --load .`
  completed successfully.
- Docker build ran `ctest --test-dir build/headless -R cppunit --output-on-failure`;
  1/1 tests passed.
- Runtime image check confirmed `libftdi1.so.2` resolves to
  `/lib/x86_64-linux-gnu/libftdi1.so.2`.
- Runtime image check confirmed `/usr/bin/lsusb` exists.
- Live container started and stayed up.
- `docker exec telldus lsusb` listed `ID 1781:0c31 Telldus TellStick Duo`.
- `docker exec telldus tdtool --list` returned 13 configured devices and one
  Oregon sensor.

## Notes

The daemon logs still report missing `/var/lib/telldus/telldus-core.conf` on a
fresh state volume. The daemon continues running and device listing works, so
this appears to be non-fatal initialization noise rather than the startup
failure addressed here.
