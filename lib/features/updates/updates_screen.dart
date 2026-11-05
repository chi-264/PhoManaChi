import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/update_api.g.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';
import 'update_controller.dart';
import 'update_repository.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(updatesProvider);
    final controller = ref.read(updatesProvider.notifier);
    final status = view.status;
    final release = status?.release;
    final newer = hasNewerRelease(status);
    final downloading =
        view.operation == 'download' ||
        view.operation == 'cancel' ||
        status?.phase == 'downloading';
    final ready = const [
      'ready',
      'installPermissionRequired',
      'installerOpened',
    ].contains(status?.phase);
    return PageContent(
      children: [
        const PageHeading(
          title: 'App updates',
          subtitle: 'New milestones, delivered from GitHub Releases.',
        ),
        if (view.initialLoading)
          const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Reading update settings',
            ),
          ),
        if (view.issue != null) ...[
          InfoNotice('Update service', view.issue!, accent: Accent.warning),
          const SizedBox(height: 16),
        ],
        if (status != null) ...[
          StatusBadge(
            _statusLabel(status),
            accent: newer ? Accent.blue : Accent.mint,
            icon: newer ? Icons.system_update_outlined : Icons.info_outline,
          ),
          const SizedBox(height: 16),
          DetailCard(
            rows: [
              (
                'Installed version',
                '${status.installedVersionName} · build ${status.installedVersionCode}',
              ),
              (
                'Last release check',
                status.lastCheckedMillis == null
                    ? 'Not checked yet'
                    : _time(context, status.lastCheckedMillis!),
              ),
              ('Release source', 'github.com/chi-264/PhoManaChi'),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (view.busy && !downloading) ...[
          const LinearProgressIndicator(
            semanticsLabel: 'Update operation in progress',
          ),
          const SizedBox(height: 12),
          Text(switch (view.operation) {
            'check' => 'Checking the latest published milestone…',
            'install' => 'Verifying the APK before opening Android…',
            _ => 'Updating notification preferences…',
          }),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: view.busy || view.initialLoading
              ? null
              : status == null
              ? controller.refresh
              : controller.check,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            status == null ? 'Retry update service' : 'Check for updates',
          ),
        ),
        if (status?.errorMessage != null) ...[
          const SizedBox(height: 16),
          InfoNotice(
            'Update notice',
            status!.errorMessage!,
            accent: Accent.warning,
          ),
        ],
        if (status?.phase == 'noRelease') ...[
          const SizedBox(height: 16),
          const InfoNotice(
            'No milestone release published yet',
            'The updater is ready. A milestone must be published with its APK and update manifest before a download can be offered.',
          ),
        ],
        if (status?.phase == 'upToDate') ...[
          const SizedBox(height: 16),
          const InfoNotice(
            'You’re up to date',
            'Your installed build is at least as new as the latest published milestone.',
            accent: Accent.mint,
          ),
        ],
        if (newer && release != null) ...[
          SectionHeading(
            'Milestone ${release.versionName}',
            subtitle: release.title,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    release.notes.isEmpty
                        ? 'No release notes were provided.'
                        : release.notes,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'APK download · ${formatBytes(release.sizeBytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The file checksum, application identity, version, and signing certificate are verified before installation.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (status!.phase == 'incompatible')
            InfoNotice(
              'A newer Android version is required',
              'This milestone requires Android API ${release.minSdk} or later. The installed app remains available.',
              accent: Accent.warning,
            )
          else if (downloading) ...[
            LinearProgressIndicator(
              value: status.downloadedBytes > 0
                  ? (status.downloadedBytes / release.sizeBytes).clamp(0, 1)
                  : null,
              semanticsLabel: 'Downloading and verifying the APK',
            ),
            const SizedBox(height: 12),
            Text(
              status.downloadedBytes >= release.sizeBytes
                  ? 'Verifying the downloaded APK…'
                  : '${formatBytes(status.downloadedBytes)} of ${formatBytes(release.sizeBytes)}',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: view.operation == 'cancel'
                  ? null
                  : controller.cancelDownload,
              child: Text(
                view.operation == 'cancel' ? 'Canceling…' : 'Cancel download',
              ),
            ),
          ] else if (ready) ...[
            InfoNotice(
              status.canInstallPackages
                  ? 'Update downloaded and verified'
                  : 'Allow installation from Phone Manager',
              status.canInstallPackages
                  ? 'Tap Install update to open Android’s installer. You will confirm the update there.'
                  : 'Android requires permission for this app to request an APK installation. Allow it in Settings, return here, and tap Install update. Nothing is installed automatically.',
              accent: Accent.mint,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: view.busy ? null : controller.install,
              icon: const Icon(Icons.system_update_rounded),
              label: Text(
                status.canInstallPackages
                    ? 'Install update'
                    : 'Allow installation',
              ),
            ),
            if (status.phase == 'installerOpened') ...[
              const SizedBox(height: 16),
              const InfoNotice(
                'Android installer opened',
                'Installation has been requested; completion is not verified. Canceling Android’s dialog does not update the app.',
              ),
            ],
            if (status.phase == 'installPermissionRequired') ...[
              const SizedBox(height: 16),
              const InfoNotice(
                'Return after changing the permission',
                'Enable installation from Phone Manager in Android Settings, then return and choose Install update again.',
              ),
            ],
          ] else
            FilledButton.icon(
              onPressed: view.busy ? null : controller.download,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download APK'),
            ),
          const SizedBox(height: 12),
          const Text(
            'Keep the app open during the download. A canceled or interrupted download will not start an installation.',
          ),
        ],
        const SectionHeading('Milestone notifications'),
        if (status != null) ...[
          Card(
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.all(20),
              title: const Text('Notify me about new milestones'),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Check about every 6 hours when connected and the battery is not low. Android may delay background work. APKs download only when you choose.',
                ),
              ),
              value: status.automaticChecksEnabled,
              onChanged: view.busy ? null : controller.setAutomaticChecks,
            ),
          ),
          if (status.automaticChecksEnabled &&
              !status.notificationsAllowed) ...[
            const SizedBox(height: 16),
            InfoNotice(
              'Notifications are blocked by Android',
              'Background checks are enabled, but system notifications are blocked. You can still review updates here.',
              accent: Accent.warning,
              action: OutlinedButton(
                onPressed: controller.openNotificationSettings,
                child: const Text('Open notification settings'),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        const InfoNotice(
          'Core tools stay offline',
          'Update checks contact GitHub only when you request a check or enable milestone notifications. Device readings and maintenance do not depend on the release server.',
          accent: Accent.mint,
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }
}

String _statusLabel(UpdateStatus status) => switch (status.phase) {
  'idle' => 'Ready to check',
  'noRelease' => 'No published milestone yet',
  'upToDate' => 'Up to date',
  'available' => 'New milestone available',
  'incompatible' => 'Android compatibility required',
  'downloading' => 'Downloading and verifying',
  'ready' => 'Download verified',
  'installPermissionRequired' => 'Installation permission required',
  'installerOpened' => 'Installer opened — unverified',
  'failed' => 'Check unavailable',
  _ => 'Update status unavailable',
};
String _time(BuildContext context, int millis) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updatesProvider).status;
    if (!hasNewerRelease(status) || status!.phase == 'incompatible') {
      return const SizedBox.shrink();
    }
    if (MediaQuery.sizeOf(context).width < 400 ||
        MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Material(
        color: Accent.blue.background(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'Milestone ${status.release!.versionName} is available',
              child: TextButton.icon(
                onPressed: () => context.go('/more/updates'),
                icon: const Icon(Icons.system_update_rounded),
                label: const Text('Review update'),
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Accent.blue.background(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.system_update_rounded,
              color: Accent.blue.foreground(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Milestone ${status.release!.versionName} is available.',
                style: TextStyle(color: Accent.blue.foreground(context)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go('/more/updates'),
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }
}
