# Phase 04: Config Compatibility - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 04-config-compatibility
**Areas discussed:** Runtime state directory, Config path flexibility, Write behavior on stable config, Cross-platform work / Dockerfile

---

## Runtime State Directory

| Option | Description | Selected |
|--------|-------------|----------|
| /var/lib/telldus | Standard Linux convention. Auto-create on startup. | ✓ |
| XDG path | Respects user data conventions. Less common for system daemons. | |
| You decide | Let Claude choose. | |

**User's choice:** `/var/lib/telldus`
**Notes:** Auto-create if missing. Run as root / 644 for v1 simplicity.

---

## State Directory Missing

| Option | Description | Selected |
|--------|-------------|----------|
| Create it automatically | Most robust for Docker and native. | ✓ |
| Fail to start with error | Strictest behavior. Forces explicit setup. | |
| Skip state persistence | Risky — device states reset to defaults. | |

**User's choice:** Create it automatically
**Notes:** None.

---

## State Directory Permissions

| Option | Description | Selected |
|--------|-------------|----------|
| Root, 644 | Simplest. Matches original behavior. | |
| Dedicated telldus user, 660 | Security best practice. More setup. | |
| You decide | Let Claude choose. | ✓ |

**User's choice:** You decide
**Claude's discretion:** Root / 644 for v1 simplicity. Dedicated user deferred to v2.

---

## State Path Configurability

| Option | Description | Selected |
|--------|-------------|----------|
| Compile-time only | Current approach. Keeps things simple. | |
| Environment variable override | Useful for testing and custom Docker layouts. | |
| Both | Compile-time default with env override. | ✓ |

**User's choice:** Both — compile-time default with TELLDUS_STATE_DIR env override
**Notes:** None.

---

## Config Path Flexibility

| Option | Description | Selected |
|--------|-------------|----------|
| Compile-time only | Matches current behavior and Docker convention. | |
| Environment variable override | Useful for testing with sample configs. | |
| Both | Default /etc/tellstick.conf with env override. | ✓ |

**User's choice:** Both — default `/etc/tellstick.conf` with TELLDUS_CONFIG_FILE env override
**Notes:** None.

---

## Missing Config Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Fail to start | Strictest. No config means no devices. | |
| Start with zero devices | More forgiving. Daemon runs but can't control anything. | ✓ |
| You decide | Let Claude choose. | |

**User's choice:** Start with zero devices and log a warning
**Notes:** None.

---

## Config Auto-Reload

| Option | Description | Selected |
|--------|-------------|----------|
| Require restart | Simplest. Matches original behavior. | |
| Auto-reload on change | Modern behavior. Useful for live edits. | ✓ |
| You decide | Let Claude choose. | |

**User's choice:** Auto-reload on file change (e.g., inotify)
**Notes:** None.

---

## Var Config Auto-Reload

| Option | Description | Selected |
|--------|-------------|----------|
| No reload | Var config is internal state owned by daemon. | ✓ |
| Auto-reload too | Treat both config files the same. | |
| You decide | Let Claude choose. | |

**User's choice:** Var config is internal — no reload
**Notes:** None.

---

## Write Behavior on Stable Config

| Option | Description | Selected |
|--------|-------------|----------|
| Read-only for v1 | Config is user-provided, may be bind-mounted read-only. | |
| Allow writes as today | Preserves original behavior. | ✓ |
| You decide | Let Claude choose. | |

**User's choice:** Allow writes as today
**Notes:** Bind-mounted configs in Docker must be writeable.

---

## Write Failure Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Log warning and continue | Daemon stays alive. Config change lost. | |
| Fail operation and return error | Strictest. Caller gets an error. | ✓ |
| You decide | Let Claude choose. | |

**User's choice:** Fail operation and return error to client
**Notes:** None.

---

## Var Config Write Failure

| Option | Description | Selected |
|--------|-------------|----------|
| Same strict behavior | Consistent with stable config. | ✓ |
| Best-effort warning | More forgiving. State is best-effort. | |
| You decide | Let Claude choose. | |

**User's choice:** Same strict behavior — fail and return error
**Notes:** None.

---

## Backup Before Writes

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — .bak | Protects against corruption. | |
| No — direct write | Preserves original behavior. | ✓ |
| You decide | Let Claude choose. | |

**User's choice:** No — write directly as today
**Notes:** None.

---

## Cross-Platform Work / Dockerfile

**User's request:** The user asked about cross-platform work and expressed a need for a Dockerfile to avoid rebuilding the Docker image for every task.

**Outcome:**
- Cross-platform: Phase 4 is Linux-only v1. Existing `#ifdef _LINUX` guards handle platform differences. No cross-platform config work needed.
- Dockerfile: Deferred to Phase 5 (Docker Image and Config Mount). The user acknowledged this is a Phase 5 concern.

---

## Claude's Discretion

- **State directory permissions:** Root / 644 for v1, dedicated user for v2.
- **inotify implementation:** Agent may choose exact mechanism (inotify, fanotify, stat polling).
- **Env var override implementation:** Agent may choose `getenv()` in `SettingsConfuse.cpp` or a thin wrapper.

## Deferred Ideas

- **Dockerfile with efficient layer caching** — Phase 5: Docker Image and Config Mount
- **Dedicated `telldus` system user** — v2 packaging/systemd hardening
- **Script path configurability (`SCRIPT_PATH`)** — out of scope for v1
- **Windows/macOS/FreeBSD config path modernization** — out of scope for v1
