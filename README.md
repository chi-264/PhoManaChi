# PhoManaChi — Android Phone Manager

An offline, ad-free Android utility based on the specifications in `Documentations/`.
PRD v1.1 and System Architecture v1.1 supersede the native-only v1.0 design.

## Foundation delivered

- Android-only Flutter project (minimum Android 9 / API 28).
- Material 3, light/dark/system themes persisted with SharedPreferencesAsync.
- Riverpod repository wiring and asynchronous state handling.
- go_router navigation with five persistent tab branches.
- Versioned, generated Pigeon interface to native Kotlin.
- Real device identity, overall physical RAM, internal storage capacity, and battery readings.
- Manual refresh and refresh on app resume; no continuous background polling.
- Independent native read failures, unavailable states, and retry UI.

Storage scanning/deletion, application inventory, detailed process inspection, manufacturer
launching, and Shizuku are **not implemented yet**. Their screens explain the current status.
No file deletion, process termination, broad storage permission, or package inventory permission
is enabled in this foundation.

## Development

Tested SDK: Flutter 3.47.4 / Dart 3.13.3. Dependencies are resolved in `pubspec.lock`.
Install Flutter and Android SDK, then run:

```sh
flutter pub get
dart run pigeon --input pigeons/system_api.dart
flutter analyze
flutter test
flutter run
```

Build a debug APK with `flutter build apk --debug`. Release signing is not configured;
the scaffold uses debug signing and is not ready for store publication.

## Architecture

`lib/app` owns routing, themes, and lifecycle refresh. `lib/features/dashboard` renders
asynchronous readings. `lib/core/domain` defines the repository contract and memory/unit
rules. `lib/core/platform` contains generated Pigeon bindings. Native implementations live
under `android/app/src/main/kotlin/dev/phomanachi/phomanachi/platform`.

Edit `pigeons/system_api.dart` and regenerate both bindings when the contract changes.
Never edit generated bindings by hand. The contract version is currently 1.

Core Android readings run on a background dispatcher and require no runtime permission.
Storage totals represent the internal data volume; they are not a complete file inventory.
Estimated used RAM is total minus available RAM, not the sum of application usage.
Battery health is the system's categorical state, not a capacity or lifetime estimate.

See [implementation status](docs/implementation-status.md) for the remaining milestones.
