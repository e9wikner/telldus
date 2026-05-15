# Phase 06: Containerized Daemon Runtime - Validation

**Phase:** 06  
**Phase Slug:** containerized-daemon-runtime  
**Created:** 2026-05-15

## Validation Strategy

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell-based integration tests |
| Config file | `scripts/test-container-runtime.sh` |
| Quick run command | `docker exec telldus tdtool --list` |
| Full suite command | `scripts/test-container-runtime.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| DOCK-02 | TellStick Duo accessible in container | Manual/Integration | `docker exec telldus lsusb \| grep -i ftdi` |
| DOCK-04 | tdtool works via docker exec | Integration | `docker exec telldus tdtool --list` |
| DOCK-05 | Restart preserves config/state | Integration | Stop/start container, verify `tdtool --list` |
| DUO-02 | Daemon starts with TellStick connected | Manual | `docker logs telldus` shows success |
| DUO-07 | Restart doesn't lose device compatibility | Integration | Restart test + device control test |

### Sampling Rate

- **Per task commit:** Manual verification with `docker exec telldus tdtool --list`
- **Per wave merge:** Full integration test script (if hardware available)
- **Phase gate:** Container runs, tdtool responds, logs show daemon ready

## Verification Dimensions

### 1. USB Passthrough (DOCK-02)

**What to verify:**
- Container can access TellStick Duo USB device
- `--privileged` flag grants sufficient USB permissions
- libftdi1 can open the device

**Test steps:**
```bash
# 1. Start container
docker run -d --name telldus --privileged \
  -v /path/to/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest

# 2. Verify USB access
docker exec telldus lsusb | grep -i ftdi
# Expected: Shows FTDI device

# 3. Check daemon logs
docker logs telldus | grep -i "tellstick\|controller"
# Expected: Shows device detection messages
```

### 2. Daemon Startup (DUO-02)

**What to verify:**
- telldusd starts successfully as container main process
- Process hierarchy is correct: tini → entrypoint → telldusd
- Signal handling works (SIGTERM triggers graceful shutdown)

**Test steps:**
```bash
# 1. Check process hierarchy
docker exec telldus ps aux
# Expected: tini as PID 1, telldusd as child

# 2. Check daemon status
docker exec telldus tdtool --list
# Expected: Shows device list (or empty if no config)

# 3. Test graceful shutdown
time docker stop telldus
# Expected: Completes in < 2 seconds
```

### 3. tdtool Communication (DOCK-04)

**What to verify:**
- tdtool can communicate with containerized daemon via docker exec
- Device listing works
- Help/usage works

**Test steps:**
```bash
# 1. Basic connectivity
docker exec telldus tdtool --help
# Expected: Shows usage information

# 2. Device listing
docker exec telldus tdtool --list
# Expected: Lists configured devices (if any)

# 3. Device commands (with hardware)
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off 1
# Expected: Commands sent (if device configured)
```

### 4. Restart Behavior (DOCK-05, DUO-07)

**What to verify:**
- Container restart preserves configuration
- State persists across restarts
- Config auto-reload works without restart
- USB disconnect/reconnect is handled gracefully

**Test steps:**
```bash
# 1. Initial state
docker exec telldus tdtool --list > /tmp/before-restart.txt

# 2. Restart container
docker restart telldus
sleep 5

# 3. Verify state preserved
docker exec telldus tdtool --list > /tmp/after-restart.txt
diff /tmp/before-restart.txt /tmp/after-restart.txt
# Expected: No differences

# 4. Verify auto-restart policy
docker ps | grep telldus
# Expected: Container running
```

## Success Criteria

All of the following must be true:

1. ✓ `docker exec telldus lsusb` shows FTDI device (USB passthrough works)
2. ✓ `docker logs telldus` shows daemon startup without errors
3. ✓ `docker exec telldus tdtool --list` returns device list
4. ✓ `docker stop telldus` completes in < 2 seconds (graceful shutdown)
5. ✓ After `docker restart telldus`, state and config are preserved
6. ✓ Config edits on host are auto-reloaded (Phase 4 feature)

## Known Limitations

- Hardware testing requires physical TellStick Duo connected
- `--privileged` mode is v1 pragmatic choice; v2 may use `--device` + udev rules
- Manual verification required for plan 06-04 checkpoint task

## References

- `06-RESEARCH.md` — Technical research and architecture patterns
- `06-CONTEXT.md` — Locked decisions and constraints
- `docs/docker-runtime.md` — Operator documentation (created by plans)
- `scripts/test-container-runtime.sh` — Automated tests (created by plans)
