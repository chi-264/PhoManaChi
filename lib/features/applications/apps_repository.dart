import '../../core/platform/apps_api.g.dart';

abstract interface class AppsRepository {
  Future<ApplicationInventory> getInventory();
  Future<ApplicationDetails?> getDetails(String packageName);
  Future<CapabilitySnapshot> getCapabilities();
  Future<AppActionResult> openAppSettings(String packageName);
  Future<AppActionResult> requestUninstall(ApplicationRecord app);
  Future<AppActionResult?> getLastAction();
  Future<void> clearLastAction();
  Future<AppActionResult> openAccessSettings(String capabilityId);
}

class AndroidAppsRepository implements AppsRepository {
  AndroidAppsRepository({AppsHostApi? api}) : _api = api ?? AppsHostApi();
  final AppsHostApi _api;
  @override
  Future<ApplicationInventory> getInventory() async {
    final value = await _api.getInventory();
    if (value.contractVersion != 1) {
      throw StateError('Unsupported apps interface.');
    }
    return value;
  }

  @override
  Future<ApplicationDetails?> getDetails(String packageName) =>
      _api.getDetails(packageName);
  @override
  Future<CapabilitySnapshot> getCapabilities() async {
    final value = await _api.getCapabilities();
    if (value.contractVersion != 1) {
      throw StateError('Unsupported capabilities interface.');
    }
    return value;
  }

  @override
  Future<AppActionResult> openAppSettings(String packageName) =>
      _api.openAppSettings(packageName);
  @override
  Future<AppActionResult> requestUninstall(ApplicationRecord app) =>
      _api.requestUninstall(
        app.packageName,
        app.versionCode,
        app.lastUpdatedMillis,
      );
  @override
  Future<AppActionResult?> getLastAction() => _api.getLastAction();
  @override
  Future<void> clearLastAction() => _api.clearLastAction();
  @override
  Future<AppActionResult> openAccessSettings(String capabilityId) =>
      _api.openAccessSettings(capabilityId);
}

enum AppFilter { all, user, system }

enum AppSort { name, updated, packageName }

List<ApplicationRecord> filterApplications(
  List<ApplicationRecord> apps, {
  String query = '',
  AppFilter filter = AppFilter.all,
  AppSort sort = AppSort.name,
}) {
  final search = query.trim().toLowerCase();
  final result = apps
      .where(
        (app) =>
            (filter == AppFilter.all ||
                (filter == AppFilter.system) == app.systemApp) &&
            (app.label.toLowerCase().contains(search) ||
                app.packageName.toLowerCase().contains(search)),
      )
      .toList();
  result.sort((a, b) {
    final comparison = switch (sort) {
      AppSort.name => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      AppSort.updated => b.lastUpdatedMillis.compareTo(a.lastUpdatedMillis),
      AppSort.packageName => a.packageName.compareTo(b.packageName),
    };
    return comparison != 0
        ? comparison
        : a.packageName.compareTo(b.packageName);
  });
  return result;
}

AppCapability? capability(List<AppCapability> values, String id) {
  for (final value in values) {
    if (value.id == id) return value;
  }
  return null;
}
