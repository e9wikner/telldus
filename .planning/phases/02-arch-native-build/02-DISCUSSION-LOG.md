# Phase 2: Arch Native Build - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14T20:08:00+02:00
**Phase:** 02-arch-native-build
**Areas discussed:** Build Dependency Management, Compiler Modernization Level, Test Enablement Strategy, Build Output Location

---

## Build Dependency Management

| Option | Description | Selected |
|--------|-------------|----------|
| A | Provide exact `pacman -S` commands in README | |
| B | List package names only, assume Arch users know | |
| C | Create `scripts/install-arch-deps.sh` shell script | ✓ |

**User's choice:** C
**Notes:** Automation-friendly, reduces copy-paste errors

| Option | Description | Selected |
|--------|-------------|----------|
| A | Only official Arch packages | |
| B | Official repos + check for AUR packages | |
| C | Official repos + warn if missing/AUR | ✓ |

**User's choice:** C
**Notes:** Balanced approach - official packages are guaranteed, AUR is user-managed

| Option | Description | Selected |
|--------|-------------|----------|
| A | Check each package with `pacman -Q` | |
| B | Just run `pacman -S`, let pacman handle it | ✓ |
| C | Check with `pkg-config` | |

**User's choice:** B
**Notes:** Simpler script, pacman's idempotency handles already-installed packages

| Option | Description | Selected |
|--------|-------------|----------|
| A | Standalone executable | ✓ |
| B | Source-able functions | |
| C | Both with `--source` flag | |

**User's choice:** A
**Notes:** Most intuitive, standard pattern

---

## Compiler Modernization Level

| Option | Description | Selected |
|--------|-------------|----------|
| A | Fix only build-blocking errors | |
| B | Fix errors + critical warnings | ✓ |
| C | Fix all warnings with `-Wall -Wextra -Werror` | |

**User's choice:** B
**Notes:** Balanced safety vs effort

| Option | Description | Selected |
|--------|-------------|----------|
| A | Security-related only | |
| B | Security + deprecation warnings | |
| C | Security + deprecation + implicit conversions | ✓ |

**User's choice:** C
**Notes:** Comprehensive safety net covering security, future compatibility, and data integrity

| Option | Description | Selected |
|--------|-------------|----------|
| A | Fix them anyway | ✓ |
| B | Document as known issues | |
| C | Suppress with compiler flags | |

**User's choice:** A
**Notes:** Don't leave technical debt

| Option | Description | Selected |
|--------|-------------|----------|
| A | Add to CMakeLists.txt | ✓ |
| B | Document in README only | |
| C | Add conditionally (Linux only) | |

**User's choice:** A
**Notes:** Enforces the standard for all future builds

---

## Test Enablement Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| A | Enable all tests and fix everything | ✓ |
| B | Enable but disable specific failing ones | |
| C | Skip tests entirely, defer to Phase 3 | |

**User's choice:** A
**Notes:** Comprehensive verification

| Option | Description | Selected |
|--------|-------------|----------|
| A | CppUnit unit tests only | ✓ |
| B | CppUnit + cpplint style checks | |
| C | All: CppUnit + cpplint + cppcheck | |

**User's choice:** A
**Notes:** Focus on core functionality verification first

| Option | Description | Selected |
|--------|-------------|----------|
| A | Fix all failures inline during Phase 2 | ✓ |
| B | Document known failures | |
| C | Skip failing tests individually | |

**User's choice:** A
**Notes:** Part of the "make it build and test" goal

| Option | Description | Selected |
|--------|-------------|----------|
| A | No — all tests without hardware | |
| B | Yes — some tests validate hardware | |
| C | Split: unit without, integration with | ✓ |

**User's choice:** C
**Notes:** Best of both: CI-friendly unit tests and comprehensive hardware validation

---

## Build Output Location

| Option | Description | Selected |
|--------|-------------|----------|
| A | Use `build/telldus-core-headless` (Phase 1) | |
| B | Use `build/` with subdirs for configs | ✓ |
| C | Out-of-tree in `/tmp` or user-specified | |

**User's choice:** B
**Notes:** Organized structure supporting multiple build configurations

| Option | Description | Selected |
|--------|-------------|----------|
| A | Just two: `build/arch/` and `build/tests/` | |
| B | Three: `build/debug/`, `build/release/`, `build/tests/` | |
| C | CMake presets | ✓ |

**User's choice:** C
**Notes:** Modern CMake approach, version-controlled build configurations

| Option | Description | Selected |
|--------|-------------|----------|
| A | Add `build/` to `.gitignore` | ✓ |
| B | Track empty `build/` with `.gitkeep` | |
| C | Don't gitignore | |

**User's choice:** A
**Notes:** Standard practice

---

## the agent's Discretion

The user provided clear choices for all questions — no areas deferred to agent discretion.

## Deferred Ideas

None — discussion stayed within phase scope.
