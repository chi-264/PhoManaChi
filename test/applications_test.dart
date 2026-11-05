import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phomanachi/app/app.dart';
import 'package:phomanachi/app/settings.dart';
import 'package:phomanachi/core/platform/apps_api.g.dart';
import 'package:phomanachi/core/platform/system_api.g.dart';
import 'package:phomanachi/core/theme/app_theme.dart';
import 'package:phomanachi/features/applications/apps_controller.dart';
import 'package:phomanachi/features/applications/apps_repository.dart';
import 'package:phomanachi/features/applications/apps_screen.dart';
import 'package:phomanachi/features/dashboard/providers.dart';
import 'package:phomanachi/features/updates/update_controller.dart';

import 'support/fake_apps.dart';
import 'support/fake_updates.dart';
import 'support/rendering.dart';

class _Theme extends ThemeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.light;
}

Widget standalone(FakeAppsRepository repo, Widget child, {bool dark = false}) =>
    ProviderScope(
      overrides: [appsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: phoneManagerTheme(dark ? Brightness.dark : Brightness.light),
        home: Scaffold(body: child),
      ),
    );

Widget app(FakeAppsRepository repo) => ProviderScope(
  overrides: [
    appsRepositoryProvider.overrideWithValue(repo),
    updateRepositoryProvider.overrideWithValue(FakeUpdatesRepository()),
    themeProvider.overrideWith(_Theme.new),
    snapshotProvider.overrideWith(
      (ref) async => SystemSnapshot(
        contractVersion: 1,
        observedAtMillis: appObservedAt,
        manufacturer: 'Test',
        model: 'Phone',
        androidVersion: '14',
        apiLevel: 34,
        buildId: 'fixture',
        notices: [],
      ),
    ),
  ],
  child: const PhoneManagerApp(),
);

