import '../../core/platform/update_api.g.dart';

abstract interface class UpdateRepository {
  Future<UpdateStatus> getStatus();
  Future<UpdateStatus> check();
  Future<UpdateStatus> setAutomaticChecks(bool enabled);
  Future<UpdateStatus> requestNotificationPermission();
  Future<void> openNotificationSettings();
  Future<UpdateStatus> download();
  Future<UpdateStatus> cancelDownload();
  Future<UpdateStatus> install();
}

class AndroidUpdateRepository implements UpdateRepository {
  AndroidUpdateRepository({UpdateHostApi? api}) : _api = api ?? UpdateHostApi();
  final UpdateHostApi _api;
  @override
  Future<UpdateStatus> getStatus() => _api.getStatus();
  @override
  Future<UpdateStatus> check() => _api.checkForUpdates();
  @override
  Future<UpdateStatus> setAutomaticChecks(bool enabled) =>
      _api.setAutomaticChecks(enabled);
  @override
  Future<UpdateStatus> requestNotificationPermission() =>
      _api.requestNotificationPermission();
  @override
  Future<void> openNotificationSettings() => _api.openNotificationSettings();
  @override
  Future<UpdateStatus> download() => _api.downloadUpdate();
  @override
  Future<UpdateStatus> cancelDownload() => _api.cancelDownload();
  @override
  Future<UpdateStatus> install() => _api.requestInstall();
}

bool hasNewerRelease(UpdateStatus? status) =>
    status != null &&
    status.release != null &&
    status.release!.versionCode > status.installedVersionCode;
