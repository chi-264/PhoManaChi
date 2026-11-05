import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phomanachi/app/app.dart';
import 'package:phomanachi/app/settings.dart';
import 'package:phomanachi/core/domain/system_repository.dart';
import 'package:phomanachi/core/platform/system_api.g.dart';
import 'package:phomanachi/core/theme/app_theme.dart';
import 'package:phomanachi/features/dashboard/providers.dart';
import 'package:phomanachi/features/updates/update_controller.dart';

import 'support/fake_updates.dart';

class TestTheme extends ThemeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.light;
  @override
  Future<void> setTheme(ThemeMode mode) async => state = AsyncData(mode);
}

class DarkTestTheme extends TestTheme {
  @override
  Future<ThemeMode> build() async => ThemeMode.dark;
}

SystemSnapshot reading({
  double battery = 75,
  List<String> notices = const [],
}) => SystemSnapshot(
  contractVersion: 1,
  observedAtMillis: DateTime(2026, 11, 5, 15, 30).millisecondsSinceEpoch,
  manufacturer: 'Test',
  model: 'Phone',
  androidVersion: '14',
  apiLevel: 34,
  buildId: 'test-build',
  totalMemoryBytes: 4 * 1024 * 1024 * 1024,
  availableMemoryBytes: 1536 * 1024 * 1024,
  lowMemory: false,
  totalStorageBytes: 64 * 1024 * 1024 * 1024,
  availableStorageBytes: 20 * 1024 * 1024 * 1024,
  batteryPercent: battery,
  batteryState: 'Discharging',
  powerSource: 'Battery',
  temperatureCelsius: 32.5,
  voltageMillivolts: 3980,
  batteryHealth: 'Good',
  notices: notices,
);

class CountingRepository implements SystemRepository {
  int calls = 0;
  Completer<SystemSnapshot>? pending;
  @override
  Future<SystemSnapshot> readSnapshot() {
    calls++;
    return pending?.future ??
        Future.value(reading(battery: 74 + calls.toDouble()));
  }
}

void viewport(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Widget app({
  SystemRepository? repository,
  bool dark = false,
  GlobalKey? captureKey,
}) => ProviderScope(
  overrides: [
    updateRepositoryProvider.overrideWithValue(FakeUpdatesRepository()),
    themeProvider.overrideWith(dark ? DarkTestTheme.new : TestTheme.new),
    if (repository != null)
      systemRepositoryProvider.overrideWithValue(repository)
    else
      snapshotProvider.overrideWith((ref) async => reading()),
  ],
  child: RepaintBoundary(key: captureKey, child: const PhoneManagerApp()),
);

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 2);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/previews').createSync(recursive: true);
    File('build/previews/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    rendered.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the SDK's offline fonts rather than the square Ahem test glyphs.
    final configFile = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(configFile.readAsStringSync())['packages'] as List;
    final flutter = packages.firstWhere((entry) => entry['name'] == 'flutter');
    final root = Directory.fromUri(
      configFile.absolute.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final fonts = '${root.path}/bin/cache/artifacts/material_fonts';
    for (final entry in [
      (
        'Roboto',
        ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
      ),
      ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ]) {
      final loader = FontLoader(entry.$1);
      for (final file in entry.$2) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(File('$fonts/$file').readAsBytesSync()),
          ),
        );
      }
      await loader.load();
    }
  });
  testWidgets(
    'More remains selected on battery details and Back returns to More',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Test Phone'), findsOneWidget);
      await tester.tap(find.text('Storage'));
      await tester.pumpAndSettle();
      expect(find.text('Storage scanning planned'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Battery Monitor'));
      await tester.pumpAndSettle();
      expect(find.text('75%'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('More for your device.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Refresh executes a repository read and waits for its result', (
    tester,
  ) async {
    final repository = CountingRepository();
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    final pending = Completer<SystemSnapshot>();
    repository.pending = pending;
    await tester.tap(find.byTooltip('Refresh readings'));
    await tester.pump();
    expect(repository.calls, 2);
    expect(find.text('Reading your device…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Refresh readings',
            ),
          )
          .onPressed,
      isNull,
    );
    pending.complete(reading(battery: 76));
    await tester.pumpAndSettle();
    expect(find.text('76%'), findsOneWidget);
    expect(find.text('Capabilities checked'), findsNothing);
  });

  testWidgets('Returning to the app refreshes measurements', (tester) async {
    final repository = CountingRepository();
    await tester.pumpWidget(app(repository: repository));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Compact ${dark ? 'dark' : 'light'} dashboard and secondary screens support 2x text',
      (tester) async {
        viewport(tester, const Size(320, 900), textScale: 2);
        await tester.pumpWidget(app(dark: dark));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(PhoneManagerApp));
        final container = ProviderScope.containerOf(context);
        final router = container.read(routerProvider);
        for (final route in [
          '/dashboard',
          '/processes',
          '/storage',
          '/applications',
          '/more',
          '/more/battery',
          '/more/manufacturer',
          '/more/diagnostics',
          '/more/permissions',
          '/more/advanced',
          '/more/settings',
          '/more/about',
          '/more/updates',
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$route must fit compact screens with large text',
          );
        }
      },
    );
  }

  testWidgets('Navigation remains usable when Android readings fail', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith(TestTheme.new),
          snapshotProvider.overrideWith(
            (ref) async => throw Exception('Disconnected'),
          ),
        ],
        child: const PhoneManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Device readings unavailable'), findsOneWidget);
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    expect(find.text('Application inventory planned'), findsOneWidget);
    expect(find.text('Device readings unavailable'), findsNothing);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('More for your device.'), findsOneWidget);
  });

  testWidgets('Settings reflects theme choice while retaining the More route', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneManagerApp)),
    );
    expect(container.read(themeProvider).requireValue, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('More for your device.'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Dashboard ${dark ? 'dark' : 'light'} preview and readable semantic colors',
      (tester) async {
        viewport(tester, const Size(400, 900));
        final key = GlobalKey();
        await tester.pumpWidget(app(dark: dark, captureKey: key));
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Test Phone'));
        final colors = Theme.of(context).colorScheme;
        double contrast(Color a, Color b) {
          final aLum = a.computeLuminance(), bLum = b.computeLuminance();
          return aLum > bLum
              ? (aLum + 0.05) / (bLum + 0.05)
              : (bLum + 0.05) / (aLum + 0.05);
        }

        expect(
          contrast(colors.onSurfaceVariant, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        for (final accent in Accent.values) {
          expect(
            contrast(accent.foreground(context), accent.background(context)),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'dashboard-${dark ? 'dark' : 'light'}');
      },
    );
  }

  testWidgets('Wide layout provides a sidebar without a bottom bar', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 1000));
    final key = GlobalKey();
    await tester.pumpWidget(app(captureKey: key));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('YOUR DEVICE'), findsOneWidget);
    await tester.tap(find.text('Processes'));
    await tester.pumpAndSettle();
    expect(find.text('Estimated used RAM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    await capture(tester, key, 'dashboard-wide');
  });
}
