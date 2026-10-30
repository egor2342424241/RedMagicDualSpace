# RedMagicDualSpace WebUI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a safe first KernelSU module build that diagnoses Android multi-user support, creates one managed secondary user, and switches between users through KernelSU WebUI.

**Architecture:** An allowlisted shell controller owns all privileged Android commands. The WebUI calls only fixed operations through KernelSU Manager's documented `window.ksu.exec` bridge. Host tests exercise real shell control logic with fake Android commands; GitHub Actions validates source and ZIP layout.

**Tech Stack:** POSIX shell, HTML/CSS/JavaScript, KernelSU WebView bridge, Python 3 standard library, Node.js 22 for JS bridge tests, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-10-30-redmagicdualspace-design.md

## Global Constraints

- Target: REDMAGIC 10 Pro NX789J, Android 16, REDMAGIC OS 11.
- Use Android's full secondary-user type; this is not a second OS.
- KernelSU WebUI only.
- No Magic Key polling/interception until the actual event is identified on-device.
- No profile deletion, PIN collection/storage, boot-time user creation, or Settings/SystemUI patching.
- Fixed allowlisted operations and exact live user-ID validation.
- Wi-Fi/mobile separation and native Settings integration are unverified and not advertised as supported.

## Review Focus

- Existing exact-name profile with missing or stale stored ID.
- Malformed command output and invalid user IDs.
- User creation attempted outside owner user 0.
- Android command unavailable or OEM denies user creation.
- Duplicate exact-name profiles.

---

### Task 1: Shell controller and host tests

**Files:** scripts/dualspace.sh; tests/test_dualspace.py; tests/fakes/pm; tests/fakes/am; tests/fakes/getprop.

**Interface:** `sh scripts/dualspace.sh {status|create|switch-owner|switch-space}`. State persists in `/data/adb/redmagicdualspace/user_id`, directory mode 0700, file mode 0600.

- [x] Write tests for owner-only creation, ID persistence/permissions, exact-name idempotency, live-list verification, owner switch, invalid output, and bad arguments.
- [x] Verify expected failures before implementation.
- [x] Implement a fixed-name secondary user with `pm create-user --user-type android.os.usertype.full.SECONDARY`.
- [x] Verify Python host suite: 11 tests passing.
- [x] Commit: safe Android secondary-user controller.

### Task 2: KernelSU WebUI

**Files:** module.prop; webroot/index.html; webroot/app.js; webroot/kernelsu-api.js; webroot/style.css; tests/test_webui_contract.py; tests/test_webui_bridge.mjs.

**Interface:** JS adapter wraps `window.ksu.exec(command, optionsJson, callbackName)`. WebUI calls only the four fixed controller actions; create requires explicit confirmation.

- [x] Add the contract test for the WebUI entry point, fixed actions and bridge.
- [x] Add responsive UI, visible command status/output, busy-state controls, and creation confirmation.
- [x] Do not accept arbitrary shell command text.
- [x] Verify Node bridge tests: 3 passing; Python contract tests: 3 passing.

### Task 3: Packaging and CI

**Files:** .github/workflows/validate.yml; tools/build-module.sh; tests/test_package.py; README.md; LICENSE.

**Interface:** deterministic `dist/RedMagicDualSpace-<version>.zip`; the archive contains module.prop, the shell controller, and the complete WebUI. ZIP builder uses only Python standard library and does not need npm.

- [x] Add archive layout and file-mode checks.
- [x] Add deterministic ZIP builder.
- [x] Add CI for Python tests, Node bridge tests, JS syntax, shell syntax, ZIP build and artifact upload.
- [x] Document first-run caution and unsupported device-specific features.
- [x] Local verification: 14 Python tests, 3 Node tests, shell syntax, JS syntax and ZIP package test pass.

## Device-only validation

Not complete until tested on the physical NX789J:
- `pm list users`, `dumpsys user`, secondary-user creation and switching.
- Independent app installation and data separation.
- Separate keyguard credential for the second user.
- Magic Key event discovery and automatic switch.
- Network behavior.
- Supported native Settings entry, if any.

## Review note

Self-review only (no remote subagent/reviewer tool is available in this session). The ZIP is a host-validated alpha and is not yet device-validated.
