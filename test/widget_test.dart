import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phomanachi/core/domain/system_repository.dart';
import 'package:phomanachi/core/platform/system_api.g.dart';
import 'package:phomanachi/features/dashboard/dashboard_screen.dart';
import 'package:phomanachi/features/dashboard/providers.dart';

SystemSnapshot snapshot({int? total, int? available}) => SystemSnapshot(
  contractVersion: 1,
  observedAtMillis: 0,
  manufacturer: 'Test',
  model: 'Device',
  androidVersion: '14',
  apiLevel: 34,
  buildId: 'test',
  notices: [],
  totalMemoryBytes: total,
  availableMemoryBytes: available,
);
void main() {
  test('Unknown and inconsistent memory readings remain unavailable', () {
    expect(estimatedUsedMemory(snapshot()), isNull);
    expect(estimatedUsedMemory(snapshot(total: 10, available: 20)), isNull);
    expect(estimatedUsedMemory(snapshot(total: 100, available: 30)), 70);
    expect(formatBytes(null), 'Unavailable');
    expect(formatBytes(0), '0 B');
  });
  testWidgets('Missing readings show unavailable rather than zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [snapshotProvider.overrideWith((ref) async => snapshot())],
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceScreen(kind: '/dashboard', title: 'Dashboard'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('0 B'), findsNothing);
    expect(find.text('Test Device'), findsOneWidget);
  });
  testWidgets('Native failure offers retry without a crash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          snapshotProvider.overrideWith(
            (ref) async => throw Exception('Disconnected'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ResourceScreen(kind: '/dashboard', title: 'Dashboard'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Device readings unavailable'), findsOneWidget);
    expect(find.byTooltip('Refresh readings'), findsOneWidget);
  });
}
