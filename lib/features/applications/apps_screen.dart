import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/apps_api.g.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';
import 'apps_controller.dart';
import 'apps_repository.dart';

String checkedTime(BuildContext context, int millis) {
  if (millis <= 0) return 'Unavailable';
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final local = MaterialLocalizations.of(context);
  return '${local.formatMediumDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

String accessLabel(AccessState state) => switch (state) {
  AccessState.available => 'Available',
  AccessState.permissionRequired => 'Access required',
  AccessState.restricted => 'Restricted',
  AccessState.unsupported => 'Not supported',
  AccessState.unavailable => 'Unavailable',
};

class ActionNotice extends ConsumerWidget {
  const ActionNotice({super.key, this.packageName});
  final String? packageName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appActionsProvider);
    final result = state.result;
    if (state.issue != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InfoNotice(
          'Request not confirmed',
          state.issue!,
          accent: Accent.warning,
        ),
      );
    }
    if (result == null ||
        (packageName != null && packageName != result.packageName)) {
      return const SizedBox.shrink();
    }
    final title = switch (result.phase) {
      AppActionPhase.opened => 'Android settings opened',
      AppActionPhase.requested => 'Uninstall requested — unverified',
      AppActionPhase.canceled => 'Uninstall canceled',
      AppActionPhase.verifiedRemoved => 'Uninstall verified',
      AppActionPhase.unverified => 'Uninstall result unverified',
      AppActionPhase.blocked => 'Request blocked',
      AppActionPhase.failed => 'Request failed',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InfoNotice(
        title,
        '${result.packageName}\n${result.message}\n${checkedTime(context, result.checkedAtMillis)}',
        accent: result.phase == AppActionPhase.verifiedRemoved
            ? Accent.mint
            : Accent.blue,
        action: result.phase == AppActionPhase.requested
            ? null
            : TextButton(
                onPressed: state.busy
                    ? null
                    : () => ref.read(appActionsProvider.notifier).dismiss(),
                child: const Text('Dismiss result'),
              ),
      ),
    );
  }
}

