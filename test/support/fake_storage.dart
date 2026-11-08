import 'dart:async';

import 'package:phomanachi/core/platform/storage_api.g.dart';
import 'package:phomanachi/features/storage/storage_repository.dart';

StorageFile storageFile(
  String id, {
  String? group,
  int? size = 4096,
  bool supported = true,
  String category = 'Documents',
}) => StorageFile(
  id: id,
  name: '$id.txt',
  mimeType: 'text/plain',
  category: category,
  location: 'Selected folder / Documents',
  sizeBytes: size,
  modifiedMillis: 1794020400000,
  deleteSupported: supported,
  deleteReason: supported ? 'Rechecked before deletion' : 'Read-only provider',
  duplicateGroup: group,
);
StorageSnapshot storageSnapshot({
  List<StorageFile> files = const [],
  String? job = 'job-1',
  ScanPhase phase = ScanPhase.completed,
  bool busy = false,
  bool requiresRescan = false,
  CleanupReport? cleanup,
  String? message,
}) => StorageSnapshot(
  contractVersion: 1,
  jobId: job,
  phase: phase,
  scopeLabel: 'Selected folder',
  observedAtMillis: 1794020400000,
  files: files,
  hashedFiles: files.where((f) => f.duplicateGroup != null).length,
  failedFiles: 0,
  warningCount: 0,
  issues: [],
  busy: busy,
  requiresRescan: requiresRescan,
  cleanup: cleanup,
  message: message,
);
CleanupReport cleanupReport() => CleanupReport(
  operationId: 'operation-1',
  startedAtMillis: 1794020400000,
  phase: CleanupPhase.partial,
  requested: 3,
  deleted: 1,
  skipped: 1,
  failed: 0,
  unverified: 1,
  deletedBytes: 4096,
  internalFreeBefore: 8192,
  internalFreeAfter: 7168,
  message: 'Only verified deletions count.',
  items: [
    CleanupItem(
      fileId: 'deleted',
      name: 'deleted.txt',
      outcome: 'deleted',
      message: 'Provider confirmed absence.',
    ),
    CleanupItem(
      fileId: 'changed',
      name: 'changed.txt',
      outcome: 'skipped',
      message: 'Content changed.',
    ),
    CleanupItem(
      fileId: 'unknown',
      name: 'unknown.txt',
      outcome: 'unverified',
      message: 'Access lost after request.',
    ),
  ],
);

class FakeStorageRepository implements StorageRepository {
  FakeStorageRepository({StorageSnapshot? initial})
    : current = initial ?? storageSnapshot(job: null, phase: ScanPhase.idle);
  StorageSnapshot current;
  int reads = 0,
      folders = 0,
      files = 0,
      media = 0,
      rescans = 0,
      canceled = 0,
      prepared = 0,
      confirmed = 0,
      discarded = 0;
  bool failReads = false, failPrepare = false;
  Completer<CleanupReview>? pendingReview;
  @override
  Future<StorageSnapshot> getState() async {
    reads++;
    if (failReads) throw StateError('Disconnected');
    return current;
  }

  @override
  Future<StorageSnapshot> chooseFolder() async {
    folders++;
    return current;
  }

  @override
  Future<StorageSnapshot> chooseFiles() async {
    files++;
    return current;
  }

  @override
  Future<StorageSnapshot> scanMedia() async {
    media++;
    return current;
  }

  @override
  Future<StorageSnapshot> rescan() async {
    rescans++;
    return current;
  }

  @override
  Future<StorageSnapshot> cancelOperation() async {
    canceled++;
    current = storageSnapshot(files: current.files, phase: ScanPhase.canceled);
    return current;
  }

  @override
  Future<CleanupReview> prepareCleanup(
    String jobId,
    List<String> fileIds,
  ) async {
    prepared++;
    if (failPrepare) throw StateError('File changed');
    if (pendingReview != null) return pendingReview!.future;
    return CleanupReview(
      reviewId: 'review-1',
      jobId: jobId,
      expiresAtMillis: 1794021000000,
      files: current.files.where((f) => fileIds.contains(f.id)).toList(),
      totalBytes: current.files
          .where((f) => fileIds.contains(f.id))
          .fold(0, (s, f) => s + (f.sizeBytes ?? 0)),
    );
  }

  @override
  Future<StorageSnapshot> discardReview(String reviewId) async {
    discarded++;
    return current;
  }

  @override
  Future<StorageSnapshot> confirmCleanup(String reviewId) async {
    confirmed++;
    current = storageSnapshot(
      files: current.files,
      requiresRescan: true,
      cleanup: cleanupReport(),
    );
    return current;
  }

  @override
  Future<StorageSnapshot> forgetScan() async {
    current = storageSnapshot(job: null, phase: ScanPhase.idle);
    return current;
  }
}
