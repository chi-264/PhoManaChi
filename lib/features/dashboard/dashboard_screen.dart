import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/system_api.g.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';
import 'providers.dart';

class ResourceScreen extends ConsumerWidget {
  const ResourceScreen({super.key, required this.kind, required this.title});
  final String kind;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsReadings = const [
      '/dashboard',
      '/processes',
      '/storage',
      '/battery',
      '/manufacturer',
      '/diagnostics',
    ].contains(kind);
    final state = needsReadings ? ref.watch(snapshotProvider) : null;
    return PageContent(
      children: [
        PageHeading(
          title: kind == '/dashboard' ? 'A clearer view of your phone.' : title,
          subtitle: _description,
          action: state == null
              ? null
              : IconButton(
                  tooltip: 'Refresh readings',
                  onPressed: state.isLoading
                      ? null
                      : () => ref.invalidate(snapshotProvider),
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ),
        if (state != null)
          ...state.when(
            skipLoadingOnRefresh: false,
            loading: () => [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        semanticsLabel: 'Reading device information',
                      ),
                      SizedBox(height: 16),
                      Text('Reading your device…'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            error: (_, _) => [
              InfoNotice(
                'Device readings unavailable',
                'Android did not return a system snapshot. You can retry while continuing to use navigation and settings.',
                accent: Accent.warning,
                action: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(snapshotProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry readings'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            data: (snapshot) => _readings(context, snapshot),
          ),
        ..._featureContent(context),
      ],
    );
  }

  String get _description => switch (kind) {
    '/dashboard' => 'Your device information and everyday tools, in one place.',
    '/processes' =>
      'Understand your memory. See which information is available.',
    '/storage' => 'Know your storage before deciding what to remove.',
    '/applications' => 'Your applications and the actions Android allows.',
    '/battery' => 'A clear picture of power and charging.',
    '/manufacturer' => 'The built-in tools available on your phone.',
    '/diagnostics' => 'Readings, data sources, and implementation status.',
    '/permissions' => 'Access only when a feature needs it.',
    '/advanced' => 'Optional access. Always in your control.',
    _ => 'Review the information available in this build.',
  };

  List<Widget> _readings(BuildContext context, SystemSnapshot s) {
    final total = formatBytes(s.totalMemoryBytes);
    final available = formatBytes(s.availableMemoryBytes);
    final storageUsed = formatBytes(usedStorageBytes(s));
    final battery = validBatteryPercent(s);
    final memoryCard = ResourceMetricCard(
      label: 'Available RAM',
      value: available,
      detail: 'Physical RAM · $total total',
      icon: Icons.memory_rounded,
      progress: usedFraction(s.totalMemoryBytes, s.availableMemoryBytes),
      footnote: 'Bar shows estimated used RAM.',
    );
    final storageCard = ResourceMetricCard(
      label: 'Used internal storage',
      value: storageUsed,
      detail: '${formatBytes(s.availableStorageBytes)} available',
      icon: Icons.storage_rounded,
      accent: Accent.purple,
      progress: usedFraction(s.totalStorageBytes, s.availableStorageBytes),
      footnote: '${formatBytes(s.totalStorageBytes)} total',
    );
    final batteryCard = ResourceMetricCard(
      label: 'Battery level',
      value: battery == null ? 'Unavailable' : '${battery.toStringAsFixed(0)}%',
      detail: s.batteryState ?? 'Charging state unavailable',
      icon: Icons.battery_std_rounded,
      accent: Accent.mint,
      progress: battery == null ? null : battery / 100,
      footnote: s.powerSource == null
          ? 'Power source unavailable'
          : 'Power source · ${s.powerSource}',
    );
    return [
      if (kind == '/dashboard') ...[
        DeviceSummaryCard(snapshot: s),
        const SectionHeading(
          'Resource overview',
          subtitle: 'Measurements from Android system APIs.',
        ),
        AdaptiveCards(children: [memoryCard, storageCard, batteryCard]),
      ],
      if (kind == '/processes') ...[
        const StatusBadge('Standard mode', icon: Icons.shield_outlined),
        const SizedBox(height: 16),
        AdaptiveCards(
          children: [
            memoryCard,
            ResourceMetricCard(
              label: 'Estimated used RAM',
              value: formatBytes(estimatedUsedMemory(s)),
              detail: 'Total physical RAM minus available RAM.',
              icon: Icons.data_usage_rounded,
              accent: Accent.purple,
            ),
            ResourceMetricCard(
              label: 'Physical RAM',
              value: total,
              detail: 'Virtual memory expansion is not included.',
              icon: Icons.memory_rounded,
              accent: Accent.mint,
            ),
          ],
        ),
        const SizedBox(height: 16),
        InfoNotice(
          'Low-memory status',
          s.lowMemory == null
              ? 'This reading is unavailable.'
              : s.lowMemory!
              ? 'Android reports low memory on this device.'
              : 'Android is not reporting a low-memory condition.',
          accent: s.lowMemory == true ? Accent.warning : Accent.mint,
        ),
      ],
      if (kind == '/storage')
        AdaptiveCards(
          maxColumns: 2,
          children: [
            storageCard,
            ResourceMetricCard(
              label: 'Available internal storage',
              value: formatBytes(s.availableStorageBytes),
              detail: 'Space available on the internal data volume.',
              icon: Icons.folder_open_rounded,
              accent: Accent.mint,
            ),
          ],
        ),
      if (kind == '/battery') ...[
        AdaptiveCards(
          children: [
            batteryCard,
            ResourceMetricCard(
              label: 'Temperature',
              value: s.temperatureCelsius == null
                  ? 'Unavailable'
                  : '${s.temperatureCelsius!.toStringAsFixed(1)} °C',
              detail: 'System-reported battery temperature.',
              icon: Icons.thermostat_rounded,
              accent: Accent.warning,
            ),
            ResourceMetricCard(
              label: 'Voltage',
              value: s.voltageMillivolts == null
                  ? 'Unavailable'
                  : '${s.voltageMillivolts} mV',
              detail: 'System-reported battery voltage.',
              icon: Icons.bolt_rounded,
              accent: Accent.purple,
            ),
          ],
        ),
        const SectionHeading('Power information'),
        DetailCard(
          rows: [
            ('Charging state', s.batteryState ?? 'Unavailable'),
            ('Power source', s.powerSource ?? 'Unavailable'),
            ('System health state', s.batteryHealth ?? 'Unavailable'),
          ],
        ),
      ],
      if (kind == '/manufacturer')
        DetailCard(
          rows: [
            ('Manufacturer', s.manufacturer),
            ('Model', s.model),
            ('Android version', '${s.androidVersion} · API ${s.apiLevel}'),
            ('Utility integration', 'Not validated for this device'),
          ],
        ),
      if (kind == '/diagnostics') ...[
        DeviceSummaryCard(snapshot: s),
        const SectionHeading('Reading sources'),
        DetailCard(
          rows: [
            ('Memory', 'Android ActivityManager'),
            ('Internal storage', 'Android StatFs · data volume'),
            ('Battery', 'Android battery broadcast'),
            ('Platform contract', 'v${s.contractVersion}'),
            ('Background polling', 'Off · manual and resume refresh'),
          ],
        ),
      ],
      for (final notice in s.notices) ...[
        const SizedBox(height: 16),
        InfoNotice('Reading unavailable', notice, accent: Accent.warning),
      ],
      const SizedBox(height: 16),
      Text(
        'Read at ${_observationTime(context, s.observedAtMillis)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _featureContent(BuildContext context) => switch (kind) {
    '/dashboard' => [
      const SectionHeading(
        'What would you like to do?',
        subtitle: 'Choose a tool to take a closer look.',
      ),
      AdaptiveCards(
        maxColumns: 4,
        children: [
          FeatureTile(
            title: 'Process Manager',
            subtitle: 'Review memory and process visibility.',
            icon: Icons.memory_rounded,
            onTap: () => context.go('/processes'),
          ),
          FeatureTile(
            title: 'Storage Cleaner',
            subtitle: 'Analyze files, compare duplicates, and review cleanup.',
            icon: Icons.folder_open_rounded,
            accent: Accent.purple,
            onTap: () => context.go('/storage'),
          ),
          FeatureTile(
            title: 'Application Manager',
            subtitle: 'Find apps, review access, and open supported controls.',
            icon: Icons.apps_rounded,
            accent: Accent.warning,
            onTap: () => context.go('/applications'),
          ),
          FeatureTile(
            title: 'Battery Monitor',
            subtitle: 'Understand power and charging.',
            icon: Icons.battery_std_rounded,
            accent: Accent.mint,
            onTap: () => context.go('/more/battery'),
          ),
        ],
      ),
      const SectionHeading('Built around your device'),
      const InfoNotice(
        'Your privacy comes first',
        'Core readings stay on your phone. No account, advertisements, or analytics are required.',
        accent: Accent.mint,
        icon: Icons.shield_outlined,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => context.go('/more/diagnostics'),
        icon: const Icon(Icons.info_outline),
        label: const Text('View device diagnostics'),
      ),
    ],
    '/processes' => [
      const SectionHeading('Process information'),
      const UnavailableFeature(
        title: 'Detailed process inspection is not implemented',
        message: 'Android restricts access to other apps’ processes. This build does not list processes or offer force-stop actions. Installed and recently used apps are not treated as running processes.',
        icon: Icons.memory_rounded,
      ),
      const SizedBox(height: 16),
      const InfoNotice(
        'About memory readings',
        'Estimated used RAM is a system-level calculation, not a sum of individual app usage. Available RAM alone does not measure device performance.',
      ),
    ],
    '/battery' => [
      const SizedBox(height: 24),
      const InfoNotice(
        'System health is a category',
        'Android’s health state does not represent a measured capacity percentage or remaining battery lifespan. No repair or calibration operation is offered.',
        accent: Accent.mint,
      ),
    ],
    '/manufacturer' => [
      const SectionHeading('Manufacturer utility'),
      const UnavailableFeature(
        title: 'Integration requires device validation',
        message: 'Realme Process Manager and TECNO Phone Master profiles need testing on the installed firmware before direct launch can be enabled.',
        icon: Icons.build_outlined,
      ),
      const SizedBox(height: 16),
      const InfoNotice(
        'Use your phone’s built-in tools',
        'Open your phone’s Settings and look for its device-management utility. Opening a utility does not confirm that a cleanup happened.',
      ),
    ],
    '/diagnostics' => [
      const SectionHeading('Implementation status'),
      const DetailCard(
        rows: [
          ('File analysis', 'Choose scope and access in Storage'),
          ('Application inventory', 'Visible apps · current Android profile'),
          ('Detailed process inspection', 'Not implemented'),
          ('Manufacturer profiles', 'Not validated'),
          ('Advanced access', 'Not implemented'),
        ],
      ),
      const SizedBox(height: 16),
      const InfoNotice(
        'Physical-device validation pending',
        'Readings and manufacturer behavior still need validation on Realme 5i and TECNO Spark 30 5G. Refresh reads system measurements; it does not certify unsupported operations.',
        accent: Accent.warning,
      ),
    ],
    '/advanced' => [
      const InfoNotice(
        'Advanced access is disabled',
        'Standard monitoring works without elevated authorization. Shizuku integration is planned after the MVP.',
        accent: Accent.warning,
        icon: Icons.lock_outline,
      ),
      const SectionHeading('Advanced access status'),
      const DetailCard(
        rows: [
          ('Shizuku service', 'Not checked · integration not implemented'),
          ('Authorization', 'Not requested'),
          ('Advanced actions', 'None enabled'),
        ],
      ),
      const SizedBox(height: 16),
      const InfoNotice(
        'Explicit authorization required',
        'Future advanced actions will check device support, protect critical apps, and require confirmation. Losing authorization will disable those controls.',
      ),
    ],
    _ => [],
  };
}

String _observationTime(BuildContext context, int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class DeviceSummaryCard extends StatelessWidget {
  const DeviceSummaryCard({super.key, required this.snapshot});
  final SystemSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Accent.blue.background(context),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBadge(
          'On-device readings',
          icon: Icons.phone_android_rounded,
        ),
        const SizedBox(height: 20),
        Text(
          '${snapshot.manufacturer} ${snapshot.model}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Android ${snapshot.androidVersion} · API ${snapshot.apiLevel}',
          style: TextStyle(color: Accent.blue.foreground(context)),
        ),
        const SizedBox(height: 8),
        Text(
          'Build ${snapshot.buildId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
