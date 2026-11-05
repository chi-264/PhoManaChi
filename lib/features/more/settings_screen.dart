import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(themeProvider);
    final selected = appearance.asData?.value;
    return PageContent(
      children: [
        const PageHeading(
          title: 'Make it feel like yours.',
          subtitle: 'Simple preferences. Clear privacy controls.',
        ),
        const SectionHeading(
          'Appearance',
          subtitle: 'Your choice is saved on this device.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final entry in const [
                  (
                    ThemeMode.light,
                    'Light',
                    'A bright, clear workspace.',
                    Icons.light_mode_outlined,
                  ),
                  (
                    ThemeMode.dark,
                    'Dark',
                    'A darker surface for low light.',
                    Icons.dark_mode_outlined,
                  ),
                  (
                    ThemeMode.system,
                    'System',
                    'Follow your device’s appearance.',
                    Icons.phone_android_rounded,
                  ),
                ])
                  Semantics(
                    selected: selected == entry.$1,
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: selected == entry.$1,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: Icon(entry.$4),
                      title: Text(entry.$2),
                      subtitle: Text(entry.$3),
                      trailing: selected == entry.$1
                          ? const Icon(Icons.check_circle_outline_rounded)
                          : null,
                      enabled: !appearance.isLoading,
                      onTap: () async {
                        try {
                          await ref
                              .read(themeProvider.notifier)
                              .setTheme(entry.$1);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save theme. Please retry.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (appearance.hasError) ...[
          const SizedBox(height: 16),
          InfoNotice(
            'Appearance preference unavailable',
            'The saved preference could not be read. Retry loading it or choose an appearance above.',
            accent: Accent.warning,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(themeProvider),
              child: const Text('Retry preference'),
            ),
          ),
        ],
        const SectionHeading('Milestone updates'),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('App updates'),
            subtitle: const Text(
              'Review releases and choose whether to enable background notifications.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/updates'),
          ),
        ),
        const SectionHeading('Monitoring & privacy'),
        const DetailCard(
          rows: [
            ('Resource refresh', 'When requested and when the app resumes'),
            ('Background polling', 'Off'),
            ('Core readings', 'On-device only'),
            ('Accounts and analytics', 'Not used'),
            ('Diagnostic export', 'Not implemented'),
          ],
        ),
        const SizedBox(height: 24),
        const InfoNotice(
          'Permissions stay with their features',
          'Optional access will be explained where it is needed. Appearance changes do not request extra permissions.',
          accent: Accent.mint,
          icon: Icons.lock_outline,
        ),
      ],
    );
  }
}
