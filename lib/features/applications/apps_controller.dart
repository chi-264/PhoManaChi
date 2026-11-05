import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/apps_api.g.dart';
import 'apps_repository.dart';

final appsRepositoryProvider = Provider<AppsRepository>(
  (ref) => AndroidAppsRepository(),
);
final appInventoryProvider = FutureProvider<ApplicationInventory>(
  (ref) => ref.watch(appsRepositoryProvider).getInventory(),
);
final appDetailsProvider = FutureProvider.autoDispose
    .family<ApplicationDetails?, String>(
      (ref, packageName) =>
          ref.watch(appsRepositoryProvider).getDetails(packageName),
    );
final capabilitiesProvider = FutureProvider.autoDispose<CapabilitySnapshot>(
  (ref) => ref.watch(appsRepositoryProvider).getCapabilities(),
);
final appActionsProvider =
    NotifierProvider<AppActionsController, AppActionState>(
      AppActionsController.new,
    );

class AppActionState {
  const AppActionState({this.result, this.busy = false, this.issue});
  final AppActionResult? result;
  final bool busy;
  final String? issue;
}

class AppActionsController extends Notifier<AppActionState> {
  late AppsRepository _repository;
  bool _disposed = false;
  int _generation = 0;
  @override
  AppActionState build() {
    _repository = ref.watch(appsRepositoryProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    Future.microtask(refresh);
    return const AppActionState();
  }

  Future<void> refresh() async {
    if (_disposed || state.busy) return;
    final generation = ++_generation;
    try {
      final value = await _repository.getLastAction();
      if (!_disposed && generation == _generation && !state.busy) {
        state = AppActionState(result: value);
      }
    } catch (_) {
      // Inventory/capability readers expose Android service errors with a retry.
      // An absent last-action channel must not manufacture an operation result.
    }
  }

  Future<void> _perform(Future<AppActionResult> Function() action) async {
    if (_disposed || state.busy) return;
    ++_generation;
    state = AppActionState(result: state.result, busy: true);
    try {
      final value = await action();
      if (!_disposed) {
        state = AppActionState(result: value);
        ref.invalidate(appInventoryProvider);
        ref.invalidate(appDetailsProvider);
        ref.invalidate(capabilitiesProvider);
        if (value.phase == AppActionPhase.requested) unawaited(refresh());
      }
    } catch (_) {
      if (!_disposed) {
        state = AppActionState(
          result: state.result,
          issue: 'Android could not complete this request. Refresh and retry; no result has been confirmed.',
        );
      }
    }
  }

  Future<void> settings(String packageName) =>
      _perform(() => _repository.openAppSettings(packageName));
  Future<void> uninstall(ApplicationRecord app) =>
      _perform(() => _repository.requestUninstall(app));
  Future<void> accessSettings(String id) =>
      _perform(() => _repository.openAccessSettings(id));
  Future<void> dismiss() async {
    if (state.busy) return;
    ++_generation;
    state = AppActionState(result: state.result, busy: true);
    try {
      await _repository.clearLastAction();
      if (!_disposed) state = const AppActionState();
    } catch (_) {
      if (!_disposed) {
        state = AppActionState(
          result: state.result,
          issue: 'Could not dismiss this result. Please retry.',
        );
      }
    }
  }
}
