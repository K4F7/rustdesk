# RustDesk Mobile Input Fixes - Test Status

This document captures the current implementation state and test status for the
mobile input/gesture/shortcut fixes. It is intended to help resume work after a
restart.

## Implemented Fixes (Summary)
- Blue UI controls are now draggable.
- Ctrl shortcuts mapping corrected; Ctrl hold (double-tap) now supports multi-select
  behavior consistent with desktop.
- Shortcut editor supports virtual/soft-key input for Ctrl/Alt/Shift/Win/Cmd.
- Mouse wheel sensitivity is adjustable; UI slider added in mobile settings.
- Removed an unneeded official entry (Chat tab) while keeping core functions.
- IME toggle state now switches on/off correctly with highlight state.
- Fast left-drag canvas no longer misclassified as Ctrl+left box select.
- Ctrl + wheel combination now forwarded correctly.
- Two-finger scroll direction no longer depends on initial finger height.

## Key Files Changed
- `flutter/lib/mobile/widgets/custom_shortcuts.dart`
  - Draggable overlay buttons and keyboard toggle
  - Soft-key modifier buttons in shortcut dialog
  - Modifier handling to align with desktop behavior
- `flutter/lib/common/widgets/remote_input.dart`
  - Two-finger scroll direction fix (uses focal point deltas)
  - Ctrl suppression during touch drag to avoid box-select
- `flutter/lib/common/widgets/gestures.dart`
  - CustomTouchGestureRecognizer pointer filtering
- `flutter/lib/models/input_model.dart`
  - Wheel sensitivity filter, modifier-aware wheel and trackpad events
- `flutter/lib/common/widgets/setting_widgets.dart`
  - Mouse wheel sensitivity slider widget
- `flutter/lib/common/widgets/dialog.dart`
  - Sensitivity dialog wiring to input model
- `flutter/lib/mobile/pages/settings_page.dart`
  - Added input section entry for sensitivity
- `flutter/lib/mobile/pages/home_page.dart`
  - Removed Chat tab entry
- `flutter/lib/mobile/pages/remote_page.dart`
  - Keyboard toggle state fix
- `flutter/lib/consts.dart`
  - Wheel sensitivity keys + limits
- `flutter/lib/models/wheel_sensitivity.dart`
  - WheelSensitivityFilter helper
- `flutter/pubspec.yaml`
  - Added `integration_test` and bumped `ffigen` to align with `file` 7.x

## Automated Tests Added
- `flutter/test/wheel_sensitivity_test.dart`
  - Verifies wheel sensitivity scaling and accumulation
- `flutter/test/shortcut_parser_test.dart`
  - Verifies shortcut parsing and display formatting
- `flutter/test/gesture_recognizer_test.dart`
  - Verifies pointer acceptance filtering
- `flutter/integration_test/app_smoke_test.dart`
  - Boots the app and verifies the mobile home page renders

## Tests Run
- `flutter test` (from `flutter/`) -> PASS
- `flutter test -r expanded` -> PASS
- `flutter test integration_test` (Windows emulator via WSL adb) -> PASS
- `flutter test integration_test --coverage -r expanded` (Windows emulator via WSL adb) -> PASS (coverage file deleted)

## Android Emulator Status (WSL)
- AVDs created:
  - `codex_emulator` (x86_64)
  - `codex_emulator_arm64`
- WSL cannot access KVM (`/dev/kvm` owned by root:kvm; user not in kvm group).
- x86_64 AVD requires KVM; arm64 image cannot run on x86_64 host.

## How to Run Android Tests (Recommended)
Because WSL does not support KVM acceleration, start the emulator on Windows
instead and connect WSL to the Windows adb server.

1) Windows (PowerShell):
   - Start the emulator:
     - `"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd <AVD_NAME>`
2) Windows:
   - `adb.exe start-server`
3) WSL:
   - `export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037`
   - `adb devices` (should list `emulator-5554`)
4) WSL:
   - Run `flutter test` or `flutter test integration_test` once integration tests
     are added.

## Pending / Next Steps
- Optional: add more integration tests for settings/input flows if needed.
