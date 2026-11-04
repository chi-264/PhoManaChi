import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phomanachi/app/app.dart';
import 'package:phomanachi/app/settings.dart';
import 'package:phomanachi/core/platform/system_api.g.dart';
import 'package:phomanachi/features/dashboard/providers.dart';

class TestTheme extends ThemeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.system;
}

void main() {
  testWidgets('Navigation exposes honest feature states and battery readings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith(TestTheme.new),
          snapshotProvider.overrideWith(
            (ref) async => SystemSnapshot(
              contractVersion: 1,
              observedAtMillis: 0,
              manufacturer: 'Test',
              model: 'Phone',
              androidVersion: '14',
              apiLevel: 34,
              buildId: 'test',
              batteryPercent: 75,
              batteryState: 'Discharging',
              notices: [],
            ),
          ),
        ],
        child: const PhoneManagerApp(),
      ),
    );
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
    expect(find.text('Discharging'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
