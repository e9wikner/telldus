# Phase 1: Headless Build Boundary - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14T17:44:43+02:00
**Phase:** 1-Headless Build Boundary
**Areas discussed:** Build Entry Point, Dependency Boundary, Legacy Platform Handling, Success Proof

---

## Build Entry Point

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `telldus-core/` as the build root | Least invasive; document/build only from `telldus-core/` and ignore `telldus-gui/` | ✓ |
| Add a repo-root headless build preset/entry point | Easier for future users but adds new build orchestration | |
| You decide | Choose the smallest change that makes headless Linux builds clear and repeatable | |

**User's choice:** Keep `telldus-core/` as the build root.
**Notes:** Phase 1 should preserve the existing project shape.

| Option | Description | Selected |
|--------|-------------|----------|
| Strict headless trio | Phase 1 only concerns `telldusd`, `libtelldus-core`, and `tdtool` | |
| Include tests too | Also wire the test build boundary; running/fixing tests remains mainly Phase 2 | ✓ |
| You decide | Keep the boundary practical if tests affect build structure | |

**User's choice:** Include tests too.
**Notes:** Test execution/fixing is not the main Phase 1 goal.

| Option | Description | Selected |
|--------|-------------|----------|
| Add explicit option/profile | Add a clear headless switch/preset if current options are too implicit | |
| Document existing options | Avoid new build API unless absolutely needed | |
| You decide | Inspect first; add an option only if existing CMake is too unclear | ✓ |

**User's choice:** You decide.
**Notes:** The planner should inspect before deciding whether new CMake surface is needed.

---

## Dependency Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal required only | Allow CMake, C/C++ toolchain, pthreads, libconfuse, libftdi/libusb stack, and test tools only when tests are enabled | ✓ |
| Pragmatic existing deps | Keep any dependency already wired into `telldus-core/` if it does not pull GUI/non-Linux complexity | |
| You decide | Minimize dependencies, but avoid churn if an existing dependency is harmless | |

**User's choice:** Minimal required only.
**Notes:** The headless dependency boundary should be strict.

| Option | Description | Selected |
|--------|-------------|----------|
| Prefer libftdi only | Make libftdi the supported Linux v1 path; ftd2xx out of scope unless harmless | |
| Keep both backends | Preserve both Linux backends if possible | |
| You decide | Prefer libftdi, but keep ftd2xx if it costs almost nothing | ✓ |

**User's choice:** You decide.
**Notes:** libftdi is preferred for Linux v1.

| Option | Description | Selected |
|--------|-------------|----------|
| Remove coupling if found | If Qt/TelldusCenter leaks into `telldus-core`, fix build files now | ✓ |
| Avoid only | Do not remove anything; document the headless path that avoids GUI components | |
| You decide | Fix coupling only if it blocks clean headless configure/build | |

**User's choice:** Remove coupling if found.
**Notes:** Accidental GUI coupling in the headless build is a Phase 1 issue.

---

## Legacy Platform Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Do not touch | Avoid editing non-Linux paths unless absolutely impossible | |
| Guard only | Add guards so Linux builds cleanly, but do not modernize/delete non-Linux logic | ✓ |
| Prune from headless path | Remove non-Linux branches from any new/cleaned headless-only build path | |

**User's choice:** Guard only.
**Notes:** Non-Linux paths are protected, not modernized.

| Option | Description | Selected |
|--------|-------------|----------|
| Modernize only Linux configure path | Keep old declarations where needed, ensure modern Linux configure/build works | |
| Raise CMake baseline globally | Simpler build files, higher risk to legacy platforms | |
| You decide | Choose the least invasive fix that unblocks modern Linux | ✓ |

**User's choice:** You decide.
**Notes:** Avoid broad global CMake baseline changes unless necessary.

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore bindings/examples | Phase 1 only defines core service/client/tdtool/test boundary | ✓ |
| Avoid breaking them | Do not test them, but avoid gratuitous source/API breaks | |
| You decide | Preserve public C API unless a Linux build blocker requires otherwise | |

**User's choice:** Ignore bindings/examples.
**Notes:** Bindings and examples are not part of Phase 1.

---

## Success Proof

| Option | Description | Selected |
|--------|-------------|----------|
| Configure proof | CMake configure succeeds with expected targets visible | |
| Dry build proof | Configure plus at least starting/building target graph enough to prove dependencies and target selection | ✓ |
| Documented boundary proof | No build required yet; planner produces target/dependency boundary for Phase 2 | |

**User's choice:** Dry build proof.
**Notes:** Phase 1 should prove more than documentation.

| Option | Description | Selected |
|--------|-------------|----------|
| Arch local only | Prove boundary on this machine; Raspberry Pi starts Phase 3 | |
| Generic Linux container | Prove boundary in a controlled Linux build environment | |
| Both if cheap | Local Arch first; add container proof only if straightforward | ✓ |

**User's choice:** Both if cheap.
**Notes:** Local Arch is primary.

| Option | Description | Selected |
|--------|-------------|----------|
| Stop with blockers | Document exact blockers and let Phase 2 handle fixes | |
| Fix minimal blockers | Phase 1 may make small fixes needed to establish boundary | |
| You decide | Fix only blockers directly tied to defining the headless boundary | ✓ |

**User's choice:** You decide.
**Notes:** Do not start broad modernization in Phase 1.

| Option | Description | Selected |
|--------|-------------|----------|
| Build notes in Phase 1 summary only | Keep it lightweight | |
| Committed docs/build instructions | Update project docs with exact headless configure/build commands | ✓ |
| You decide | Capture enough for Phase 2 to reproduce the proof without guessing | |

**User's choice:** Committed docs/build instructions.
**Notes:** Phase 2 should not need to guess the commands.

## the agent's Discretion

- Decide whether existing CMake is too unclear and needs an explicit headless option/profile.
- Keep ftd2xx only if it does not complicate Linux v1.
- Choose the least invasive modern Linux CMake unblock.
- Include a generic Linux container proof only if straightforward.
- Fix only blockers directly tied to defining the headless boundary.

## Deferred Ideas

None.
