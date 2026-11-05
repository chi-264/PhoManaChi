# Direct APK milestone updates

This implements direct APK updates using the public GitHub Releases source selected
for this project: **chi-264/PhoManaChi**. It is independent of Google Play in-app
updates and does not replace the core offline device-monitoring features.

## On the device

1. Install the updater-enabled **0.2.0 / build 2** APK once. APKs distributed before
   this milestone do not contain an update checker and cannot acquire one remotely.
2. Open **More → App updates**. Manual checking works without notification permission.
3. Enable **Notify me about new milestones** for automatic checks. Android 13+
   asks for notification permission in this context. If denied, checks and the
   in-app release view remain available; the screen links to notification settings.
4. A newer release shows its version, milestone notes, and APK download size.
   Choose **Download APK**, then **Install update**. Android handles the installation
   confirmation. If needed, enable installation from Phone Manager in Android
   Settings, return, and choose Install update again.

The app never automatically downloads or silently installs an update. Opening
Android's installer is reported as an unverified request, not a successful upgrade.
Canceling its prompt does not advance the installed version. Installed version/code
are read from Android PackageManager on each status refresh.

## How notifications work

Automatic checks default to off. Enabling them schedules a persisted Android
JobScheduler job approximately every **six hours**, with network connectivity and
battery-not-low constraints. Enabled checks also run on app resume, throttled to
one attempt per fifteen minutes. There is no permanent monitoring/foreground service,
push server, Firebase dependency, or exact alarm.

Android can defer background work for power management; force-stopping the app can
prevent checks until it is opened again. This is periodic release discovery, not
instant push delivery. One notification is posted per newly discovered higher
version code, with the last notified code stored locally. If multiple milestones
are published between checks, the latest available milestone is offered. Tapping
the notification opens the Updates screen for both cold and running app launches.

Disabling notifications in the app cancels its scheduled update job and outstanding
milestone notification. Disabling them in Android blocks posting but leaves the
user's selected check preference visible. Download progress is polled only during
an active foreground download and stops polling when the app is backgrounded.

## Release feed and validation

Stable feed URL:

`https://github.com/chi-264/PhoManaChi/releases/latest/download/update.json`

Each stable milestone release publishes these assets together:

- `phomanachi.apk`
- `update.json`
- `phomanachi.apk.sha256`

The manifest schema is generated from the **actual signed APK**, not a separately
maintained version string. It includes schema version, package, version code/name,
minimum SDK, milestone title/notes, APK URL, SHA-256, and exact byte size. The native
client bounds metadata to 64 KiB and APKs to 1 GiB; validates the repository URL,
field types, version/SDK ranges, and checksum format; and follows only HTTPS
GitHub/CDN redirects. A missing first manifest has its own “No published milestone”
state. Network failure is not described as “up to date.”

Downloads go to the app's internal update directory, stream in bounded buffers,
and support cancellation. Before storing a ready APK and again before opening the
installer, native Kotlin verifies:

- Actual byte count and SHA-256 match the manifest.
- The archive package matches this installed application.
- Archive version/code match the release and are newer than the installed code.
- The actual APK minimum SDK is compatible with the device.
- APK signing certificates exactly match the installed application's current signers.

The installer receives a temporarily granted FileProvider content URI scoped to
this app's update directory. No broad storage permission or arbitrary file path is
exposed. Invalid downloads are not offered for installation. Interrupted partial
files are replaced on the next download; obsolete verified APKs are removed after
an upgrade or a subsequent verified download.

## Signing continuity: required once before publishing

Android updates require the same package ID and signing identity. The earlier APKs
shared from this workspace were debug builds. This bootstrap debug APK uses the
existing local debug signing setup, so its update compatibility depends on the same
key being present as was used for the device's installed copy.

For continued development updates without reinstalling, subsequent milestone APKs
must use that **same existing signing key**. A CI runner's newly generated default
debug key will not match. To move to a dedicated production key, plan a one-time
manual reinstall/migration; the updater will reject an unexpected signing change.
It never uninstalls the existing app to work around this restriction.

Configure the repository's Actions secrets with the chosen stable key:

| Secret | Value |
| --- | --- |
| `PHOMANACHI_KEYSTORE_BASE64` | Base64 contents of the matching keystore |
| `PHOMANACHI_STORE_PASSWORD` | Keystore password |
| `PHOMANACHI_KEY_ALIAS` | Signing alias |
| `PHOMANACHI_KEY_PASSWORD` | Key password |

Keystores and local signing properties are ignored by Git. Do not commit or publish
private signing material. The workflow decodes the keystore into its temporary
directory, restricts file permissions, and removes it at the end of the build step.
The release Gradle configuration requires explicit signing credentials rather
than silently substituting another debug key.

Local release builds use `PHOMANACHI_KEYSTORE_PATH` plus the three password/alias
environment variables above. Debug builds retain their existing local debug signing.
No key has been uploaded or repository secret created by this implementation.

### Troubleshoot signing failures

