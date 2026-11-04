import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/system_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/dev/phomanachi/phomanachi/platform/SystemApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.phomanachi.phomanachi.platform'),
  ),
)
class SystemSnapshot {
  SystemSnapshot({
    required this.contractVersion,
    required this.observedAtMillis,
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.apiLevel,
    required this.buildId,
    this.totalMemoryBytes,
    this.availableMemoryBytes,
    this.lowMemory,
    this.totalStorageBytes,
    this.availableStorageBytes,
    this.batteryPercent,
    this.batteryState,
    this.powerSource,
    this.temperatureCelsius,
    this.voltageMillivolts,
    this.batteryHealth,
    required this.notices,
  });
  int contractVersion;
  int observedAtMillis;
  String manufacturer;
  String model;
  String androidVersion;
  int apiLevel;
  String buildId;
  int? totalMemoryBytes;
  int? availableMemoryBytes;
  bool? lowMemory;
  int? totalStorageBytes;
  int? availableStorageBytes;
  double? batteryPercent;
  String? batteryState;
  String? powerSource;
  double? temperatureCelsius;
  int? voltageMillivolts;
  String? batteryHealth;
  List<String> notices;
}

@HostApi()
abstract class DeviceHostApi {
  @async
  SystemSnapshot getSystemSnapshot();
}
