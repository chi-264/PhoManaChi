import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/storage_api.g.dart';
import 'storage_repository.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => AndroidStorageRepository(),
);
final storageProvider = NotifierProvider<StorageController, StorageState>(
  StorageController.new,
);

class StorageState {
  const StorageState({
    this.snapshot,
    this.selected = const {},
    this.actionBusy = false,
    this.review,
    this.issue,
  });
  final StorageSnapshot? snapshot;
  final Set<String> selected;
  final bool actionBusy;
  final CleanupReview? review;
  final String? issue;
  bool get busy => actionBusy || (snapshot?.busy ?? false);
  bool get canSelect =>
      !busy &&
      review == null &&
      snapshot?.requiresRescan == false &&
      [ScanPhase.completed, ScanPhase.partial].contains(snapshot?.phase);
}

class StorageController extends Notifier<StorageState> {
  late StorageRepository _repository;
  Timer? _timer;
  bool _disposed = false, _foreground = true, _refreshing = false;
  int _generation = 0;
  @override
  StorageState build() {
    _repository = ref.watch(storageRepositoryProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _timer?.cancel();
    });
    Future.microtask(refresh);
    return const StorageState();
  }

  void _poll() {
    _timer?.cancel();
    if (!_disposed && _foreground && state.busy) {
      _timer = Timer(const Duration(seconds: 1), refresh);
    }
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      unawaited(refresh());
    } else {
      _timer?.cancel();
    }
  }

  void _accept(
    StorageSnapshot snapshot, {
    String? issue,
    bool actionBusy = false,
    CleanupReview? review,
  }) {
    final selected =
        snapshot.jobId == state.snapshot?.jobId && !snapshot.requiresRescan
        ? state.selected.intersection(snapshot.files.map((f) => f.id).toSet())
        : <String>{};
    state = StorageState(
      snapshot: snapshot,
      selected: selected,
      issue: issue,
      actionBusy: actionBusy,
      review: review,
    );
    _poll();
  }

  Future<void> refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    final generation = _generation;
    try {
      final snapshot = await _repository.getState();
      if (!_disposed && generation == _generation) {
        _accept(
          snapshot,
          issue: state.issue,
          actionBusy: state.actionBusy,
          review: state.review,
        );
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        state = StorageState(
          snapshot: state.snapshot,
          selected: state.selected,
          review: state.review,
          actionBusy: state.actionBusy,
          issue: 'Storage service unavailable. Refresh to reconnect; no deletion result is confirmed.',
        );
      }
    } finally {
      _refreshing = false;
      if (!_disposed) _poll();
    }
  }

  void select(String id, bool selected) {
    if (!state.canSelect ||
        !state.snapshot!.files.any((f) => f.id == id && f.deleteSupported)) {
      return;
    }
    state = StorageState(
      snapshot: state.snapshot,
      selected: {...state.selected}
        ..removeWhere((value) => value == id)
        ..addAll(selected ? [id] : []),
      issue: state.issue,
    );
  }

  void clearSelection() {
    if (!state.canSelect) return;
    state = StorageState(snapshot: state.snapshot);
  }

  Future<void> _perform(
    Future<StorageSnapshot> Function() action, {
    bool allowBusy = false,
  }) async {
    if (_disposed || (!allowBusy && (state.busy || state.review != null))) {
      return;
    }
    ++_generation;
    state = StorageState(
      snapshot: state.snapshot,
      selected: state.selected,
      actionBusy: true,
    );
    _poll();
    try {
      final value = await action();
      if (!_disposed) _accept(value);
    } catch (_) {
      if (!_disposed) {
        state = StorageState(
          snapshot: state.snapshot,
          selected: state.selected,
          issue: 'Android could not complete this request. Access or files may have changed. Refresh or rescan before retrying.',
        );
        await refresh();
      }
    }
  }

  Future<void> chooseFolder() => _perform(_repository.chooseFolder);
  Future<void> chooseFiles() => _perform(_repository.chooseFiles);
  Future<void> scanMedia() => _perform(_repository.scanMedia);
  Future<void> rescan() => _perform(_repository.rescan);
  Future<void> forget() => _perform(_repository.forgetScan);
  Future<void> cancel() async {
    // Cancellation can run while a proof hash or Android picker is pending.
    try {
      await _repository.cancelOperation();
    } catch (_) {
      /* Refresh exposes service failures. */
    }
    await refresh();
  }

  Future<void> prepare() async {
    if (!state.canSelect ||
        selectionIssue(state.snapshot!.files, state.selected) != null) {
      return;
    }
    final job = state.snapshot!.jobId;
    if (job == null) return;
    final selected = state.selected;
    ++_generation;
    state = StorageState(
      snapshot: state.snapshot,
      selected: selected,
      actionBusy: true,
    );
    _poll();
    try {
      final review = await _repository.prepareCleanup(job, selected.toList());
      if (!_disposed) {
        state = StorageState(
          snapshot: state.snapshot,
          selected: selected,
          review: review,
        );
      }
    } catch (_) {
      if (!_disposed) {
        state = StorageState(
          snapshot: state.snapshot,
          selected: selected,
          issue: 'Review could not be prepared. A file or retained copy may have changed, or access was lost. Rescan and choose files again.',
        );
      }
    } finally {
      if (!_disposed) {
        await refresh();
        _poll();
      }
    }
  }

  Future<void> discard() async {
    final review = state.review;
    if (review == null || state.busy) return;
    await _perform(
      () => _repository.discardReview(review.reviewId),
      allowBusy: true,
    );
  }

  Future<void> confirm() async {
    final review = state.review;
    if (review == null || state.busy) return;
    // The native token is single-use. Never retry a deletion automatically.
    await _perform(
      () => _repository.confirmCleanup(review.reviewId),
      allowBusy: true,
    );
  }
}
