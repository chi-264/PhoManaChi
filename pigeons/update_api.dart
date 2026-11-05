import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/update_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/dev/phomanachi/phomanachi/updates/UpdateApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.phomanachi.phomanachi.updates'),
  ),
)
class UpdateRelease {
  UpdateRelease({
    required this.versionCode,
    required this.versionName,
    required this.title,
    required this.notes,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.minSdk,
  });
  int versionCode;
  String versionName;
  String title;
  String notes;
  String apkUrl;
  String sha256;
  int sizeBytes;
  int minSdk;
}

class UpdateStatus {
  UpdateStatus({
    required this.installedVersionCode,
    required this.installedVersionName,
    required this.phase,
    required this.automaticChecksEnabled,
    required this.notificationsAllowed,
    required this.canInstallPackages,
    required this.downloadedBytes,
    this.lastCheckedMillis,
    this.release,
    this.errorMessage,
  });
  int installedVersionCode;
  String installedVersionName;
  String phase;
  bool automaticChecksEnabled;
  bool notificationsAllowed;
  bool canInstallPackages;
  int downloadedBytes;
  int? lastCheckedMillis;
  UpdateRelease? release;
  String? errorMessage;
}

@HostApi()
abstract class UpdateHostApi {
  @async
  UpdateStatus getStatus();
  @async
  UpdateStatus checkForUpdates();
  @async
  UpdateStatus setAutomaticChecks(bool enabled);
  @async
  UpdateStatus requestNotificationPermission();
  @async
  void openNotificationSettings();
  @async
  UpdateStatus downloadUpdate();
  @async
  UpdateStatus cancelDownload();
  @async
  UpdateStatus requestInstall();
}

@FlutterApi()
abstract class UpdateFlutterApi {
  void statusChanged();
  void openUpdates();
}
