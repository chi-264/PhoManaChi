import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      const PageHeading(
        title: 'More for your device.',
        subtitle: 'Power information, permissions, and preferences.',
      ),
      const SectionHeading('Device tools'),
      _ToolList(
        entries: const [
          (
            'battery',
            'Battery Monitor',
            'Power, temperature, and charging.',
            Icons.battery_std_rounded,
            Accent.mint,
          ),
          (
            'manufacturer',
            'Manufacturer Tools',
            'Device-specific integration status.',
            Icons.build_outlined,
            Accent.purple,
          ),
          (
            'diagnostics',
            'Diagnostics',
            'Reading sources and implementation status.',
            Icons.info_outline_rounded,
            Accent.blue,
          ),
          (
            'permissions',
            'Permissions',
            'Understand what the app can access.',
            Icons.shield_outlined,
            Accent.blue,
          ),
          (
            'advanced',
            'Advanced Access',
            'Optional privileges · not enabled.',
            Icons.lock_outline_rounded,
            Accent.warning,
          ),
        ],
      ),
      const SectionHeading('Preferences & information'),
      _ToolList(
        entries: const [
          (
            'updates',
            'App updates',
            'Milestones, downloads, and notifications.',
            Icons.system_update_outlined,
            Accent.blue,
          ),
          (
            'settings',
            'Settings',
            'Appearance, monitoring, and privacy.',
            Icons.settings_outlined,
            Accent.blue,
          ),
          (
            'about',
            'About',
            'A thoughtful approach to maintenance.',
            Icons.help_outline_rounded,
            Accent.mint,
          ),
        ],
      ),
      const SizedBox(height: 24),
      const InfoNotice(
        'Your data stays with you',
        'Core features work offline. No advertisements, analytics, or account are required.',
        accent: Accent.mint,
        icon: Icons.shield_outlined,
      ),
    ],
  );
}

class _ToolList extends StatelessWidget {
  const _ToolList({required this.entries});
  final List<(String, String, String, IconData, Accent)> entries;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: AccentIcon(entries[i].$4, accent: entries[i].$5),
            title: Text(
              entries[i].$2,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(entries[i].$3),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/more/${entries[i].$1}'),
          ),
        ],
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageContent(
    children: [
      PageHeading(
        title: 'Clarity over clever claims.',
        subtitle: 'PhoManaChi · Android Phone Manager',
      ),
      InfoNotice(
        'Private by design',
        'Device readings stay local. Your phone does not need a cloud account for everyday maintenance.',
        accent: Accent.mint,
        icon: Icons.shield_outlined,
      ),
      SizedBox(height: 16),
      InfoNotice(
        'Accurate information',
        'Measurements come from supported Android APIs. Missing readings stay unavailable; unsupported actions stay disabled.',
      ),
      SizedBox(height: 16),
      InfoNotice(
        'Always your choice',
        'File cleanup and advanced actions are not enabled in this development build. Future destructive operations will require your confirmation.',
        accent: Accent.purple,
        icon: Icons.touch_app_outlined,
      ),
    ],
  );
}
