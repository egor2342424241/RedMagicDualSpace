# RedMagicDualSpace WebUI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a safe first KernelSU module build that can diagnose Android multi-user support, create one managed secondary user, and switch between the owner and that user through KernelSU WebUI.

**Architecture:** A small allowlisted shell controller owns all privileged Android commands. KernelSU WebUI invokes only fixed controller actions through the documented kernelsu package. Host-side tests exercise shell behavior with fake Android command binaries; GitHub Actions validates the ZIP layout.

**Tech Stack:** POSIX shell, HTML/CSS/JavaScript, KernelSU WebUI JS API, Python 3 standard-library unittest, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-10-30-redmagicdualspace-design.md

## Global Constraints

- Target device: REDMAGIC 10 Pro (NX789J), Android 16, REDMAGIC OS 11.
- Use Android's native full secondary user; do not claim a second OS.
- Module interface: KernelSU WebUI only.
- No background Magic Key polling or interception in this release.
- No user deletion, PIN collection/storage, boot-time user creation, or Settings.apk/SystemUI patch.
- All WebUI actions must use a fixed allowlist and validated user IDs.
- Treat Wi-Fi/mobile network independence and native Settings integration as unsupported until verified.

## Review Focus

- Existing managed user already present but saved ID missing.
- Malformed or stale saved user ID.
- Profile creation attempted while a non-owner user is active.
- Android shell command missing or OEM user creation denied.
- Command output containing spaces or unexpected failure text.

---

### Task 1: Shell controller and host tests

**Files:**
- Create: scripts/dualspace.sh
- Create: tests/test_dualspace.py
- Create: tests/fakes/pm
- Create: tests/fakes/am
- Create: tests/fakes/getprop

**Interfaces:**
- Controller CLI: sh scripts/dualspace.sh {status|create|switch-owner|switch-space}
- Test override only: RMDSS_STATE_DIR may redirect persisted state for host tests.
- Persisted managed user ID: <state-dir>/user_id.

- [ ] Write tests for owner-only creation, successful creation and ID persistence, idempotent reuse of an existing exact-name profile, second-user switching only after live-list verification, owner switching, and non-owner creation rejection.
- [ ] Run python3 -m unittest discover -s tests -v; confirm expected failures before implementation.
- [ ] Implement the allowlisted shell controller with a fixed user name, numeric ID validation, exact-name live-list verification, and explicit error output.
- [ ] Run python3 -m unittest discover -s tests -v and sh -n scripts/dualspace.sh; both must pass.
- [ ] Commit as feat: add safe Android secondary-user controller.

### Task 2: KernelSU metadata and WebUI

**Files:**
- Create: module.prop
- Create: webroot/index.html
- Create: webroot/app.js
- Create: webroot/style.css

**Interfaces:**
- WebUI imports exec from kernelsu.
- WebUI runs only sh /data/adb/modules/redmagicdualspace/scripts/dualspace.sh <fixed-operation>.
- UI actions: diagnostics, create managed space (confirmation required), switch to owner, switch to managed space.

- [ ] Add a source-level test confirming the module metadata ID matches the fixed install path, WebUI entrypoint exists, and only the four fixed controller operations are exposed.
- [ ] Run that test and confirm it fails before adding the module/WebUI files.
- [ ] Add KernelSU metadata and a responsive WebUI with status display, clear warnings, and disabled controls while requests run.
- [ ] Use await exec() and display both stdout and stderr; surface non-zero exit codes as failures.
- [ ] Run the full Python test suite and shell syntax check; inspect the UI source for arbitrary command input.
- [ ] Commit as feat: add KernelSU WebUI dashboard.

### Task 3: Build validation and user documentation

**Files:**
- Create: .github/workflows/validate.yml
- Create: tools/build-module.sh
- Create: tests/test_package.py
- Modify: README.md

**Interfaces:**
- Build output: dist/RedMagicDualSpace-v<version>.zip.
- ZIP root contains module.prop, scripts/dualspace.sh, and webroot/index.html.

- [ ] Write a package-layout test that fails when a required file or metadata field is missing.
- [ ] Run the package test and observe the expected failure before adding the builder/workflow.
- [ ] Implement deterministic ZIP packaging and GitHub Actions validation (Python tests, shell syntax, package build and layout inspection).
- [ ] Document install, safe first-run sequence, current limitations, and exact ADB diagnostics required from the device.
- [ ] Run all tests, build the archive, inspect its members, and run shell syntax validation.
- [ ] Commit as build: add module packaging and CI validation.

## Device-only validation after this plan

Do not mark the following as complete without physical-device output:
- pm list users and dumpsys user confirm creation/switch availability.
- Second user can complete first-run setup and install an app independently.
- Android keyguard accepts a separate credential for the second user.
- Magic Key input/broadcast source is identified before enabling any automation.
- Separate network behavior is measured rather than assumed.
- Native Settings entry is implemented only if a stable vendor-supported mechanism is found.
