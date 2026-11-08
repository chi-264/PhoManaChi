import '../../core/platform/storage_api.g.dart';

abstract interface class StorageRepository {
  Future<StorageSnapshot> getState();
  Future<StorageSnapshot> chooseFolder();
  Future<StorageSnapshot> chooseFiles();
  Future<StorageSnapshot> scanMedia();
  Future<StorageSnapshot> rescan();
  Future<StorageSnapshot> cancelOperation();
  Future<CleanupReview> prepareCleanup(String jobId, List<String> fileIds);
  Future<StorageSnapshot> discardReview(String reviewId);
  Future<StorageSnapshot> confirmCleanup(String reviewId);
  Future<StorageSnapshot> forgetScan();
}

class AndroidStorageRepository implements StorageRepository {
  AndroidStorageRepository({StorageHostApi? api})
    : _api = api ?? StorageHostApi();
  final StorageHostApi _api;
  @override
  Future<StorageSnapshot> getState() async {
    final value = await _api.getState();
    if (value.contractVersion != 1) {
      throw StateError('Unsupported storage interface.');
    }
    return value;
  }

  @override
  Future<StorageSnapshot> chooseFolder() => _api.chooseFolder();
  @override
  Future<StorageSnapshot> chooseFiles() => _api.chooseFiles();
  @override
  Future<StorageSnapshot> scanMedia() => _api.scanMedia();
  @override
  Future<StorageSnapshot> rescan() => _api.rescan();
  @override
  Future<StorageSnapshot> cancelOperation() => _api.cancelOperation();
  @override
  Future<CleanupReview> prepareCleanup(String jobId, List<String> fileIds) =>
      _api.prepareCleanup(jobId, fileIds);
  @override
  Future<StorageSnapshot> discardReview(String reviewId) =>
      _api.discardReview(reviewId);
  @override
  Future<StorageSnapshot> confirmCleanup(String reviewId) =>
      _api.confirmCleanup(reviewId);
  @override
  Future<StorageSnapshot> forgetScan() => _api.forgetScan();
}

enum FileSort { largest, name, newest }

const largeFileBytes = 100 * 1024 * 1024;
const fileCategories = [
  'All',
  'Images',
  'Videos',
  'Audio',
  'Documents',
  'Archives',
  'APKs',
  'Other',
];

List<StorageFile> filterFiles(
  List<StorageFile> files, {
  String query = '',
  String category = 'All',
  bool largeOnly = false,
  bool duplicatesOnly = false,
  FileSort sort = FileSort.largest,
}) {
  final search = query.trim().toLowerCase();
  final result = files
      .where(
        (f) =>
            (category == 'All' || f.category == category) &&
            (!largeOnly || (f.sizeBytes ?? -1) >= largeFileBytes) &&
            (!duplicatesOnly || f.duplicateGroup != null) &&
            (f.name.toLowerCase().contains(search) ||
                f.location.toLowerCase().contains(search)),
      )
      .toList();
  result.sort((a, b) {
    final order = switch (sort) {
      FileSort.largest => (b.sizeBytes ?? -1).compareTo(a.sizeBytes ?? -1),
      FileSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      FileSort.newest => (b.modifiedMillis ?? -1).compareTo(
        a.modifiedMillis ?? -1,
      ),
    };
    return order != 0 ? order : a.id.compareTo(b.id);
  });
  return result;
}

String? selectionIssue(List<StorageFile> files, Set<String> selected) {
  if (selected.isEmpty) return 'Select individual files to review.';
  if (selected.length > 100) return 'Review at most 100 files at a time.';
  final known = {for (final file in files) file.id: file};
  if (selected.any((id) => known[id]?.deleteSupported != true)) {
    return 'Some selected files are no longer eligible. Rescan first.';
  }
  final groups = <String, List<StorageFile>>{};
  for (final file in files) {
    if (file.duplicateGroup case final String group) {
      groups.putIfAbsent(group, () => []).add(file);
    }
  }
  for (final group in groups.values) {
    if (group.every((f) => selected.contains(f.id))) {
      return 'Keep at least one unselected copy in each duplicate group.';
    }
  }
  return null;
}
