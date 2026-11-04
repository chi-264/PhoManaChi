import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/system_api.g.dart';
import 'providers.dart';

class ResourceScreen extends ConsumerWidget {
  const ResourceScreen({super.key, required this.kind, required this.title});
  final String kind;
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snapshotProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Refresh readings',
              onPressed: state.isLoading
                  ? null
                  : () => ref.invalidate(snapshotProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...state.when(
          loading: () => [
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Reading device information',
              ),
            ),
          ],
          error: (_, _) => [
            const Notice(
              'Device readings unavailable',
              'Android did not return a system snapshot. Refresh to retry. Other screens remain accessible.',
            ),
          ],
          data: (data) => _content(context, data),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, SystemSnapshot s) {
    final memory = [
      Metric('Available RAM', formatBytes(s.availableMemoryBytes)),
      Metric('Physical RAM', formatBytes(s.totalMemoryBytes)),
      Metric('Estimated used RAM', formatBytes(estimatedUsedMemory(s))),
      Metric(
        'Low-memory status',
        s.lowMemory == null
            ? 'Unavailable'
            : s.lowMemory!
            ? 'Low memory'
            : 'Not low',
      ),
    ];
    final storage = [
      Metric(
        'Available internal storage',
        formatBytes(s.availableStorageBytes),
      ),
      Metric('Total internal storage', formatBytes(s.totalStorageBytes)),
    ];
    final battery = [
      Metric(
        'Battery level',
        s.batteryPercent == null
            ? 'Unavailable'
            : '${s.batteryPercent!.toStringAsFixed(0)}%',
      ),
      Metric('Charging state', s.batteryState ?? 'Unavailable'),
    ];
    return [
      if (kind == '/dashboard' || kind == '/diagnostics') ...[
        Notice(
          '${s.manufacturer} ${s.model}',
          'Android ${s.androidVersion} • API ${s.apiLevel}\nBuild ${s.buildId}',
        ),
      ],
      if (kind == '/dashboard' || kind == '/processes') ...memory,
      if (kind == '/dashboard' || kind == '/storage') ...storage,
      if (kind == '/dashboard' || kind == '/battery') ...battery,
      if (kind == '/battery') ...[
        Metric('Power source', s.powerSource ?? 'Unavailable'),
        Metric(
          'Temperature',
          s.temperatureCelsius == null
              ? 'Unavailable'
              : '${s.temperatureCelsius!.toStringAsFixed(1)} °C',
        ),
        Metric(
          'Voltage',
          s.voltageMillivolts == null
              ? 'Unavailable'
              : '${s.voltageMillivolts} mV',
        ),
        Metric('System health state', s.batteryHealth ?? 'Unavailable'),
      ],
      if (kind == '/processes')
        const Notice(
          'Standard Mode',
          'Estimated used RAM is total minus available memory, not a sum of app usage. Detailed process inspection and controls are not implemented in this foundation. Installed apps are never treated as running processes.',
        ),
      if (kind == '/storage')
        const Notice(
          'Storage scanning planned',
          'This screen currently reports internal storage capacity. File selection, MediaStore/SAF access, duplicate detection, and confirmed deletion will be implemented in the storage milestone.',
        ),
      if (kind == '/applications')
        const Notice(
          'Application inventory planned',
          'Visible-package inventory and supported settings/uninstall flows will be implemented in the next milestone.',
        ),
      if (kind == '/manufacturer')
        Notice(
          'Device: ${s.manufacturer}',
          'No manufacturer activity profiles have been validated yet. Realme and TECNO integration requires testing on the target firmware.',
        ),
      if (kind == '/advanced')
        const Notice(
          'Advanced access not enabled',
          'Shizuku integration is planned after the MVP. Standard monitoring works without elevated authorization.',
        ),
      if (kind == '/permissions')
        const Notice(
          'No optional access requested',
          'Basic memory, battery, and storage-capacity readings use standard Android APIs. File and usage permissions will be requested only when their features are implemented.',
        ),
      if (kind == '/diagnostics') ...[
        Metric('Platform contract', 'v${s.contractVersion}'),
        const Notice(
          'Validation pending',
          'Physical-device tests are required on Realme 5i and TECNO Spark 30 5G. No manufacturer cleanup or advanced process operation is currently enabled.',
        ),
      ],
      for (final notice in s.notices) Notice('Reading unavailable', notice),
      const SizedBox(height: 12),
      Text(
        'Observed: ${DateTime.fromMillisecondsSinceEpoch(s.observedAtMillis).toLocal()}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.title, this.message, {super.key});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  );
}
