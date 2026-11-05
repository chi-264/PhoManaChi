import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/platform/update_api.g.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/providers.dart';
import '../core/platform/apps_api.g.dart';
import '../features/applications/apps_controller.dart';
import '../features/applications/apps_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/settings_screen.dart';
import '../features/updates/updates_screen.dart';
import '../features/updates/update_controller.dart';
import 'settings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(shell: shell, location: state.uri.path),
        branches: [
          for (final entry in const [
            ('/dashboard', 'Dashboard'),
            ('/processes', 'Process Manager'),
            ('/storage', 'Storage Cleaner'),
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: entry.$1,
                  builder: (_, _) =>
                      ResourceScreen(kind: entry.$1, title: entry.$2),
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/applications',
                builder: (_, _) => const AppsScreen(),
                routes: [
                  GoRoute(
                    path: ':packageName',
                    builder: (_, state) => AppDetailsScreen(
                      packageName: state.pathParameters['packageName']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  for (final entry in const [
                    ('battery', 'Battery Monitor'),
                    ('manufacturer', 'Manufacturer Tools'),
                    ('diagnostics', 'Diagnostics'),
                    ('advanced', 'Advanced Access'),
                  ])
                    GoRoute(
                      path: entry.$1,
                      builder: (_, _) =>
                          ResourceScreen(kind: '/${entry.$1}', title: entry.$2),
                    ),
                  GoRoute(
                    path: 'permissions',
                    builder: (_, _) => const PermissionsScreen(),
                  ),
                  GoRoute(
                    path: 'updates',
                    builder: (_, _) => const UpdatesScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (_, _) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

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
    AppsFlutterApi.setUp(_AppsCallbacks(changed: _refreshApps));
    UpdateFlutterApi.setUp(
      _UpdateCallbacks(
        changed: () {
          if (mounted) ref.read(updatesProvider.notifier).refresh();
        },
        open: () {
          if (mounted) ref.read(routerProvider).go('/more/updates');
        },
      ),
    );
  }

  @override
  void dispose() {
    AppsFlutterApi.setUp(null);
    UpdateFlutterApi.setUp(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(snapshotProvider);
      _refreshApps();
    }
    ref
        .read(updatesProvider.notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  void _refreshApps() {
    if (!mounted) return;
    ref.invalidate(appInventoryProvider);
    ref.invalidate(appDetailsProvider);
    ref.invalidate(capabilitiesProvider);
    if (ref.exists(appActionsProvider)) {
      ref.read(appActionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Phone Manager',
    debugShowCheckedModeBanner: false,
    routerConfig: ref.watch(routerProvider),
    themeMode: ref.watch(themeProvider).asData?.value ?? ThemeMode.system,
    theme: phoneManagerTheme(Brightness.light),
    darkTheme: phoneManagerTheme(Brightness.dark),
  );
}

const _destinations = [
  ('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
  ('Processes', Icons.memory_outlined, Icons.memory_rounded),
  ('Storage', Icons.folder_outlined, Icons.folder_rounded),
  ('Apps', Icons.apps_outlined, Icons.apps_rounded),
  ('More', Icons.more_horiz_rounded, Icons.more_horiz_rounded),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.location});
  final StatefulNavigationShell shell;
  final String location;
  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final wide = MediaQuery.sizeOf(context).width >= 1000 && !largeText;
    final detail =
        location.startsWith('/more/') || location.startsWith('/applications/');
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: largeText ? 88 : 72,
        leading: detail
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(
                        location.startsWith('/applications/')
                            ? '/applications'
                            : '/more',
                      ),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Row(
          children: [
            if (!largeText) ...[
              Container(
                width: 34,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                'Phone Manager',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          if (location != '/more/settings')
            IconButton(
              tooltip: 'Settings',
              onPressed: () {
                if (shell.currentIndex == 4) {
                  context.push('/more/settings');
                } else {
                  context.go('/more/settings');
                }
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: wide,
        child: Row(
          children: [
            if (wide)
              Container(
                width: 236,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            child: Text(
                              'YOUR DEVICE',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          for (var i = 0; i < _destinations.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: shell.currentIndex == i,
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  leading: Icon(
                                    shell.currentIndex == i
                                        ? _destinations[i].$3
                                        : _destinations[i].$2,
                                  ),
                                  title: Text(_destinations[i].$1),
                                  onTap: () => _select(i),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 20,
                            color: Accent.mint.foreground(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'On your phone.\nNo account required.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (location != '/more/updates')
                    const UpdateAvailableBanner(),
                  Expanded(child: shell),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: largeText ? 96 : 80,
              selectedIndex: shell.currentIndex,
              labelBehavior: largeText
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _select,
              destinations: [
                for (final entry in _destinations)
                  NavigationDestination(
                    icon: Icon(entry.$2),
                    selectedIcon: Icon(entry.$3),
                    label: entry.$1,
                  ),
              ],
            ),
    );
  }
}

class _UpdateCallbacks extends UpdateFlutterApi {
  _UpdateCallbacks({required this.changed, required this.open});
  final VoidCallback changed;
  final VoidCallback open;
  @override
  void statusChanged() => changed();
  @override
  void openUpdates() => open();
}

class _AppsCallbacks extends AppsFlutterApi {
  _AppsCallbacks({required this.changed});
  final VoidCallback changed;
  @override
  void actionChanged() => changed();
}
