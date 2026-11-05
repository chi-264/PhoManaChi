import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phomanachi/app/app.dart';
import 'package:phomanachi/app/settings.dart';
import 'package:phomanachi/core/platform/system_api.g.dart';
import 'package:phomanachi/core/platform/update_api.g.dart';
import 'package:phomanachi/core/theme/app_theme.dart';
import 'package:phomanachi/features/dashboard/providers.dart';
import 'package:phomanachi/features/updates/update_controller.dart';
import 'package:phomanachi/features/updates/update_repository.dart';
import 'package:phomanachi/features/updates/updates_screen.dart';

import 'support/fake_updates.dart';

class _Theme extends ThemeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.light;
}

Widget screen(FakeUpdatesRepository repository) => ProviderScope(
  overrides: [updateRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    theme: phoneManagerTheme(Brightness.light),
    home: const Scaffold(body: UpdatesScreen()),
  ),
);
Future<void> tapVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void compact(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 900);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void main() {
  test('Only higher Android version codes represent an update', () {
    final release = milestone();
    expect(hasNewerRelease(updateStatus(release: release)), isTrue);
    release.versionCode = 2;
    expect(hasNewerRelease(updateStatus(release: release)), isFalse);
    expect(hasNewerRelease(updateStatus()), isFalse);
    expect(hasNewerRelease(null), isFalse);
  });
  testWidgets(
    'Checking shows release notes without downloading or installing',
    (tester) async {
      final repository = FakeUpdatesRepository();
      await tester.pumpWidget(screen(repository));
      await tester.pumpAndSettle();
      expect(repository.checks, 0);
      await tapVisible(tester, 'Check for updates');
      expect(repository.checks, 1);
      expect(find.text('Milestone 0.3.0'), findsOneWidget);
      expect(find.textContaining('Storage analysis'), findsOneWidget);
      expect(repository.downloads, 0);
      expect(repository.installs, 0);
    },
  );
  testWidgets('Download and install remain separate explicit actions', (
    tester,
  ) async {
    final repository = FakeUpdatesRepository(
      initial: updateStatus(phase: 'available', release: milestone()),
    );
    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Download APK');
    expect(repository.downloads, 1);
    expect(repository.installs, 0);
    expect(find.text('Update downloaded and verified'), findsOneWidget);
    await tapVisible(tester, 'Install update');
    expect(repository.installs, 1);
    expect(find.text('Installer opened — unverified'), findsOneWidget);
    expect(find.textContaining('completion is not verified'), findsOneWidget);
    expect(find.text('You’re up to date'), findsNothing);
  });
  testWidgets(
    'Installation permission is explained and not reported as completion',
    (tester) async {
      final repository = FakeUpdatesRepository(
        initial: updateStatus(
          phase: 'ready',
          release: milestone(),
          canInstall: false,
        ),
      );
      await tester.pumpWidget(screen(repository));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Allow installation');
      expect(find.text('Return after changing the permission'), findsOneWidget);
      expect(find.text('You’re up to date'), findsNothing);
      expect(repository.installs, 1);
    },
  );
  testWidgets('Denied notifications preserve manual update checks', (
    tester,
  ) async {
    final repository = FakeUpdatesRepository()..grantNotifications = false;
    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repository.permissionRequests, 1);
    expect(repository.status.automaticChecksEnabled, isTrue);
    expect(find.text('Notifications are blocked by Android'), findsOneWidget);
    await tapVisible(tester, 'Check for updates');
    expect(repository.checks, 1);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repository.status.automaticChecksEnabled, isFalse);
    expect(repository.permissionRequests, 1);
  });
  testWidgets('Offline check does not pretend that the app is up to date', (
    tester,
  ) async {
    final repository = FakeUpdatesRepository()..failCheck = true;
    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();
    await tapVisible(tester, 'Check for updates');
    expect(
      find.text('The update operation could not complete. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('You’re up to date'), findsNothing);
    expect(repository.status.lastCheckedMillis, isNull);
  });
  testWidgets('Unsupported Android version never offers Download APK', (
    tester,
  ) async {
    final repository = FakeUpdatesRepository(
      initial: updateStatus(phase: 'incompatible', release: milestone()),
    );
    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();
    expect(find.text('A newer Android version is required'), findsOneWidget);
    expect(find.text('Download APK'), findsNothing);
  });
  testWidgets(
    'Canceled downloads stop polling and never request installation',
    (tester) async {
      final repository = FakeUpdatesRepository(
        initial: updateStatus(phase: 'available', release: milestone()),
      )..pendingDownload = Completer<UpdateStatus>();
      await tester.pumpWidget(screen(repository));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download APK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download APK'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.ensureVisible(find.text('Cancel download'));
      await tester.pump();
      await tester.tap(find.text('Cancel download'));
      await tester.pumpAndSettle();
      expect(
        find.text('Download canceled. No installation was started.'),
        findsOneWidget,
      );
      expect(repository.installs, 0);
      final reads = repository.reads;
      await tester.pump(const Duration(seconds: 3));
      expect(repository.reads, reads);
    },
  );
  testWidgets('Update details fit a compact phone at 2x text', (tester) async {
    compact(tester);
    final repository = FakeUpdatesRepository(
      initial: updateStatus(
        phase: 'available',
        release: milestone(),
        automatic: true,
        allowed: false,
      ),
    );
    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Notification cold launch opens Updates under More', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/more/updates';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final repository = FakeUpdatesRepository(
      initial: updateStatus(phase: 'available', release: milestone()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateRepositoryProvider.overrideWithValue(repository),
          themeProvider.overrideWith(_Theme.new),
          snapshotProvider.overrideWith(
            (ref) async => SystemSnapshot(
              contractVersion: 1,
              observedAtMillis: 0,
              manufacturer: 'Test',
              model: 'Phone',
              androidVersion: '14',
              apiLevel: 34,
              buildId: 'test',
              notices: [],
            ),
          ),
        ],
        child: const PhoneManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App updates'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
  });
  testWidgets(
    'Available update banner opens More on a compact phone with large text',
    (tester) async {
      compact(tester);
      final repository = FakeUpdatesRepository(
        initial: updateStatus(phase: 'available', release: milestone()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateRepositoryProvider.overrideWithValue(repository),
            themeProvider.overrideWith(_Theme.new),
            snapshotProvider.overrideWith(
              (ref) async => SystemSnapshot(
                contractVersion: 1,
                observedAtMillis: 0,
                manufacturer: 'Test',
                model: 'Phone',
                androidVersion: '14',
                apiLevel: 34,
                buildId: 'test',
                notices: [],
              ),
            ),
          ],
          child: const PhoneManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review update'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Review update'));
      await tester.pumpAndSettle();
      expect(find.text('App updates'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
