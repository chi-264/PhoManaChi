import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phomanachi/core/platform/storage_api.g.dart';
import 'package:phomanachi/core/theme/app_theme.dart';
import 'package:phomanachi/features/dashboard/providers.dart';
import 'package:phomanachi/features/storage/storage_controller.dart';
import 'package:phomanachi/features/storage/storage_repository.dart';
import 'package:phomanachi/features/storage/storage_screen.dart';

import 'support/fake_storage.dart';
import 'support/rendering.dart';
import 'app_test.dart' show reading, viewport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  test('Search, categories, large files, duplicates and unknown sizes', () {
    final files = [
      storageFile('small', group: '1'),
      storageFile('large', size: largeFileBytes),
      storageFile('unknown', size: null, category: 'Other'),
    ];
    expect(filterFiles(files, largeOnly: true).map((f) => f.id), ['large']);
    expect(filterFiles(files, duplicatesOnly: true).map((f) => f.id), [
      'small',
    ]);
    expect(filterFiles(files, category: 'Other').single.id, 'unknown');
    expect(filterFiles(files, query: 'SMALL').single.id, 'small');
    expect(filterFiles(files).last.id, 'unknown');
  });
  test('Every duplicate group retains an unselected member, including hidden files', () {
    final files = [
      storageFile('a', group: '1'),
      storageFile('b', group: '1'),
      storageFile('c'),
    ];
    expect(selectionIssue(files, {'a'}), isNull);
    expect(selectionIssue(files, {'a', 'b'}), contains('Keep at least one'));
    expect(selectionIssue(files, {'unknown'}), contains('no longer eligible'));
    expect(
      selectionIssue(List.generate(101, (i) => storageFile('$i')), {
        for (var i = 0; i < 101; i++) '$i',
      }),
      contains('100'),
    );
  });
  test('No automatic deletion; proof review and single explicit confirmation required', () async {
    final repo = FakeStorageRepository(
      initial: storageSnapshot(
        files: [
          storageFile('a', group: '1'),
          storageFile('b', group: '1'),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [storageRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(storageProvider.notifier);
    await controller.refresh();
    controller.select('a', true);
    expect(repo.prepared, 0);
    expect(repo.confirmed, 0);
    await controller.prepare();
    expect(container.read(storageProvider).review?.files.single.id, 'a');
    expect(repo.confirmed, 0);
    await controller.confirm();
    await controller.confirm();
    expect(repo.confirmed, 1);
    expect(container.read(storageProvider).canSelect, isFalse);
    expect(container.read(storageProvider).selected, isEmpty);
  });
  test('Whole duplicate group cannot reach native review', () async {
    final repo = FakeStorageRepository(
      initial: storageSnapshot(
        files: [
          storageFile('a', group: '1'),
          storageFile('b', group: '1'),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [storageRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(storageProvider.notifier);
    await controller.refresh();
    controller.select('a', true);
    controller.select('b', true);
    await controller.prepare();
    expect(repo.prepared, 0);
  });
  test(
    'Changed job clears selection; cancellation results remain read-only',
    () async {
      final repo = FakeStorageRepository(
        initial: storageSnapshot(files: [storageFile('a')]),
      );
      final container = ProviderContainer(
        overrides: [storageRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final controller = container.read(storageProvider.notifier);
      await controller.refresh();
      controller.select('a', true);
      repo.current = storageSnapshot(job: 'job-2', files: [storageFile('a')]);
      await controller.refresh();
      expect(container.read(storageProvider).selected, isEmpty);
      await controller.cancel();
      controller.select('a', true);
      expect(container.read(storageProvider).selected, isEmpty);
      expect(container.read(storageProvider).canSelect, isFalse);
    },
  );
  test('Canceled picker retains old results and selection', () async {
    final repo = FakeStorageRepository(
      initial: storageSnapshot(
        files: [storageFile('a')],
        message: 'Selection canceled. Previous results retained.',
      ),
    );
    final container = ProviderContainer(
      overrides: [storageRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final controller = container.read(storageProvider.notifier);
    await controller.refresh();
    controller.select('a', true);
    await controller.chooseFolder();
    expect(container.read(storageProvider).selected, {'a'});
    expect(repo.confirmed, 0);
  });
  test(
    'Revoked access fails review without creating a deletion token',
    () async {
      final repo = FakeStorageRepository(
        initial: storageSnapshot(files: [storageFile('a')]),
      )..failPrepare = true;
      final container = ProviderContainer(
        overrides: [storageRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final controller = container.read(storageProvider.notifier);
      await controller.refresh();
      controller.select('a', true);
      await controller.prepare();
      await controller.confirm();
      expect(container.read(storageProvider).review, isNull);
      expect(
        container.read(storageProvider).issue,
        contains('access was lost'),
      );
      expect(repo.confirmed, 0);
    },
  );
  testWidgets(
    'Busy scanning polls in foreground and stops polling in background',
    (tester) async {
      final repo = FakeStorageRepository(
        initial: storageSnapshot(busy: true, phase: ScanPhase.scanning),
      );
      final container = ProviderContainer(
        overrides: [storageRepositoryProvider.overrideWithValue(repo)],
      );
      final controller = container.read(storageProvider.notifier);
      await tester.pump();
      await controller.refresh();
      final reads = repo.reads;
      await tester.pump(const Duration(seconds: 2));
      expect(repo.reads, greaterThan(reads));
      controller.setForeground(false);
      final paused = repo.reads;
      await tester.pump(const Duration(seconds: 3));
      expect(repo.reads, paused);
      container.dispose();
    },
  );
  testWidgets('Stop remains available during a pending proof review', (
    tester,
  ) async {
    final repo = FakeStorageRepository(
      initial: storageSnapshot(files: [storageFile('a')]),
    )..pendingReview = Completer<CleanupReview>();
    final container = ProviderContainer(
      overrides: [storageRepositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(storageProvider.notifier);
    await controller.refresh();
    controller.select('a', true);
    final preparing = controller.prepare();
    await tester.pump();
    expect(container.read(storageProvider).busy, isTrue);
    await controller.cancel();
    expect(repo.canceled, 1);
    repo.pendingReview!.completeError(StateError('Canceled'));
    await preparing;
    expect(container.read(storageProvider).review, isNull);
    expect(repo.confirmed, 0);
    container.dispose();
  });
  Widget screen(
    FakeStorageRepository repo, {
    bool dark = false,
    GlobalKey? key,
  }) => ProviderScope(
    overrides: [
      storageRepositoryProvider.overrideWithValue(repo),
      snapshotProvider.overrideWith((ref) async => reading()),
    ],
    child: MaterialApp(
      theme: phoneManagerTheme(dark ? Brightness.dark : Brightness.light),
      home: RepaintBoundary(
        key: key,
        child: const Scaffold(body: StorageScreen()),
      ),
    ),
  );
  testWidgets(
    'Access selection is explicit and clearing results does not delete',
    (tester) async {
      final repo = FakeStorageRepository();
      await tester.pumpWidget(screen(repo));
      await tester.pumpAndSettle();
      expect(repo.folders + repo.files + repo.media + repo.confirmed, 0);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(repo.folders, 1);
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      expect(repo.files, 1);
      await tester.tap(find.text('Scan media library'));
      await tester.pumpAndSettle();
      expect(repo.media, 1);
      expect(repo.confirmed, 0);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'Storage ${dark ? 'dark' : 'light'} wraps at 320px with 2x text and reports real outcomes',
      (tester) async {
        viewport(tester, const Size(320, 900), textScale: 2);
        final repo = FakeStorageRepository(
          initial: storageSnapshot(
            files: [
              storageFile('a', group: '1'),
              storageFile('b', group: '1'),
            ],
            requiresRescan: true,
            cleanup: cleanupReport(),
          ),
        );
        final key = GlobalKey();
        await tester.pumpWidget(screen(repo, dark: dark, key: key));
        await tester.pumpAndSettle();
        await capture(tester, key, 'storage-${dark ? 'dark' : 'light'}');
        final scroll = find.byType(CustomScrollView);
        for (var i = 0; i < 25; i++) {
          await tester.drag(scroll, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(repo.confirmed, 0);
      },
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      'Storage file list ${dark ? 'dark' : 'light'} preview and checkbox review',
      (tester) async {
        viewport(tester, const Size(400, 900));
        final repo = FakeStorageRepository(
          initial: storageSnapshot(
            files: [
              storageFile(
                'holiday-original',
                group: '1',
                size: largeFileBytes,
                category: 'Videos',
              ),
              storageFile(
                'holiday-copy',
                group: '1',
                size: largeFileBytes,
                category: 'Videos',
              ),
              storageFile('notes'),
            ],
          ),
        );
        final key = GlobalKey();
        await tester.pumpWidget(screen(repo, dark: dark, key: key));
        await tester.pumpAndSettle();
        await capture(
          tester,
          key,
          'storage-overview-${dark ? 'dark' : 'light'}',
        );
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(find.text('holiday-copy.txt'), findsOneWidget);
        await capture(tester, key, 'storage-files-${dark ? 'dark' : 'light'}');
        final checkbox = find.byWidgetPredicate(
          (widget) =>
              widget is Checkbox &&
              widget.semanticLabel == 'Select holiday-copy.txt',
        );
        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(StorageScreen)),
        );
        expect(container.read(storageProvider).selected, {'holiday-copy'});
        expect(repo.confirmed, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Review UI has a separate permanent-delete confirmation and cancel',
    (tester) async {
      final repo = FakeStorageRepository(
        initial: storageSnapshot(files: [storageFile('a')]),
      );
      await tester.pumpWidget(screen(repo));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorageScreen)),
      );
      final controller = container.read(storageProvider.notifier);
      controller.select('a', true);
      await controller.prepare();
      await tester.pumpAndSettle();
      expect(repo.confirmed, 0);
      await tester.ensureVisible(find.text('Cancel review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel review'));
      await tester.pumpAndSettle();
      expect(repo.discarded, 1);
      expect(repo.confirmed, 0);
      await controller.prepare();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete reviewed files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete reviewed files'));
      await tester.pumpAndSettle();
      expect(repo.confirmed, 1);
      expect(find.text('Confirmed deleted logical bytes'), findsOneWidget);
      expect(find.text('−1.0 KiB'), findsOneWidget);
    },
  );
}
