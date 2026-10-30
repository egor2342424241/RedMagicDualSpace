# RedMagicDualSpace

KernelSU module prototype for REDMAGIC 10 Pro (NX789J, Android 16 / REDMAGIC OS 11).

> **Status: experimental / device validation required.** This repository does not claim that Magic Key interception, a Settings integration, independent Wi-Fi configuration, or PIN provisioning works on this firmware yet.

## Current scope

- KernelSU WebUI dashboard.
- Read-only device and Android multi-user diagnostics.
- Explicit creation of one clean Android secondary user.
- Explicit switching between the owner (user 0) and the managed secondary user.
- No automatic boot-time user creation, no deletion action, and no background polling.
- No attempt to patch Settings.apk or SystemUI.

## Important limitations

Android secondary users share the device OS, kernel, radio hardware, and system services. App data and user storage are separated by Android's multi-user model, but Wi-Fi and mobile connectivity are device-wide in the normal Android architecture. A separate per-user VPN may be configured later, but it is not equivalent to separate network hardware/settings.

The REDMAGIC Magic Key currently exposes OEM actions in Settings. Its hardware event or broadcast has not yet been identified. Automatic switching is deliberately disabled until an actual event is observed on the target device.

A separate Android user can be protected with the normal Android lock-screen credential when the firmware supports that flow. This module will never store or set a PIN itself.

## Installation (when a validated ZIP is published)

1. Install the ZIP from KernelSU Manager.
2. Reboot only when the build instructions explicitly require it.
3. Open the module's WebUI.
4. Run diagnostics before creating a user.
5. Create the secondary user only after reviewing the device's reported user limit.

Do not install experimental builds on a device with important unbacked-up data.

## Device validation still required

Run from a computer with ADB:

```sh
adb shell pm list users
adb shell am get-current-user
adb shell dumpsys user
adb shell getprop ro.build.display.id
adb shell getprop ro.build.version.incremental
adb shell getprop ro.build.version.release
adb shell getevent -lp
```

For Magic Key investigation, compare input/event logs while moving the slider through both positions. Do not infer a trigger from the Game Space screen alone.

## Development

The module uses shell scripts and a static KernelSU WebUI. Shell behavior is covered by host-side tests where possible. Device-only functions must be marked **UNVERIFIED** until tested on REDMAGIC 10 Pro NX789J running Android 16 / REDMAGIC OS 11.

## License

MIT