Future<void> tapVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> confirmUninstall(WidgetTester tester) async {
  await tapVisible(tester, 'Request uninstall');
  expect(find.text('Request uninstall?'), findsOneWidget);
  await tapVisible(tester, 'Continue to Android');
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

void resumeFromSettings(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  test('Pending result dismissal cannot overlap another app action', () async {
    final repo = FakeAppsRepository()..pendingDismiss = Completer<void>();
    final container = ProviderContainer(
      overrides: [appsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(appActionsProvider.notifier);
    final dismissal = controller.dismiss();
    expect(container.read(appActionsProvider).busy, isTrue);
    await controller.uninstall(fixtureApp());
    expect(repo.uninstalls, 0);
    repo.pendingDismiss!.complete();
    await dismissal;
    expect(container.read(appActionsProvider).busy, isFalse);
    await controller.uninstall(fixtureApp());
    expect(repo.uninstalls, 1);
  });
  test('Search and filters preserve the source inventory and sort deterministically', () {
    final apps = [
      fixtureApp(label: 'Zebra', packageName: 'test.z'),
      fixtureApp(
        label: 'Alpha',
        packageName: 'test.a',
        system: true,
        updated: appObservedAt + 1,
      ),
    ];
    expect(filterApplications(apps, query: ' TEST.A ').single.label, 'Alpha');
    expect(
      filterApplications(apps, filter: AppFilter.user).single.label,
      'Zebra',
    );
    expect(
      filterApplications(apps, filter: AppFilter.system).single.label,
      'Alpha',
    );
    expect(
      filterApplications(apps, sort: AppSort.updated).first.label,
      'Alpha',
    );
    expect(apps.first.label, 'Zebra');
  });
  testWidgets(
    'Visible inventory searches packages and filters user/system apps',
    (tester) async {
      final repo = FakeAppsRepository();
      await tester.pumpWidget(standalone(repo, const AppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('2 shown · 2 visible apps'), findsOneWidget);
      expect(
        find.textContaining('not a list of running processes'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'test.notes');
      await tester.pumpAndSettle();
      expect(find.text('1 shown · 2 visible apps'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear app search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System apps'));
      await tester.pumpAndSettle();
      expect(find.text('1 shown · 2 visible apps'), findsOneWidget);
      expect(repo.uninstalls, 0);
    },
  );
  testWidgets(
    'Native inventory failure offers retry without a false empty list',
    (tester) async {
      final repo = FakeAppsRepository()..failInventory = true;
      await tester.pumpWidget(standalone(repo, const AppsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Apps could not be read'), findsOneWidget);
      expect(find.text('No visible apps returned'), findsNothing);
      repo.failInventory = false;
      await tapVisible(tester, 'Retry app list');
      expect(repo.reads, 2);
      expect(find.text('2 shown · 2 visible apps'), findsOneWidget);
    },
  );
  testWidgets(
    'Uninstall requires explicit review and preserves the reviewed identity',
    (tester) async {
      final repo = FakeAppsRepository();
      await tester.pumpWidget(
        standalone(repo, const AppDetailsScreen(packageName: 'test.notes')),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Request uninstall');
      expect(repo.uninstalls, 0);
      await tapVisible(tester, 'Keep app');
      expect(repo.uninstalls, 0);
      await confirmUninstall(tester);
      expect(repo.uninstalls, 1);
      expect(repo.requestedTarget!.versionCode, 12);
      expect(repo.requestedTarget!.lastUpdatedMillis, appObservedAt);
      expect(find.text('Uninstall requested — unverified'), findsOneWidget);
      expect(find.text('Uninstall verified'), findsNothing);
    },
  );
  testWidgets('Protected system apps have no enabled uninstall action', (
    tester,
  ) async {
    final repo = FakeAppsRepository();
    await tester.pumpWidget(
      standalone(repo, const AppDetailsScreen(packageName: 'android.system')),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Request uninstall'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('This app is protected by Android.'), findsOneWidget);
    expect(repo.uninstalls, 0);
  });
  testWidgets('Missing uninstall capability fails closed', (tester) async {
    final repo = FakeAppsRepository()..missingUninstallCapability = true;
    await tester.pumpWidget(
      standalone(repo, const AppDetailsScreen(packageName: 'test.notes')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request uninstall'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'Changed or restricted target is blocked by the native action result',
    (tester) async {
      final repo = FakeAppsRepository()..blockUninstall = true;
      await tester.pumpWidget(
        standalone(repo, const AppDetailsScreen(packageName: 'test.notes')),
      );
      await tester.pumpAndSettle();
      await confirmUninstall(tester);
      expect(find.text('Request blocked'), findsOneWidget);
      expect(find.text('Uninstall verified'), findsNothing);
    },
  );
  testWidgets('Uninstall errors are recoverable and never become success', (
    tester,
  ) async {
    final repo = FakeAppsRepository()..failUninstall = true;
    await tester.pumpWidget(
      standalone(repo, const AppDetailsScreen(packageName: 'test.notes')),
    );
    await tester.pumpAndSettle();
    await confirmUninstall(tester);
    expect(find.text('Request not confirmed'), findsOneWidget);
    expect(find.text('Uninstall verified'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request uninstall'),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('Cancellation and verified removal remain distinct on resume', (
    tester,
  ) async {
    final repo = FakeAppsRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    repo.last = AppActionResult(
      packageName: 'test.notes',
      phase: AppActionPhase.canceled,
      message: 'User canceled. Still installed.',
      checkedAtMillis: appObservedAt,
    );
    resumeFromSettings(tester);
    await tester.pumpAndSettle();
    expect(find.text('Uninstall canceled'), findsOneWidget);
    expect(find.text('Uninstall verified'), findsNothing);
    final before = repo.reads;
    repo.apps.removeWhere((a) => a.packageName == 'test.notes');
    repo.last = AppActionResult(
      packageName: 'test.notes',
      phase: AppActionPhase.verifiedRemoved,
      message: 'Android confirmed; package absent.',
      checkedAtMillis: appObservedAt,
    );
    resumeFromSettings(tester);
    await tester.pumpAndSettle();
    expect(repo.reads, greaterThan(before));
    expect(find.text('Uninstall verified'), findsOneWidget);
    expect(find.text('1 shown · 1 visible apps'), findsOneWidget);
  });
  testWidgets('Details and Back keep Apps selected and preserve search', (
    tester,
  ) async {
    final repo = FakeAppsRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Notes');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('test.notes')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('test.notes')));
    await tester.pumpAndSettle();
    expect(find.text('Application details'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Notes',
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });
  testWidgets(
    'Revoked access is rechecked on returning from Android settings',
    (tester) async {
      final repo = FakeAppsRepository()..notifications = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Permissions');
      expect(
        find.text('Notifications are allowed by Android.'),
        findsOneWidget,
      );
      repo.notifications = false;
      resumeFromSettings(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Notifications are blocked by Android.'),
        findsOneWidget,
      );
      expect(repo.checks, greaterThanOrEqualTo(2));
      expect(repo.accessRequests, 0);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      repo.notifications = true;
      final previousChecks = repo.checks;
      await tapVisible(tester, 'Permissions');
      expect(repo.checks, greaterThan(previousChecks));
      expect(find.text('Notifications are allowed by Android.'), findsOneWidget);
    },
  );
  testWidgets('Resolver failure cannot display access as available', (
    tester,
  ) async {
    final repo = FakeAppsRepository()..failCapabilities = true;
    await tester.pumpWidget(standalone(repo, const PermissionsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Capabilities could not be checked'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
    repo.failCapabilities = false;
    await tapVisible(tester, 'Retry capabilities');
    expect(find.text('Access required'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('App management preview ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final repo = FakeAppsRepository();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: standalone(repo, const AppsScreen(), dark: dark),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'apps-${dark ? 'dark' : 'light'}');
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: standalone(
            repo,
            const AppDetailsScreen(packageName: 'test.notes'),
            dark: dark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'app-details-${dark ? 'dark' : 'light'}');
    });
    testWidgets(
      'Apps list and capability cards fit compact large text ${dark ? 'dark' : 'light'}',
      (tester) async {
        compact(tester);
        final repo = FakeAppsRepository();
        await tester.pumpWidget(
          standalone(repo, const AppsScreen(), dark: dark),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('test.notes')),
          250,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          standalone(repo, const PermissionsScreen(), dark: dark),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Android notification settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repo.accessRequests, 0);
      },
    );
    testWidgets(
      'App details and confirmation support compact 2x text ${dark ? 'dark' : 'light'}',
      (tester) async {
        compact(tester);
        final repo = FakeAppsRepository();
        await tester.pumpWidget(
          standalone(
            repo,
            const AppDetailsScreen(packageName: 'test.notes'),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, 'Request uninstall');
        expect(tester.takeException(), isNull);
        await tapVisible(tester, 'Keep app');
        expect(tester.takeException(), isNull);
        expect(repo.uninstalls, 0);
      },
    );
  }
  testWidgets('Unavailable app never offers controls or claims removal', (
    tester,
  ) async {
    await tester.pumpWidget(
      standalone(
        FakeAppsRepository(),
        const AppDetailsScreen(packageName: 'test.missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App unavailable'), findsOneWidget);
    expect(find.text('Request uninstall'), findsNothing);
    expect(find.text('Uninstall verified'), findsNothing);
  });
}
