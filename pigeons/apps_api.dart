import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/apps_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/dev/phomanachi/phomanachi/apps/AppsApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.phomanachi.phomanachi.apps'),
  ),
)
enum AccessState {
  available,
  permissionRequired,
  restricted,
  unsupported,
  unavailable,
}

enum AppActionPhase {
  opened,
  requested,
  canceled,
  verifiedRemoved,
  unverified,
  blocked,
  failed,
}

class AppCapability {
  AppCapability({
    required this.id,
    required this.title,
    required this.state,
    required this.reason,
  });
  String id;
  String title;
  AccessState state;
  String reason;
}

class CapabilitySnapshot {
  CapabilitySnapshot({
    required this.contractVersion,
    required this.checkedAtMillis,
    required this.capabilities,
  });
  int contractVersion;
  int checkedAtMillis;
  List<AppCapability> capabilities;
}

class ApplicationRecord {
  ApplicationRecord({
    required this.packageName,
    required this.label,
    this.versionName,
    required this.versionCode,
    required this.systemApp,
    required this.enabled,
    required this.firstInstalledMillis,
    required this.lastUpdatedMillis,
  });
  String packageName;
  String label;
  String? versionName;
  int versionCode;
  bool systemApp;
  bool enabled;
  int firstInstalledMillis;
  int lastUpdatedMillis;
}

class ApplicationInventory {
  ApplicationInventory({
    required this.contractVersion,
    required this.observedAtMillis,
    required this.apps,
    required this.notices,
  });
  int contractVersion;
  int observedAtMillis;
  List<ApplicationRecord> apps;
  List<String> notices;
}

class AppPermission {
  AppPermission({
    required this.name,
    required this.label,
    required this.granted,
  });
  String name;
  String label;
  bool granted;
}

class ApplicationDetails {
  ApplicationDetails({
    required this.app,
    required this.checkedAtMillis,
    required this.uid,
    required this.targetSdk,
    this.installerPackage,
    this.apkBytes,
    required this.permissions,
    required this.capabilities,
  });
  ApplicationRecord app;
  int checkedAtMillis;
  int uid;
  int targetSdk;
  String? installerPackage;
  int? apkBytes;
  List<AppPermission> permissions;
  List<AppCapability> capabilities;
}

class AppActionResult {
  AppActionResult({
    required this.packageName,
    required this.phase,
    required this.message,
    required this.checkedAtMillis,
  });
  String packageName;
  AppActionPhase phase;
  String message;
  int checkedAtMillis;
}

@HostApi()
abstract class AppsHostApi {
  @async
  ApplicationInventory getInventory();
  @async
  ApplicationDetails? getDetails(String packageName);
  @async
  CapabilitySnapshot getCapabilities();
  @async
  AppActionResult openAppSettings(String packageName);
  @async
  AppActionResult requestUninstall(
    String packageName,
    int expectedVersionCode,
    int expectedUpdatedMillis,
  );
  @async
  AppActionResult? getLastAction();
  @async
  void clearLastAction();
  @async
  AppActionResult openAccessSettings(String capabilityId);
}

@FlutterApi()
abstract class AppsFlutterApi {
  void actionChanged();
}
