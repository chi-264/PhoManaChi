import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/providers.dart';
import '../features/dashboard/dashboard_screen.dart';
import 'settings.dart';

final _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        for (final entry in const [
          ('/dashboard', 'Dashboard'),
          ('/processes', 'Process Manager'),
          ('/storage', 'Storage Cleaner'),
          ('/applications', 'Application Manager'),
          ('/more', 'More'),
        ])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: entry.$1,
                builder: (_, _) => entry.$1 == '/more'
                    ? const MoreScreen()
                    : ResourceScreen(kind: entry.$1, title: entry.$2),
              ),
            ],
          ),
      ],
    ),
    for (final entry in const [
      ('/battery', 'Battery Monitor'),
      ('/manufacturer', 'Manufacturer Tools'),
      ('/diagnostics', 'Diagnostics'),
      ('/permissions', 'Permissions'),
      ('/advanced', 'Advanced Access'),
    ])
      GoRoute(
        path: entry.$1,
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: Text(entry.$2)),
          body: ResourceScreen(kind: entry.$1, title: entry.$2),
        ),
      ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);

class PhoneManagerApp extends ConsumerStatefulWidget {
  const PhoneManagerApp({super.key});
  @override
  ConsumerState<PhoneManagerApp> createState() => _PhoneManagerAppState();
}

class _PhoneManagerAppState extends ConsumerState<PhoneManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(snapshotProvider);
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Phone Manager',
    debugShowCheckedModeBanner: false,
    routerConfig: _router,
    themeMode: ref.watch(themeProvider).asData?.value ?? ThemeMode.system,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Phone Manager'),
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(child: shell),
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(icon: Icon(Icons.memory), label: 'Processes'),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          label: 'Storage',
        ),
        NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    ),
  );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final entry in const [
        ('/battery', 'Battery Monitor', Icons.battery_std),
        ('/manufacturer', 'Manufacturer Tools', Icons.phone_android),
        ('/diagnostics', 'Diagnostics', Icons.info_outline),
        ('/permissions', 'Permissions', Icons.lock_outline),
        ('/advanced', 'Advanced Access', Icons.admin_panel_settings_outlined),
        ('/settings', 'Settings', Icons.settings_outlined),
      ])
        ListTile(
          leading: Icon(entry.$3),
          title: Text(entry.$2),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(entry.$1),
        ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Phone Manager • Foundation build\nOffline core. No ads, accounts, or analytics.',
        ),
      ),
    ],
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Appearance'),
        DropdownButtonFormField<ThemeMode>(
          initialValue:
              ref.watch(themeProvider).asData?.value ?? ThemeMode.system,
          items: [
            for (final mode in ThemeMode.values)
              DropdownMenuItem(value: mode, child: Text(mode.name)),
          ],
          onChanged: (mode) async {
            if (mode == null) return;
            try {
              await ref.read(themeProvider.notifier).setTheme(mode);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not save theme. Please retry.'),
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Monitoring refreshes when the app resumes or when you request it. No permanent background service is enabled.',
        ),
      ],
    ),
  );
}
