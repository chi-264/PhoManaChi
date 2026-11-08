import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/system_repository.dart';
import '../../core/platform/storage_api.g.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/components.dart';
import '../dashboard/providers.dart';
import 'storage_controller.dart';
import 'storage_repository.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});
  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  String _query = '', _category = 'All';
  bool _large = false, _duplicates = false;
  FileSort _sort = FileSort.largest;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(storageProvider);
    final controller = ref.read(storageProvider.notifier);
    final scan = value.snapshot;
    final files = scan?.files ?? <StorageFile>[];
    final filtered = filterFiles(
      files,
      query: _query,
      category: _category,
      largeOnly: _large,
      duplicatesOnly: _duplicates,
      sort: _sort,
    );
    if (_duplicates) {
      filtered.sort(
        (a, b) => (a.duplicateGroup ?? '').compareTo(b.duplicateGroup ?? ''),
      );
    }
    final groups = <String, List<StorageFile>>{};
    for (final file in files) {
      if (file.duplicateGroup case final String group) {
        groups.putIfAbsent(group, () => []).add(file);
      }
    }
    final capacity = ref.watch(snapshotProvider).asData?.value;
    final selectedBytes = files
        .where((f) => value.selected.contains(f.id))
        .fold<int>(0, (sum, f) => sum + (f.sizeBytes ?? 0));
    final selectionProblem = selectionIssue(files, value.selected);
    Widget padded(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 16), child: child);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth > 1160
            ? (constraints.maxWidth - 1120) / 2
            : 20.0;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 24, inset, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeading(
                      title: 'Your files, your choice.',
                      subtitle: 'Analyze chosen storage and review individual files before cleanup.',
                      action: IconButton(
                        tooltip: 'Refresh storage status',
                        onPressed: controller.refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                    if (capacity != null)
                      padded(
                        DetailCard(
                          rows: [
                            (
                              'Internal storage available',
                              formatBytes(capacity.availableStorageBytes),
                            ),
                            (
                              'Internal storage capacity',
                              formatBytes(capacity.totalStorageBytes),
                            ),
                          ],
                        ),
                      ),
                    padded(
                      const InfoNotice(
                        'Choose what to scan',
                        'Folder and file access comes from Android’s picker. Media access covers only permitted images, videos, and audio. Results describe this scope, not the whole phone. No files are selected or deleted automatically.',
                        icon: Icons.folder_open_rounded,
                      ),
                    ),
                    padded(
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: !value.busy && value.review == null
                                ? controller.chooseFolder
                                : null,
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('Choose folder'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !value.busy && value.review == null
                                ? controller.chooseFiles
                                : null,
                            icon: const Icon(Icons.file_open_outlined),
                            label: const Text('Choose files'),
                          ),
                          OutlinedButton.icon(
                            onPressed: !value.busy && value.review == null
                                ? controller.scanMedia
                                : null,
                            icon: const Icon(Icons.perm_media_outlined),
                            label: const Text('Scan media library'),
                          ),
                        ],
                      ),
                    ),
                    if (value.issue != null)
                      padded(
                        InfoNotice(
                          'Request needs attention',
                          value.issue!,
                          accent: Accent.warning,
                        ),
                      ),
                    if (scan == null)
                      padded(const Text('Connecting to Android storage…')),
                    if (scan != null) ...[
                      padded(
                        DetailCard(
                          rows: [
                            ('Scope', scan.scopeLabel),
                            ('Scan status', scan.phase.name),
                            (
                              'Files found',
                              '${files.length} · ${formatBytes(files.fold<int>(0, (s, f) => s + (f.sizeBytes ?? 0)))} known logical size',
                            ),
                            (
                              'Unknown file sizes',
                              '${files.where((f) => f.sizeBytes == null).length}',
                            ),
                            (
                              'SHA-256 comparisons',
                              '${scan.hashedFiles} files hashed · ${scan.failedFiles} hash failures',
                            ),
                            ('Verified duplicate groups', '${groups.length}'),
                            (
                              'Scope warnings',
                              '${scan.warningCount} · coverage may be incomplete',
                            ),
                          ],
                        ),
                      ),
                      if (scan.message != null) padded(Text(scan.message!)),
                      for (final issue in scan.issues) padded(Text('• $issue')),
                      if (value.busy) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        padded(
                          OutlinedButton.icon(
                            onPressed: controller.cancel,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Stop operation'),
                          ),
                        ),
                      ],
                      if (scan.requiresRescan)
                        padded(
                          const InfoNotice(
                            'Fresh scan required',
                            'Review the cleanup results, then rescan before selecting more files.',
                            accent: Accent.warning,
                          ),
                        ),
                      if (scan.jobId != null)
                        padded(
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: !value.busy && value.review == null
                                    ? controller.rescan
                                    : null,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Rescan selected scope'),
                              ),
                              TextButton(
                                onPressed: !value.busy && value.review == null
                                    ? controller.forget
                                    : null,
                                child: const Text('Forget scan results'),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (value.review case final CleanupReview review)
                      padded(
                        _ReviewPanel(
                          review: review,
                          busy: value.busy,
                          confirm: controller.confirm,
                          cancel: controller.discard,
                        ),
                      ),
                    if (scan?.cleanup case final CleanupReport report)
                      padded(_ReportPanel(report: report)),
                    if (files.isNotEmpty) ...[
                      const SectionHeading(
                        'Explore this scan',
                        subtitle: 'Category totals include known sizes only. Large files are at least 100 MiB.',
                      ),
                      padded(
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in fileCategories.skip(1))
                              Chip(
                                label: Text(
                                  '$category · ${files.where((f) => f.category == category).length} · ${formatBytes(files.where((f) => f.category == category).fold<int>(0, (s, f) => s + (f.sizeBytes ?? 0)))}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      padded(
                        TextField(
                          onChanged: (query) => setState(() => _query = query),
                          decoration: const InputDecoration(
                            labelText: 'Search files or locations',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      padded(
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            DropdownButton<String>(
                              value: _category,
                              isExpanded: false,
                              items: [
                                for (final category in fileCategories)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                              ],
                              onChanged: (category) =>
                                  setState(() => _category = category!),
                            ),
                            DropdownButton<FileSort>(
                              value: _sort,
                              items: [
                                for (final sort in FileSort.values)
                                  DropdownMenuItem(
                                    value: sort,
                                    child: Text(switch (sort) {
                                      FileSort.largest => 'Largest first',
                                      FileSort.name => 'Name',
                                      FileSort.newest => 'Newest first',
                                    }),
                                  ),
                              ],
                              onChanged: (sort) =>
                                  setState(() => _sort = sort!),
                            ),
                            FilterChip(
                              label: const Text('Large files'),
                              selected: _large,
                              onSelected: (v) => setState(() => _large = v),
                            ),
                            FilterChip(
                              label: const Text('Duplicate groups'),
                              selected: _duplicates,
                              onSelected: (v) =>
                                  setState(() => _duplicates = v),
                            ),
                          ],
                        ),
                      ),
                      if (_duplicates)
                        padded(
                          const Text(
                            'Groups contain matching sizes and SHA-256 content at scan time. “Suggested keep” is an unselected starting point; keep at least one verifiable copy per group.',
                          ),
                        ),
                      padded(
                        DetailCard(
                          rows: [
                            (
                              'Selected across all filters',
                              '${value.selected.length} files · ${formatBytes(selectedBytes)}',
                            ),
                            ('Review limit', '100 files per review'),
                          ],
                        ),
                      ),
                      if (selectionProblem != null)
                        padded(Text(selectionProblem)),
                      padded(
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  value.canSelect && selectionProblem == null
                                  ? controller.prepare
                                  : null,
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Review selected files'),
                            ),
                            TextButton(
                              onPressed:
                                  value.canSelect && value.selected.isNotEmpty
                                  ? controller.clearSelection
                                  : null,
                              child: const Text('Clear selection'),
                            ),
                          ],
                        ),
                      ),
                      SectionHeading(
                        '${filtered.length} matching files',
                        subtitle: value.canSelect
                            ? 'Select only files you intend to permanently delete.'
                            : 'Results are read-only while busy or until a fresh scan completes.',
                      ),
                    ] else if (scan != null && !value.busy)
                      padded(
                        const Text(
                          'No files to display. Choose access above to start a scan.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 32),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final file = filtered[index];
                  final group = file.duplicateGroup;
                  final suggested =
                      group != null && groups[group]!.first.id == file.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            semanticLabel: 'Select ${file.name}',
                            value: value.selected.contains(file.id),
                            onChanged: value.canSelect && file.deleteSupported
                                ? (selected) =>
                                      controller.select(file.id, selected!)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${file.category} · ${file.sizeBytes == null ? 'Size unknown' : formatBytes(file.sizeBytes)}',
                                ),
                                Text(file.location),
                                Text(
                                  'Modified: ${file.modifiedMillis == null ? 'Unknown' : DateTime.fromMillisecondsSinceEpoch(file.modifiedMillis!).toLocal().toString()}',
                                ),
                                if (group != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Duplicate group $group · ${groups[group]!.length} copies${suggested ? ' · Suggested keep' : ''}',
                                      style: TextStyle(
                                        color: Accent.purple.foreground(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!file.deleteSupported)
                                  Text(
                                    file.deleteReason,
                                    style: TextStyle(
                                      color: Accent.warning.foreground(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.review,
    required this.busy,
    required this.confirm,
    required this.cancel,
  });
  final CleanupReview review;
  final bool busy;
  final VoidCallback confirm, cancel;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading('Confirm permanent deletion'),
          Text(
            '${review.files.length} reviewed files · ${formatBytes(review.totalBytes)} logical size',
          ),
          const SizedBox(height: 8),
          const Text(
            'These files will be permanently deleted. This app cannot undo the operation. Android may request additional access. Files and retained duplicate copies are checked again before deletion.',
          ),
          Text(
            'Review expires: ${DateTime.fromMillisecondsSinceEpoch(review.expiresAtMillis).toLocal()}',
          ),
          for (final file in review.files)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${file.name}\n${file.location} · ${formatBytes(file.sizeBytes ?? 0)}',
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : confirm,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete reviewed files'),
              ),
              OutlinedButton(
                onPressed: busy ? null : cancel,
                child: const Text('Cancel review'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.report});
  final CleanupReport report;
  @override
  Widget build(BuildContext context) {
    final before = report.internalFreeBefore, after = report.internalFreeAfter;
    final delta = before != null && after != null ? after - before : null;
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text('Cleanup result · ${report.phase.name}'),
      children: [
        Text(report.message),
        Text(
          'Started: ${DateTime.fromMillisecondsSinceEpoch(report.startedAtMillis).toLocal()}',
        ),
        const SizedBox(height: 12),
        DetailCard(
          rows: [
            ('Requested', '${report.requested}'),
            ('Confirmed deleted', '${report.deleted}'),
            ('Skipped', '${report.skipped}'),
            ('Failed', '${report.failed}'),
            ('Unverified', '${report.unverified}'),
            (
              'Confirmed deleted logical bytes',
              formatBytes(report.deletedBytes),
            ),
            (
              'Internal free space before',
              before == null ? 'Unavailable' : formatBytes(before),
            ),
            (
              'Internal free space after',
              after == null ? 'Unavailable' : formatBytes(after),
            ),
            (
              'Observed internal free-space change',
              delta == null
                  ? 'Unavailable'
                  : '${delta < 0 ? '−' : '+'}${formatBytes(delta.abs())}',
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Internal free-space change is a separate device observation. Other apps, providers, removable storage, and filesystem allocation can make it differ from deleted logical bytes. Unverified results add no deleted bytes.',
          ),
        ),
        for (final item in report.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${item.name} · ${item.outcome}'),
            subtitle: Text(item.message),
          ),
      ],
    );
  }
}