`packageRelease` reporting `Failed to read key ... from store` means the signing
credentials or uploaded keystore need checking. A `.jks` filename does not mean a
PKCS12 keystore must be converted; Java detects the format from the contents.
The workflow now validates the keystore, alias, and private-key password before
installing Flutter or building. Errors name the setting to check without printing
its value. The private-key password is checked separately from the store password.

For the unchanged standard Android debug keystore, the store password is `android`,
the alias is `androiddebugkey`, and the key password is `android`. Enter those exact
values without quotation marks, trailing spaces, or asterisks. Customized keystores
require their actual credentials. If needed, replace the Base64 secret by encoding
the same original keystore again; do not generate a replacement key.

After editing secrets, start a new workflow run. Push this workflow change to `main`
first to receive the earlier, clearer validation messages; rerunning an old failed
run uses its original workflow revision. These checks do not change the signing key.

## Publish each milestone

The repository must be public for unauthenticated devices to access its Releases.
The publisher checks visibility and does not change repository visibility itself.

1. Increase `pubspec.yaml` version **and build number**, for example `0.3.0+3`.
2. Add `release-notes/0.3.0.md` describing the completed milestone.
3. Commit/push the changes and workflow, then push the matching `v0.3.0` tag, or
   run **Publish milestone APK** manually from GitHub Actions.
4. The workflow tests Flutter, Python packaging, and native verification policies;
   builds a signed release APK; generates matching metadata; and publishes the
   assets. Publication starts as a draft and becomes the latest stable release
   only after all assets are uploaded. Existing release tags are not overwritten.
5. The publishing script rejects build numbers that do not advance beyond the
   last published updater manifest. Device-side checks independently reject equal
   versions and downgrades.

Only a published milestone can trigger discovery. Editing source code, finishing
an internal task, or building an APK locally does not publish it to installed devices.
Every milestone should therefore finish with the version/notes/tag release steps.

### Prepare or publish manually

```sh
flutter build apk --debug --no-pub
python3 tool/prepare_update.py --apk build/app/outputs/flutter-apk/app-debug.apk
```

This prepares development-signed assets in `build/milestone-release/` with the
APK, manifest, checksum, and release notes. Publish under the tag matching the
actual APK version (`v0.3.0` for the currently prepared app-management milestone),
ensuring it is the latest stable release. The initial `v0.2.0` bootstrap is already
public. Later versions must increase the build number and use the same signing key.

With an authenticated GitHub CLI and publication authorization, the prepared assets
can be published with `python3 tool/publish_milestone.py`. Production automation
uses the signed release build instead. The manifest download URL always points to
the exact immutable version tag; it does not accidentally fetch an APK from a
newer release while using an older release's checksum.

## Permissions

- `INTERNET`: optional update manifest/APK requests; core readings remain local.
- `ACCESS_NETWORK_STATE`: scheduling update checks when connected.
- `POST_NOTIFICATIONS`: contextual milestone notification permission on Android 13+.
- `REQUEST_INSTALL_PACKAGES`: user-confirmed self-update through Android's installer.
- `RECEIVE_BOOT_COMPLETED`: allows the opted-in periodic job to persist across reboot.

No notification or installation permission prompt is shown just for opening the
Dashboard. The installation permission is checked only when the user requests the
verified APK's installation.

## Verification and remaining deployment work

Automated coverage includes version/downgrade rules, allowed sources, signer/package
identity checks, corrupted/truncated files, notification deduplication, user-initiated
download/install actions, denied permissions, offline checks, canceled downloads,
large text, and notification deep links. See the task result for actual check outcomes.

The first hosted workflow has succeeded and published
[v0.2.0](https://github.com/chi-264/PhoManaChi/releases/tag/v0.2.0).
The public latest-release feed is accessible, and its APK URL, size, and SHA-256
agree with GitHub's asset metadata. Signing secrets were configured by the user;
this verification did not read or change them.

Still required on devices:

- Install the bootstrap on the device and enable milestone notifications.
- Exercise a two-version signed update on Realme 5i and TECNO Spark 30 5G, including
  notification denial, unknown-app permission, offline mode, canceled download,
  tampering, canceled installation, reboot, and post-install version confirmation.

Live publication was verified separately from local build and test results.
Physical-device installation and notification delivery remain unverified.

The native verification step runs `:app:testDebugUnitTest` after building the
signed release APK and before preparing or publishing assets. Flutter's build
generates the Git-ignored Gradle wrapper, which is absent in a fresh checkout.
AGP 9 enables unit tests only for the tested build type by
default (debug here), so `:app:testReleaseUnitTest` is not available in this
configuration. The tests exercise the shared `src/test` update policies and file
integrity code; the APK is still built with `flutter build apk --release`.
The workflow locates both the wrapper and Gradle project explicitly under
`$GITHUB_WORKSPACE/android`, so the native test command does not depend on the
shell's current working directory.

## Platform references

- [Android JobScheduler](https://developer.android.com/reference/android/app/job/JobScheduler)
- [Notification runtime permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Android app signing and update identity](https://developer.android.com/studio/publish/app-signing)
- [Secure file sharing](https://developer.android.com/training/secure-file-sharing/share-file)
- [GitHub latest-release asset links](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)
