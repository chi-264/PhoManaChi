# Implementation status

## Current milestone: Flutter foundation and frontend redesign

Implemented: Flutter Android shell, Riverpod, go_router, SharedPreferencesAsync theme,
Pigeon contract v1, Kotlin host registration/cleanup, background system snapshot reads,
partial-data notices, manual/resume refresh, dashboard, battery screen, diagnostic identity,
and honest feature placeholders.

The Figma-inspired Flutter redesign adds shared semantic themes/components, compact
single-column layouts, wide navigation, dashboard shortcuts, nested More/back behavior,
and readable battery/settings/diagnostics screens. See [frontend redesign](frontend-redesign.md)
for delivered scope and remaining native workflows.

Automated checks cover absent/inconsistent RAM readings, unavailable values in the UI,
and native-read errors with retry. An Android APK build checks Dart, generated bindings,
Kotlin, Android resources, and Gradle integration together. Check the task report for the
actual build/test results; successful compilation is not physical-device validation.

## Next milestones

1. Capability resolver: typed per-operation states and native revalidation, permission UI,
   visible package inventory, app settings and supported uninstall flow.
2. Storage: MediaStore/SAF selection, cancellable identified scans, categories, hashing,
   explicit deletion confirmation, per-file verification, separate deleted-byte and
   free-space-change reports. Enforce critical rules natively.
3. Processes: accessible own-process diagnostics and accurately sourced observations,
   optional usage history, protected-target policy, disabled unsupported controls.
4. Manufacturer tools: firmware-specific verified profiles, exported activity checks,
   safe launches and system-settings fallback. No external-cleanup success inference.
5. Release: integration tests, accessibility/large-text checks, performance measurements,
   device validation and production signing.
6. Post-MVP: optional Shizuku with per-action checks, authorization-loss handling, and
   explicit disruptive-action confirmation. Root remains outside the MVP.

## Required physical-device evidence

No physical device has been validated by this implementation yet. Record installed OS,
firmware, API level, available metrics, denied/revoked permissions, lifecycle behavior,
and manufacturer activity results on Realme 5i and TECNO Spark 30 5G. Validate newer Android
versions independently. Manufacturer profiles must remain disabled until tested.

## Scope decisions

Use PRD v1.1 and Architecture v1.1 as the implementation baseline. UI/UX, Personas, and
Journeys v1.0 support that Flutter design. The original Kotlin/Compose documents are
historical. Default package identifier is `dev.phomanachi.phomanachi`; confirm ownership
before publishing. No backend, analytics, advertising SDK, or release internet permission
is included. Debug/profile manifests retain Flutter development network access.

## Original foundation verification

- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: four tests passed, including the complete navigation-to-battery flow.
- Physical-device runtime validation: pending.
- `flutter build apk --debug`: passed. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
  The first build installed missing Android SDK Platform 35 and CMake 3.22.1 components.

## Frontend redesign verification

- `flutter test --no-pub --dart-define=CAPTURE_PREVIEWS=true`: all 14 tests passed.
  Includes 320 px / 2× text in both themes, real refresh/resume calls, More/back
  behavior, theme selection, unavailable readings, wide navigation, and color contrast targets.
- `flutter build apk --debug --no-pub`: passed with the redesigned frontend.
- Compact light/dark and wide dashboard previews were generated and visually inspected
  in `build/previews/`. Values are test fixtures, not physical-device readings.
- Physical-device and TalkBack validation remain pending.
- Final `flutter analyze --no-pub`: passed with no issues.
