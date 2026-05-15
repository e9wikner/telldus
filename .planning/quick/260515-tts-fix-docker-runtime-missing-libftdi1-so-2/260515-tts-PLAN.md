---
status: in_progress
quick_id: 260515-tts
created: 2026-05-15
---

# Quick Task 260515-tts: Fix Docker runtime missing libftdi1.so.2 and lsusb

## Goal

Make the Docker image start `telldusd` successfully when the daemon is linked
against `libftdi1.so.2`, and keep the QUICKSTART USB verification command valid.

## Tasks

1. Update the final Docker image runtime package list so it installs the package
   that provides `libftdi1.so.2`.
2. Add the package that provides `lsusb`, because QUICKSTART tells users to run
   `docker exec telldus lsusb`.
3. Fix entrypoint command dispatch so the default Docker `CMD` does not pass
   a duplicate `telldusd` argument to the daemon.
4. Rebuild or inspect the image enough to verify `ldd /usr/local/sbin/telldusd`
   resolves `libftdi1.so.2`.