class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});
  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final _search = TextEditingController();
  AppFilter _filter = AppFilter.all;
  AppSort _sort = AppSort.name;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _bounded(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: child,
    ),
  );
  Future<void> _refresh() async {
    ref.invalidate(appInventoryProvider);
    await ref.read(appInventoryProvider.future);
    await ref.read(appActionsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(appInventoryProvider);
    final data = inventory.asData?.value;
    final apps = data == null
        ? <ApplicationRecord>[]
        : filterApplications(
            data.apps,
            query: _search.text,
            filter: _filter,
            sort: _sort,
          );
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await _refresh();
        } catch (_) {
          /* Inline retry state. */
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: _bounded(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeading(
                      title: 'Your applications.',
                      subtitle:
                          'Review apps and use Android’s supported controls.',
                      action: IconButton(
                        tooltip: 'Refresh apps',
                        onPressed: inventory.isLoading
                            ? null
                            : () {
                                ref.invalidate(appInventoryProvider);
                              },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                    const InfoNotice(
                      'Visible apps in this profile',
                      'Android limits which installed apps Phone Manager can see. This list may exclude hidden apps and other profiles; it is not a list of running processes.',
                    ),
                    const SizedBox(height: 16),
                    const ActionNotice(),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Search apps or packages',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear app search',
                                onPressed: () => setState(_search.clear),
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in AppFilter.values)
                          FilterChip(
                            label: Text(switch (value) {
                              AppFilter.all => 'All visible',
                              AppFilter.user => 'User apps',
                              AppFilter.system => 'System apps',
                            }),
                            selected: _filter == value,
                            onSelected: (_) => setState(() => _filter = value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AppSort>(
                      initialValue: _sort,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Sort apps'),
                      items: [
                        for (final value in AppSort.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(switch (value) {
                              AppSort.name => 'Name',
                              AppSort.updated => 'Recently updated',
                              AppSort.packageName => 'Package name',
                            }),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (data != null) ...[
                      Text(
                        '${apps.length} shown · ${data.apps.length} visible apps',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Read at ${checkedTime(context, data.observedAtMillis)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final notice in data.notices)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: InfoNotice(
                            'Partial inventory',
                            notice,
                            accent: Accent.warning,
                          ),
                        ),
                    ],
                    if (inventory.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Reading visible applications',
                          ),
                        ),
                      ),
                    if (inventory.hasError)
                      InfoNotice(
                        'Apps could not be read',
                        'The Android app service could not provide an inventory. Retry on your Android device.',
                        accent: Accent.warning,
                        action: OutlinedButton(
                          onPressed: () => ref.invalidate(appInventoryProvider),
                          child: const Text('Retry app list'),
                        ),
                      ),
                    if (data != null && apps.isEmpty)
                      InfoNotice(
                        data.apps.isEmpty
                            ? 'No visible apps returned'
                            : 'No matching apps',
                        data.apps.isEmpty
                            ? 'Android returned no readable app records. Refresh to check again.'
                            : 'Try a different search or filter.',
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _bounded(
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: ValueKey(app.packageName),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: const Icon(Icons.apps_rounded),
                      title: Text(app.label),
                      subtitle: Text(
                        '${app.packageName}\n${app.systemApp ? 'System app' : 'User app'} · ${app.enabled ? 'Enabled' : 'Disabled'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/applications/${Uri.encodeComponent(app.packageName)}',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class AppDetailsScreen extends ConsumerWidget {
  const AppDetailsScreen({super.key, required this.packageName});
  final String packageName;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    ApplicationRecord app,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Request uninstall?'),
        content: Text(
          '${app.label}\n${app.packageName}\nVersion ${app.versionName ?? 'unavailable'} · build ${app.versionCode}\n\nAndroid will ask for confirmation. Uninstalling can remove this app’s local data. Phone Manager will recheck whether this target is eligible before opening Android.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep app'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to Android'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await ref.read(appActionsProvider.notifier).uninstall(app);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(appDetailsProvider(packageName));
    final action = ref.watch(appActionsProvider);
    return PageContent(
      children: [
        PageHeading(
          title: 'Application details',
          subtitle: packageName,
          action: IconButton(
            tooltip: 'Refresh app details',
            onPressed: details.isLoading
                ? null
                : () => ref.invalidate(appDetailsProvider(packageName)),
            icon: const Icon(Icons.refresh),
          ),
        ),
        ActionNotice(packageName: packageName),
        details.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Reading app details',
            ),
          ),
          error: (_, _) => InfoNotice(
            'App details could not be read',
            'Refresh to retry. No action is available until this app has been checked.',
            accent: Accent.warning,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(appDetailsProvider(packageName)),
              child: const Text('Retry app details'),
            ),
          ),
          data: (value) {
            if (value == null) {
              return const InfoNotice(
                'App unavailable',
                'This package may have been removed or may no longer be visible in this profile. Its absence alone does not confirm an uninstall.',
              );
            }
            final app = value.app;
            final uninstall = capability(value.capabilities, 'uninstall');
            final settings = capability(value.capabilities, 'appSettings');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  app.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DetailCard(
                  rows: [
                    ('Package', app.packageName),
                    (
                      'Version',
                      '${app.versionName ?? 'Unavailable'} · build ${app.versionCode}',
                    ),
                    ('Type', app.systemApp ? 'System app' : 'User app'),
                    ('State', app.enabled ? 'Enabled' : 'Disabled'),
                    (
                      'Installed',
                      checkedTime(context, app.firstInstalledMillis),
                    ),
                    ('Updated', checkedTime(context, app.lastUpdatedMillis)),
                    ('Target Android API', '${value.targetSdk}'),
                    ('Android UID', '${value.uid}'),
                    (
                      'Installer package',
                      value.installerPackage ?? 'Unavailable',
                    ),
                    ('APK files only', formatBytes(value.apkBytes)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'APK file size includes readable base and split APKs. App data, cache, and total storage usage are not measured.',
                ),
                const SectionHeading('Supported actions'),
                if (settings != null) Text(settings.reason),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      !action.busy && settings?.state == AccessState.available
                      ? () => ref
                            .read(appActionsProvider.notifier)
                            .settings(packageName)
                      : null,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open Android app settings'),
                ),
                const SizedBox(height: 16),
                Text(
                  uninstall?.reason ??
                      'Uninstall availability could not be checked.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      !action.busy && uninstall?.state == AccessState.available
                      ? () => _confirm(context, ref, app)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Request uninstall'),
                ),
                if (action.busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Requesting Android action',
                      ),
                    ),
                  ),
                const SectionHeading(
                  'Requested permissions',
                  subtitle: 'Android-reported grant flags for permissions declared by this app. Special access and per-operation restrictions can differ. Change access in Android app settings.',
                ),
                if (value.permissions.isEmpty)
                  const Text('No requested permission records returned.'),
                for (final permission in value.permissions)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permission.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(permission.name),
                          const SizedBox(height: 8),
                          Text(
                            permission.granted
                                ? 'Granted by Android'
                                : 'Not granted by Android',
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Checked at ${checkedTime(context, value.checkedAtMillis)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(capabilitiesProvider);
    final busy = ref.watch(appActionsProvider.select((value) => value.busy));
    return PageContent(
      children: [
        PageHeading(
          title: 'Access & capabilities',
          subtitle: 'Checked on this device. Access is checked again before each action.',
          action: IconButton(
            tooltip: 'Refresh capabilities',
            onPressed: snapshot.isLoading
                ? null
                : () => ref.invalidate(capabilitiesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ),
        const ActionNotice(),
        snapshot.when(
          skipLoadingOnRefresh: false,
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Checking device capabilities',
            ),
          ),
          error: (_, _) => InfoNotice(
            'Capabilities could not be checked',
            'The Android service is unavailable. Retry before using an action.',
            accent: Accent.warning,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(capabilitiesProvider),
              child: const Text('Retry capabilities'),
            ),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Checked at ${checkedTime(context, value.checkedAtMillis)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final item in value.capabilities)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusBadge(
                            accessLabel(item.state),
                            accent: item.state == AccessState.available
                                ? Accent.mint
                                : Accent.warning,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(item.reason),
                        if ([
                          'notifications',
                          'installUpdates',
                          'appSettings',
                        ].contains(item.id)) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => ref
                                      .read(appActionsProvider.notifier)
                                      .accessSettings(item.id),
                            child: Text(switch (item.id) {
                              'notifications' =>
                                'Android notification settings',
                              'installUpdates' =>
                                'Android installation settings',
                              _ => 'Phone Manager app settings',
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/more/updates'),
                icon: const Icon(Icons.system_update),
                label: const Text('Manage milestone updates'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
