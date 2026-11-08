import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/platform/storage_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/dev/phomanachi/phomanachi/storage/StorageApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'dev.phomanachi.phomanachi.storage'),
))
enum ScanPhase { idle, choosing, scanning, hashing, completed, partial, canceled, failed }
enum CleanupPhase { idle, preparing, awaitingAuthorization, deleting, completed, partial, canceled, interrupted, failed }

class StorageFile {
  StorageFile({required this.id, required this.name, required this.mimeType,
    required this.category, required this.location, this.sizeBytes, this.modifiedMillis,
    required this.deleteSupported, required this.deleteReason, this.duplicateGroup});
  String id;
  String name;
  String mimeType;
  String category;
  String location;
  int? sizeBytes;
  int? modifiedMillis;
  bool deleteSupported;
  String deleteReason;
  String? duplicateGroup;
}

class CleanupItem {
  CleanupItem({required this.fileId, required this.name, required this.outcome, required this.message});
  String fileId;
  String name;
  String outcome;
  String message;
}

class CleanupReport {
  CleanupReport({required this.operationId, required this.startedAtMillis, required this.phase, required this.requested,
    required this.deleted, required this.skipped, required this.failed, required this.unverified,
    required this.deletedBytes, this.internalFreeBefore, this.internalFreeAfter,
    required this.items, required this.message});
  String operationId;
  int startedAtMillis;
  CleanupPhase phase;
  int requested;
  int deleted;
  int skipped;
  int failed;
  int unverified;
  int deletedBytes;
  int? internalFreeBefore;
  int? internalFreeAfter;
  List<CleanupItem> items;
  String message;
}

class CleanupReview {
  CleanupReview({required this.reviewId, required this.jobId, required this.expiresAtMillis,
    required this.files, required this.totalBytes});
  String reviewId;
  String jobId;
  int expiresAtMillis;
  List<StorageFile> files;
  int totalBytes;
}

class StorageSnapshot {
  StorageSnapshot({required this.contractVersion, this.jobId, required this.phase,
    required this.scopeLabel, required this.observedAtMillis, required this.files,
    required this.hashedFiles, required this.failedFiles, required this.warningCount,
    required this.issues, this.message, required this.busy, required this.requiresRescan, this.cleanup});
  int contractVersion;
  String? jobId;
  ScanPhase phase;
  String scopeLabel;
  int observedAtMillis;
  List<StorageFile> files;
  int hashedFiles;
  int failedFiles;
  int warningCount;
  List<String> issues;
  String? message;
  bool busy;
  bool requiresRescan;
  CleanupReport? cleanup;
}

@HostApi()
abstract class StorageHostApi {
  @async
  StorageSnapshot getState();
  @async
  StorageSnapshot chooseFolder();
  @async
  StorageSnapshot chooseFiles();
  @async
  StorageSnapshot scanMedia();
  @async
  StorageSnapshot rescan();
  @async
  StorageSnapshot cancelOperation();
  @async
  CleanupReview prepareCleanup(String jobId, List<String> fileIds);
  @async
  StorageSnapshot discardReview(String reviewId);
  @async
  StorageSnapshot confirmCleanup(String reviewId);
  @async
  StorageSnapshot forgetScan();
}

@FlutterApi()
abstract class StorageFlutterApi {
  void stateChanged();
}
