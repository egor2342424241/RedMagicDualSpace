# RedMagicDualSpace — design

Date: 2026-10-30

## Intent

Provide REDMAGIC 10 Pro (NX789J, Android 16, REDMAGIC OS 11) with a clean second Android user whose installed apps and private app data are isolated from the owner's user. The user wants to switch between the owner and this space using the physical Magic Key slider, manage the feature through KernelSU WebUI, and use a separate lock-screen credential for the second user.

## Goals

- Use Android's native full secondary user where the OEM firmware allows it.
- Provide a KernelSU WebUI to inspect user state, create the managed user, and switch to either user.
- Keep the managed user ID persistent and validate it against the live Android user list before switching.
- Make all mutating actions explicit and visible; do not create or switch users automatically during boot in the first release.
- Never store or transmit the user's lock-screen PIN/password.
- Add host-side tests for shell control logic and a release workflow that validates the module archive.

## Non-goals for the first release

- It is not a second Android installation, dual boot, or separate kernel.
- It does not promise independent Wi-Fi/mobile-radio settings. Connectivity hardware and many network settings are device-wide; a per-user VPN may be evaluated separately.
- It does not patch Settings.apk, SystemUI, framework resources, or SELinux policy.
- It does not intercept the Magic Key or automatically switch users until the actual NX789J event/broadcast is observed.
- It does not delete users, copy apps from the owner, or share files between users.
- It does not set, capture, or store a PIN/password.

## Chosen approach

Use AOSP's default android.os.usertype.full.SECONDARY user. Modern Android's pm create-user command defaults to this type. The module gives the user an explicit create action. Android remains responsible for user credentials and keyguard. am switch-user performs explicit switching.

This is preferable to a cloned-app/work-profile-only solution because the user asked for a clean profile with independent app installs and files. Patching the Settings app or SystemUI is more fragile and can break across REDMAGIC OS updates. Magic Key automation is deferred until device logs reveal a reliable event source.

## Architecture

- module.prop: KernelSU module metadata.
- scripts/dualspace.sh: fixed-operation root shell controller (status, create, switch-owner, switch-space). It accepts no arbitrary shell snippets or custom user names.
- webroot/index.html, app.js, style.css: static KernelSU Manager UI using the documented kernelsu JS package and exec() API.
- tests/: host-side tests that run the shell controller with fake pm, am, and getprop commands.
- .github/workflows/validate.yml: checks shell syntax, host tests, archive layout, and module metadata.

## Security and safety constraints

- The module must not change the owner user's files, remove apps, wipe data, or auto-switch users during boot.
- Profile creation is allowed only from current user 0 and only after a UI confirmation.
- The target user ID must be numeric, greater than 0, and verified by exact managed-user name before a switch.
- No command-string concatenation from text fields; WebUI actions call a fixed operation allowlist.
- Profile deletion is intentionally omitted from the UI.
- The owner or second user must set its own lock-screen credential through Android Settings when supported by the firmware.

## Remaining device-specific questions

- Does this REDMAGIC OS build expose Android full-secondary-user creation and switching?
- What exact input event, broadcast, intent, or service transition does Magic Key produce when moved?
- Does REDMAGIC OS permit an independent user lock-screen credential and show keyguard on user switching?
- Is there a supported vendor extension or Settings resource hook for a native “Second Space” Settings entry?

These remain UNVERIFIED until tested on the actual phone.