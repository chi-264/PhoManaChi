import '../platform/system_api.g.dart';

abstract interface class SystemRepository {
  Future<SystemSnapshot> readSnapshot();
}

class AndroidSystemRepository implements SystemRepository {
  AndroidSystemRepository({DeviceHostApi? api}) : _api = api ?? DeviceHostApi();
  final DeviceHostApi _api;

  @override
  Future<SystemSnapshot> readSnapshot() async {
    final snapshot = await _api.getSystemSnapshot();
    if (snapshot.contractVersion != 1) {
      throw StateError('Unsupported Android interface version.');
    }
    return snapshot;
  }
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) return 'Unavailable';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

int? estimatedUsedMemory(SystemSnapshot snapshot) {
  final total = snapshot.totalMemoryBytes;
  final available = snapshot.availableMemoryBytes;
  if (total == null ||
      available == null ||
      total < 0 ||
      available < 0 ||
      available > total) {
    return null;
  }
  return total - available;
}
