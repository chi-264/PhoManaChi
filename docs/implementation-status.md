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
before publishing. No backend, analytics, or advertising SDK is included. Version 0.2.0 adds internet
access for the user-requested optional milestone updater; core readings remain offline.
Debug/profile manifests retain Flutter development network access.

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


## Milestone updater (0.2.0 / build 2)

Implemented typed Flutter/Kotlin update APIs, App updates UI, foreground availability
banner, manual and opt-in scheduled checks, notification permission/status/deep links,
streamed/cancelable APK downloads, checksum/identity/version/signer verification,
user-confirmed Android installation, and a signed GitHub milestone release workflow.

The old APK must be updated once to bootstrap this feature. Live delivery uses a
public release manifest, stable signing credentials, and notification opt-in.
See [milestone updates](milestone-updates.md) for publishing and device validation.
Release [v0.2.0](https://github.com/chi-264/PhoManaChi/releases/tag/v0.2.0) is now
publicly published. Physical-device update installation remains unverified.

### Updater verification

- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: all 25 tests passed, including update flows and the
  narrow-screen update banner with large text.
- `./gradlew :app:assembleDebug :app:testDebugUnitTest` from `android/`: passed;
  all 11 native policy and file-integrity tests passed.
- Python release-packaging unit tests: all four passed.
- Final debug APK signature/identity inspection and release-asset preparation:
  passed. The bootstrap APK and prepared manifest have matching size and SHA-256.
- Workflow YAML and embedded shell syntax checks passed. The first hosted release
  workflow succeeded and published v0.2.0. Production-key migration and
  physical-device verification remain pending.
- Signing troubleshooting adds an early credential check before the release build.
  Seven real-keystore fixture tests cover JKS/PKCS12, separate key/store passwords,
  missing settings, wrong credentials/alias, and corrupt files without logging secrets.
  The original local debug key also passed validation with standard debug credentials;
  this does not verify the separately configured GitHub secrets.
- Fixed the release workflow's unavailable `testReleaseUnitTest` invocation. AGP 9
  exposes `testDebugUnitTest` under this project's default configuration. Native
  tests now run in a separate step after the signed release build and before
  publication, so Flutter generates the Git-ignored Gradle wrapper first. The replacement
  Gradle command succeeded locally; workflow YAML, shell syntax, and step ordering
  checks passed. The corrected workflow subsequently succeeded on GitHub Actions.

### First public deployment (5 November 2026, Asia/Manila)

Verified that the milestone workflow completed successfully and the public v0.2.0
release contains the APK, checksum, and update manifest. The live latest-release
feed reports version 0.2.0 / build 2; its exact APK URL, size (52,292,177 bytes),
and SHA-256 match GitHub's asset metadata. This verifies publication and metadata,
not physical-device installation, certificate continuity, or notification delivery.
