import 'dart:async';

import 'package:phomanachi/core/platform/apps_api.g.dart';
import 'package:phomanachi/features/applications/apps_repository.dart';

const appObservedAt = 1793850000000;
ApplicationRecord fixtureApp({
  String packageName = 'test.notes',
  String label = 'Notes',
  bool system = false,
  int updated = appObservedAt,
}) => ApplicationRecord(
  packageName: packageName,
  label: label,
  versionName: '1.2.0',
  versionCode: 12,
  systemApp: system,
  enabled: true,
  firstInstalledMillis: appObservedAt - 10000,
  lastUpdatedMillis: updated,
);

AppCapability fixtureCapability(
  String id,
  AccessState state, {
  String? reason,
}) => AppCapability(
  id: id,
  title: id == 'uninstall'
      ? 'Uninstall'
      : id == 'notifications'
      ? 'Milestone notifications'
      : 'Android app settings',
  state: state,
  reason:
      reason ??
      (state == AccessState.available
          ? 'Android confirmation is required.'
          : 'This app is protected by Android.'),
);

class FakeAppsRepository implements AppsRepository {
  List<ApplicationRecord> apps = [
    fixtureApp(),
    fixtureApp(
      packageName: 'android.system',
      label: 'Android System',
      system: true,
    ),
  ];
  int reads = 0;
  int detailReads = 0;
  int checks = 0;
  int uninstalls = 0;
  int settings = 0;
  int accessRequests = 0;
  bool failInventory = false;
  bool failDetails = false;
  bool failCapabilities = false;
  bool failUninstall = false;
  bool notifications = false;
  bool blockUninstall = false;
  bool missingUninstallCapability = false;
  ApplicationRecord? requestedTarget;
  AppActionResult? last;
  Completer<ApplicationInventory>? pending;
  Completer<void>? pendingDismiss;

  @override
  Future<ApplicationInventory> getInventory() async {
    reads++;
    if (failInventory) throw StateError('Native inventory unavailable');
    return pending?.future ??
        ApplicationInventory(
          contractVersion: 1,
          observedAtMillis: appObservedAt,
          apps: apps,
          notices: [],
        );
  }

  @override
  Future<ApplicationDetails?> getDetails(String packageName) async {
    detailReads++;
    if (failDetails) throw StateError('Native details unavailable');
    final matches = apps.where((a) => a.packageName == packageName);
    if (matches.isEmpty) return null;
    final app = matches.first;
    return ApplicationDetails(
      app: app,
      checkedAtMillis: appObservedAt,
      uid: 10123,
      targetSdk: 35,
      installerPackage: 'test.installer',
      apkBytes: 2048,
      permissions: [
        AppPermission(
          name: 'android.permission.CAMERA',
          label: 'Camera',
          granted: false,
        ),
      ],
      capabilities: [
        fixtureCapability('appSettings', AccessState.available),
        if (!missingUninstallCapability)
          fixtureCapability(
            'uninstall',
            app.systemApp ? AccessState.restricted : AccessState.available,
          ),
      ],
    );
  }

  @override
  Future<CapabilitySnapshot> getCapabilities() async {
    checks++;
    if (failCapabilities) throw StateError('Native resolver unavailable');
    return CapabilitySnapshot(
      contractVersion: 1,
      checkedAtMillis: appObservedAt,
      capabilities: [
        fixtureCapability('appSettings', AccessState.available),
        fixtureCapability(
          'notifications',
          notifications
              ? AccessState.available
              : AccessState.permissionRequired,
          reason: notifications
              ? 'Notifications are allowed by Android.'
              : 'Notifications are blocked by Android.',
        ),
      ],
    );
  }

  @override
  Future<AppActionResult> openAppSettings(String packageName) async {
    settings++;
    return AppActionResult(
      packageName: packageName,
      phase: AppActionPhase.opened,
      message: 'Settings opened; changes are not confirmed.',
      checkedAtMillis: appObservedAt,
    );
  }

  @override
  Future<AppActionResult> requestUninstall(ApplicationRecord app) async {
    uninstalls++;
    requestedTarget = app;
    if (failUninstall) throw StateError('Native action failed');
    return last = AppActionResult(
      packageName: app.packageName,
      phase: blockUninstall ? AppActionPhase.blocked : AppActionPhase.requested,
      message: blockUninstall
          ? 'This app changed after you reviewed it. Refresh its details before uninstalling.'
          : 'Android confirmation requested. Removal has not been verified.',
      checkedAtMillis: appObservedAt,
    );
  }

  @override
  Future<AppActionResult?> getLastAction() async => last;
  @override
  Future<void> clearLastAction() async {
    await pendingDismiss?.future;
    last = null;
  }

  @override
  Future<AppActionResult> openAccessSettings(String capabilityId) async {
    accessRequests++;
    return AppActionResult(
      packageName: 'test.phone',
      phase: AppActionPhase.opened,
      message: 'Settings opened; permission has not been confirmed.',
      checkedAtMillis: appObservedAt,
    );
  }
}
