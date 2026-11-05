import 'dart:async';

import 'package:phomanachi/core/platform/update_api.g.dart';
import 'package:phomanachi/features/updates/update_repository.dart';

UpdateRelease milestone() => UpdateRelease(
  versionCode: 3,
  versionName: '0.3.0',
  title: 'Storage milestone',
  notes: 'Storage analysis and confirmed file review.\nReview this milestone before downloading.',
  apkUrl: 'https://github.com/chi-264/PhoManaChi/releases/download/v0.3.0/phomanachi.apk',
  sha256: 'a' * 64,
  sizeBytes: 1024 * 1024,
  minSdk: 28,
);
UpdateStatus updateStatus({
  String phase = 'idle',
  UpdateRelease? release,
  bool automatic = false,
  bool allowed = true,
  bool canInstall = true,
  String? error,
}) => UpdateStatus(
  installedVersionCode: 2,
  installedVersionName: '0.2.0',
  phase: phase,
  automaticChecksEnabled: automatic,
  notificationsAllowed: allowed,
  canInstallPackages: canInstall,
  downloadedBytes: 0,
  release: release,
  errorMessage: error,
);

class FakeUpdatesRepository implements UpdateRepository {
  FakeUpdatesRepository({UpdateStatus? initial})
    : status = initial ?? updateStatus();
  UpdateStatus status;
  int reads = 0,
      checks = 0,
      downloads = 0,
      installs = 0,
      permissionRequests = 0,
      settingsOpened = 0;
  bool failCheck = false, grantNotifications = true;
  Completer<UpdateStatus>? pendingDownload;
  @override
  Future<UpdateStatus> getStatus() async {
    reads++;
    return status;
  }

  @override
  Future<UpdateStatus> check() async {
    checks++;
    if (failCheck) throw Exception('Offline');
    status = updateStatus(
      phase: 'available',
      release: milestone(),
      automatic: status.automaticChecksEnabled,
      allowed: status.notificationsAllowed,
    );
    status.lastCheckedMillis = DateTime(2026, 11, 5).millisecondsSinceEpoch;
    return status;
  }

  @override
  Future<UpdateStatus> setAutomaticChecks(bool enabled) async {
    status.automaticChecksEnabled = enabled;
    return status;
  }

  @override
  Future<UpdateStatus> requestNotificationPermission() async {
    permissionRequests++;
    status.notificationsAllowed = grantNotifications;
    return status;
  }

  @override
  Future<void> openNotificationSettings() async {
    settingsOpened++;
  }

  @override
  Future<UpdateStatus> download() async {
    downloads++;
    status.phase = 'downloading';
    status.downloadedBytes = status.release!.sizeBytes ~/ 2;
    if (pendingDownload != null) return pendingDownload!.future;
    status.phase = 'ready';
    status.downloadedBytes = status.release!.sizeBytes;
    return status;
  }

  @override
  Future<UpdateStatus> cancelDownload() async {
    status.phase = 'available';
    status.errorMessage = 'Download canceled. No installation was started.';
    pendingDownload?.complete(status);
    return status;
  }

  @override
  Future<UpdateStatus> install() async {
    installs++;
    status.phase = status.canInstallPackages
        ? 'installerOpened'
        : 'installPermissionRequired';
    return status;
  }
}
