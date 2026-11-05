# App management milestone — 0.3.0 / build 3

This milestone implements the capability/permission foundation and Application
Manager scope in the existing PRD v1.1 roadmap (FR-015–FR-020 and FR-049–FR-053).
The original `Documentations/` files are absent from the current checkout; scope
uses the previously recorded [requirements audit](figma-frontend-audit.md) and
[implementation roadmap](implementation-status.md).

## Device workflow

Open **Apps** to read the current profile's visible applications. Search matches
name and package identifier; filters distinguish user/system apps, including
updated system applications. Sort by name, package name, or latest update.
Refresh performs a native query and dates the actual result. An error is distinct
from an empty inventory or an empty search result; unreadable individual records
produce a partial-inventory notice. Inventory rows are built lazily.

Open an app to inspect version, type, enabled state, installation/update dates,
Android UID, target API, installer package, readable APK-file size, and requested
permissions with Android-reported grant flags. Unknown values stay unavailable.
APK-file size includes base/split APKs only; it is not app data/cache/total storage.
Permission grant flags are not a claim that special access or every operation is
authorized. App settings remain the supported place to change another app's access.

Application details keep Apps selected. Back restores the list's search, filter,
sort and scroll state. Returning from Android refreshes inventory, open details,
capabilities, and any persisted uninstall result. Core readings remain independent.

## Capabilities and permissions

**More → Permissions** reads a typed native capability snapshot with a real check
time. States distinguish available, permission required, restricted, unsupported,
and unavailable. It covers visible inventory, app settings, per-app uninstall,
notification access, APK installation access, and unavailable cleanup/advanced
features. Settings actions are selected from a fixed native allowlist.

No runtime access prompt is shown just for opening Apps or Permissions. Permission
and restriction checks run again natively at action time. Notification access does
not imply automatic milestone checks are enabled; that remains an App updates
preference. Revocation is reflected when returning to the app.

## Uninstall safety and outcomes

1. The detail screen shows the target package, version, protection reason, and
   supported actions. Missing or unavailable checks disable uninstall.
2. **Request uninstall** opens an in-app review explaining potential local-data
   loss. **Keep app** performs no native uninstall request.
3. **Continue to Android** sends the reviewed package, version code, and update
   time. Kotlin reloads the target, rejects changed/absent targets, rechecks
   restrictions, and serializes confirmation requests.
4. Protected targets include this application, system/updated-system apps, core
   Android UIDs, default home/dialer/SMS/keyboard packages, active device
   administrators, and user/device restrictions. Failed protection checks deny
   uninstall. Android can enforce additional policy at confirmation time.
5. Android's uninstall UI requires the user's confirmation. `REQUEST_DELETE_PACKAGES`
   permits the request; it does not grant silent deletion privileges.
6. The app records the request before opening Android. Only Android's success
   result plus a follow-up absent-package check yields **Uninstall verified**.
   Cancellation with the app still present is **Uninstall canceled**. Missing,
   inconsistent, interrupted, or otherwise ambiguous results remain **unverified**.
   A package disappearing from a visibility-filtered list alone is not proof.
7. The last uninstall result is kept locally across process death and can be
   dismissed after completion. No reclaimed-byte or cleanup-success claim is made.

The compatibility path uses `ACTION_UNINSTALL_PACKAGE` with `EXTRA_RETURN_RESULT`
for user-confirmed management of visible third-party apps on API 28+. This intent
is deprecated on newer Android, but remains documented. The recommended
`PackageInstaller.uninstall` API is restricted to installer-of-record/device-owner
roles; Phone Manager does not assume those privileges. Firmware support must be
verified on the actual target phones. Unsupported handlers/settings failures have
explicit fallback guidance. No all-users or silent removal is requested.

## Architecture and visibility

`pigeons/apps_api.dart` generates the separate Dart/Kotlin apps interface. Repository
providers and the action controller own async UI state; native Kotlin queries and
protection checks run off the main thread. Native result callbacks invalidate the
appropriate providers. Pigeon bindings are generated rather than edited manually.

Selective manifest queries cover launcher/default-role applications and supported
Android settings/uninstall handlers. `QUERY_ALL_PACKAGES` is not requested.
The default-SMS check includes Android's required `SMS_DELIVER` visibility query.
Other profiles and hidden packages may be absent. Installed apps are never presented as
running processes. App inventory and permissions remain local; update requests do
not upload them.

## Release and physical-device acceptance

Prepared version: **0.3.0+3**, with `release-notes/0.3.0.md`. Development is on
`feature/app-management`. Merge tested changes to `main` and publish through the
existing milestone workflow using the same signing key. Local implementation or
an APK build does not mean the milestone has been published.

Validate on Realme 5i and TECNO Spark 30 5G:

- Real inventory, user/system filters, labels/version/permissions, missing metadata,
  restricted visibility, large lists, rotation, large text, both themes, and TalkBack.
- Opening app settings and returning after permission/default/enabled-state changes.
- Protected/default/admin targets; Android restrictions; failed/unsupported handlers.
- A disposable test app: cancel the review, cancel Android uninstall, then explicitly
  confirm uninstall and compare the result with actual installed state.
- Update/reinstall a test target after opening details; confirm stale review is rejected.
- Process interruption while Android confirmation is open; no invented success.
- Existing v0.2.0 discovers published v0.3.0, downloads, verifies, installs with the
  same signer, reports build 3, and preserves theme/update preferences.

These physical-device behaviors are not established by widget/unit tests alone.

## Completed local verification

Static analysis, 45 Flutter tests, 19 native tests, and 11 release-tool tests passed.
The signed release APK and matching update assets are prepared in
`build/milestone-release/`. The APK's signing certificate matches the downloaded,
signature-verified public v0.2.0 APK. Light/dark fixture previews were inspected;
compact large-text checks passed. No authorized device was connected for runtime
validation. See [implementation status](implementation-status.md) for the results.

## Platform references

- [Android package visibility](https://developer.android.com/training/package-visibility)
- [Uninstall confirmation intent](https://developer.android.com/reference/android/content/Intent#ACTION_UNINSTALL_PACKAGE)
- [PackageInstaller role restrictions](https://developer.android.com/reference/android/content/pm/PackageInstaller#uninstall(java.lang.String,%20android.content.IntentSender))
- [Contextual access and revalidation](https://developer.android.com/training/permissions/requesting)
