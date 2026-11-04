import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/system_api.g.dart';

final systemRepositoryProvider = Provider<SystemRepository>(
  (ref) => AndroidSystemRepository(),
);
final snapshotProvider = FutureProvider<SystemSnapshot>(
  (ref) => ref.watch(systemRepositoryProvider).readSnapshot(),
);
