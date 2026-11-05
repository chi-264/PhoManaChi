import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/update_api.g.dart';
import 'update_repository.dart';

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => AndroidUpdateRepository(),
);
final updatesProvider = NotifierProvider<UpdatesController, UpdateViewState>(
  UpdatesController.new,
);

class UpdateViewState {
  const UpdateViewState({
    this.status,
    this.busy = false,
    this.initialLoading = true,
    this.operation,
    this.issue,
  });
  final UpdateStatus? status;
  final bool busy;
  final bool initialLoading;
  final String? operation;
  final String? issue;
}

class UpdatesController extends Notifier<UpdateViewState> {
  late UpdateRepository _repository;
  bool _disposed = false;
  bool _foreground = true;
  bool _polling = false;
  Timer? _progress;
  @override
  UpdateViewState build() {
    _repository = ref.watch(updateRepositoryProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _progress?.cancel();
    });
    Future.microtask(refresh);
    return const UpdateViewState();
  }

  Future<void> refresh() async {
    if (_disposed || state.busy) return;
    try {
      final status = await _repository.getStatus();
      if (!_disposed && !state.busy) {
        state = UpdateViewState(status: status, initialLoading: false);
      }
    } catch (_) {
      if (!_disposed && !state.busy) {
        state = UpdateViewState(
          status: state.status,
          initialLoading: false,
          issue: 'The Android update service is unavailable. Retry on your Android device.',
        );
      }
    }
  }

  Future<void> _perform(
    String operation,
    Future<UpdateStatus> Function() action,
  ) async {
    if (_disposed || state.busy) return;
    state = UpdateViewState(
      status: state.status,
      initialLoading: false,
      busy: true,
      operation: operation,
    );
    if (operation == 'download') _startProgress();
    try {
      final status = await action();
      if (!_disposed) {
        state = UpdateViewState(status: status, initialLoading: false);
      }
    } catch (_) {
      if (!_disposed) {
        state = UpdateViewState(
          status: state.status,
          initialLoading: false,
          issue: 'The update operation could not complete. Please retry.',
        );
      }
    } finally {
      _progress?.cancel();
    }
  }

  Future<void> check() => _perform('check', _repository.check);
  Future<void> setAutomaticChecks(bool enabled) =>
      _perform('preferences', () async {
        if (enabled) await _repository.requestNotificationPermission();
        return _repository.setAutomaticChecks(enabled);
      });
  Future<void> download() => _perform('download', _repository.download);
  Future<void> install() => _perform('install', _repository.install);

  Future<void> cancelDownload() async {
    if (_disposed || state.operation != 'download') return;
    state = UpdateViewState(
      status: state.status,
      initialLoading: false,
      busy: true,
      operation: 'cancel',
    );
    try {
      await _repository.cancelDownload();
    } catch (_) {
      if (!_disposed && state.busy && state.operation == 'cancel') {
        state = UpdateViewState(
          status: state.status,
          initialLoading: false,
          busy: true,
          operation: 'download',
          issue: 'Cancellation could not be requested. Please retry.',
        );
      }
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _repository.openNotificationSettings();
    } catch (_) {
      if (!_disposed) {
        state = UpdateViewState(
          status: state.status,
          initialLoading: false,
          issue: 'Android notification settings could not be opened.',
        );
      }
    }
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _progress?.cancel();
    } else if (state.busy && state.operation == 'download') {
      _startProgress();
    } else {
      unawaited(refresh());
    }
  }

  void _startProgress() {
    _progress?.cancel();
    if (!_foreground) return;
    _progress = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_disposed ||
          _polling ||
          !state.busy ||
          state.operation != 'download') {
        return;
      }
      _polling = true;
      try {
        final status = await _repository.getStatus();
        if (!_disposed && state.busy && state.operation == 'download') {
          state = UpdateViewState(
            status: status,
            initialLoading: false,
            busy: true,
            operation: 'download',
          );
        }
      } catch (_) {
        /* The awaited operation reports its own final result. */
      } finally {
        _polling = false;
      }
    });
  }
}
