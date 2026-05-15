# Phase 08: Operator Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 08-operator-documentation
**Areas discussed:** Documentation structure, Audience targeting

---

## Documentation Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single comprehensive README | One README.md at repo root covering all topics. Simple but potentially long. | |
| README + docs/ folder | Root README with quickstart, detailed guides in docs/. Most common open source pattern. | |
| README + wiki approach | Minimal README pointing to GitHub wiki. Better for evolving docs but adds hosting complexity. | |

**User's choice:** Single comprehensive README (initially), then refined to README + QUICKSTART.md

**Notes:** User initially selected single README but after discussion of content volume, agreed to split into README (concise full guide) + QUICKSTART.md (ultra-terse commands). This balances completeness with accessibility.

---

## Documentation Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Single README, all content | One file with everything. | |
| README + docs/ detailed guides | README summarizes, docs/ has deep dives. | |
| Consolidate into README + QUICKSTART.md | Two-file approach, absorb docs/ content. | ✓ |

**User's choice:** Consolidate everything into README + QUICKSTART.md

**Notes:** User wants to avoid maintaining parallel documentation. Existing docs/ content will be absorbed into README or removed. docs/ folder kept only for protocol documentation (*.dox files) and generated artifacts.

---

## README Length

| Option | Description | Selected |
|--------|-------------|----------|
| Concise (~200 lines) | Brief sections, bullet points, minimal explanation. | ✓ |
| Complete (~500-800 lines) | Full context, explanations, code blocks, examples. | |
| Comprehensive (~1000+ lines) | Everything including troubleshooting matrix, protocol details. | |

**User's choice:** Concise (~200 lines)

**Notes:** User prefers brevity. Detailed content that doesn't fit will go into existing phase documentation (CONTEXT.md, SUMMARY.md) which will be linked from README.

---

## Overflow Content Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Link to phase docs | Brief summaries with links to .planning/phases/ for details. | |
| Create QUICKSTART.md | Ultra-concise quick reference, keep existing docs/ for deep dives. | ✓ |
| Inline foldable sections | Use HTML details/summary tags for expandable sections. | |

**User's choice:** Create QUICKSTART.md

**Notes:** Two-file structure confirmed: README = full guide concise, QUICKSTART.md = ultra-terse commands only.

---

## Audience Targeting

| Option | Description | Selected |
|--------|-------------|----------|
| Single doc with role markers | One README with 'For Developers' and 'For Operators' sections. | |
| Separate entry points | README for operators, BUILDING.md for developers. | ✓ |
| Progressive depth | README starts simple, deepens into developer details. | |
| Platform-based split | Sections for Arch vs Raspberry Pi users as primary dimension. | |

**User's choice:** Separate entry points (but minimal)

**Notes:** User wants clean separation but minimal file count. Final structure: README.md (complete concise) + QUICKSTART.md (ultra-terse). No separate BUILDING.md or OPERATING.md.

---

## File Split Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| README + BUILDING.md + OPERATING.md | Three files: overview, native build, operations. | |
| README + QUICKSTART.md | Two files: full guide + ultra-concise commands. | ✓ |
| README + ARCH.md + DEBIAN.md + DOCKER.md | Platform-specific files. | |

**User's choice:** README + QUICKSTART.md

**Notes:** User prefers minimal file count. Two files sufficient: README has all content concisely, QUICKSTART is command reference only.

---

## Content Split Between Files

| Option | Description | Selected |
|--------|-------------|----------|
| README = narrative, QUICKSTART = commands | README explains what/why, QUICKSTART is copy-paste only. | |
| README = Docker, QUICKSTART = everything | README focuses on Docker, QUICKSTART covers both native and Docker. | |
| README = full guide concise, QUICKSTART = ultra-terse | README has complete concise coverage, QUICKSTART is essentials only. | ✓ |

**User's choice:** README = full guide concise, QUICKSTART = ultra-terse

**Notes:** README will be comprehensive but concise (~200 lines). QUICKSTART will be just the essential commands for the impatient user who wants to get running immediately.

---

## Deferred Ideas

The following were noted during discussion and deferred to future work:

- MQTT integration guide (explicitly deferred to v2)
- Home Assistant MQTT discovery setup (deferred to v2)
- Native packaging instructions (APK, DEB packages - deferred)
- Systemd service setup guide (deferred - Docker primary for now)
- TelldusCenter GUI documentation (explicitly out of scope for v1)
- Man pages or --help documentation generation
- Auto-generated documentation from code comments

---

## Summary

**Final documentation structure:**
- `README.md` (~200 lines): Concise but complete guide covering all aspects (Docker quickstart, native builds for Arch and Debian/RPi, configuration, verification, troubleshooting, v2 roadmap)
- `QUICKSTART.md`: Ultra-terse command reference only, no explanations
- Existing `docs/` folder: Keep only for protocol documentation (*.dox files), consolidate runtime docs into README

**Key decisions captured in CONTEXT.md:**
- D-08-01: Two-file approach (README + QUICKSTART.md)
- D-08-02: Consolidate docs/ content
- D-08-03: Separate entry points but minimal files
- D-08-04: Progressive disclosure within README
- D-08-05: README section ordering
- D-08-06: QUICKSTART.md content type
- D-08-07: Documentation scope boundaries
- D-08-08: Reference phase artifacts for details
