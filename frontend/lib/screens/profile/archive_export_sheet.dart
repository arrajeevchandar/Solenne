import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/archive/archive_repository.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../theme/app_theme.dart';

Future<void> showArchiveExportSheet(
  BuildContext context, {
  required ExportKind initialKind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _ArchiveExportSheet(initialKind: initialKind),
  );
}

class _ArchiveExportSheet extends ConsumerStatefulWidget {
  const _ArchiveExportSheet({required this.initialKind});

  final ExportKind initialKind;

  @override
  ConsumerState<_ArchiveExportSheet> createState() =>
      _ArchiveExportSheetState();
}

class _ArchiveExportSheetState extends ConsumerState<_ArchiveExportSheet> {
  late ExportKind _kind;
  final Set<String> _selectedIds = {};
  String? _jobId;
  bool _checkingActive = true;
  bool _submitting = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _resumeActiveExport();
  }

  Future<void> _resumeActiveExport() async {
    try {
      final active = await ref
          .read(archiveRepositoryProvider)
          .latestActiveExport();
      if (!mounted) return;
      setState(() {
        if (active != null) {
          _jobId = active.id;
          _kind = active.exportKind;
        }
        _checkingActive = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingActive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SolenneGlass(
          borderRadius: 30,
          padding: EdgeInsets.zero,
          tint: AppColors.sapphire,
          child: _checkingActive
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _jobId == null
              ? _buildSelection(controller)
              : _buildJob(controller, _jobId!),
        ),
      ),
    );
  }

  Widget _buildSelection(ScrollController controller) {
    final journals = ref.watch(journalStreamProvider);
    return journals.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => _CenteredMessage(
        title: 'Your archive could not be opened',
        detail: 'Close this panel and try again.',
      ),
      data: (entries) {
        final selectedEntries = entries
            .where((entry) => _selectedIds.contains(entry.id))
            .toList(growable: false);
        final canSubmit =
            selectedEntries.isNotEmpty &&
            selectedEntries.any(
              (entry) => ArchiveExportPolicy.hasRequestedContent(entry, _kind),
            );
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(child: _sheetHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _modeSelector(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} OF 50 SELECTED',
                        style: AppTextStyles.mono(
                          fontSize: 8,
                          color: AppColors.quicksand.withValues(alpha: 0.76),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: entries.isEmpty
                          ? null
                          : () => _toggleSelectAll(entries),
                      child: Text(
                        _selectedIds.isEmpty ? 'Select all' : 'Clear',
                        style: AppTextStyles.body(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CenteredMessage(
                  title: 'No sessions yet',
                  detail: 'Record a reflection before creating an archive.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _SessionTile(
                      entry: entry,
                      kind: _kind,
                      selected: _selectedIds.contains(entry.id),
                      selectionEnabled:
                          _selectedIds.contains(entry.id) ||
                          _selectedIds.length < 50,
                      onTap: () => _toggleEntry(entry.id),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectionNote(selectedEntries),
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.shellstone.withValues(alpha: 0.68),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: canSubmit && !_submitting
                          ? _createExport
                          : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: Text(
                        _submitting
                            ? 'Preparing request…'
                            : 'Create private ZIP',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJob(ScrollController controller, String jobId) {
    final jobState = ref.watch(exportJobStreamProvider(jobId));
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppColors.shellstone.withValues(alpha: 0.28),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your private archive',
          style: AppTextStyles.display(fontSize: 34),
        ),
        const SizedBox(height: 6),
        Text(
          'ONE DOWNLOAD · AUTO-REMOVED',
          style: AppTextStyles.mono(
            fontSize: 8,
            color: AppColors.quicksand.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 28),
        jobState.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => _jobError('The export status could not be loaded.'),
          data: (job) => job == null
              ? _jobError('This export is no longer available.')
              : _jobContent(job),
        ),
      ],
    );
  }

  Widget _jobContent(ExportJob job) {
    if (job.status == 'queued' || job.status == 'processing') {
      final progress = job.selectedCount == 0
          ? null
          : (job.completedItems / job.selectedCount).clamp(0.0, 1.0);
      return SolenneGlass(
        borderRadius: 24,
        tint: AppColors.royalBlue,
        child: Column(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.quicksand,
              size: 34,
            ),
            const SizedBox(height: 15),
            Text(
              job.status == 'queued'
                  ? 'Your export is queued'
                  : 'Gathering your sessions',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 25),
            ),
            const SizedBox(height: 8),
            Text(
              '${job.completedItems} of ${job.selectedCount} sessions reviewed',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(value: progress),
          ],
        ),
      );
    }
    if (job.isReady) {
      return Column(
        children: [
          SolenneGlass(
            borderRadius: 24,
            tint: AppColors.royalBlue,
            child: Column(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.quicksand,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  'Ready for you',
                  style: AppTextStyles.display(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  '${job.includedCount} files included'
                  '${job.skippedCount > 0 ? ' · ${job.skippedCount} skipped' : ''}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.shellstone.withValues(alpha: 0.74),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Opening the ZIP uses its only download. Keep the save or share panel open until you choose where it goes.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.shellstone.withValues(alpha: 0.62),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _downloading ? null : () => _download(job),
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _downloading ? 'Downloading once…' : 'Download and save',
              ),
            ),
          ),
        ],
      );
    }
    if (job.status == 'failed') {
      return _jobError(
        job.errorMessage ?? 'The archive could not be created.',
        allowNewExport: true,
      );
    }
    return _jobError(
      job.status == 'consumed'
          ? 'This one-time ZIP has been downloaded and removed.'
          : 'This export has expired and was removed.',
      allowNewExport: true,
    );
  }

  Widget _jobError(String message, {bool allowNewExport = false}) {
    return Column(
      children: [
        SolenneGlass(
          borderRadius: 24,
          tint: AppColors.royalBlue,
          child: Column(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.quicksand,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.shellstone.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
        if (allowNewExport) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() {
              _jobId = null;
              _selectedIds.clear();
            }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Choose sessions again'),
          ),
        ],
      ],
    );
  }

  Widget _sheetHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppColors.shellstone.withValues(alpha: 0.28),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose what to carry',
            style: AppTextStyles.display(fontSize: 34),
          ),
          const SizedBox(height: 5),
          Text(
            'SELECT UP TO 50 REFLECTIONS',
            style: AppTextStyles.mono(
              fontSize: 8,
              color: AppColors.quicksand.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return SegmentedButton<ExportKind>(
      segments: ExportKind.values
          .map(
            (kind) => ButtonSegment<ExportKind>(
              value: kind,
              label: Text(kind.label),
              icon: Icon(switch (kind) {
                ExportKind.audio => Icons.graphic_eq_rounded,
                ExportKind.transcript => Icons.subject_rounded,
                ExportKind.both => Icons.all_inbox_rounded,
              }),
            ),
          )
          .toList(growable: false),
      selected: {_kind},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _kind = selection.first);
      },
    );
  }

  void _toggleSelectAll(List<JournalEntry> entries) {
    setState(() {
      if (_selectedIds.isNotEmpty) {
        _selectedIds.clear();
        return;
      }
      _selectedIds.addAll(entries.take(50).map((entry) => entry.id));
    });
  }

  void _toggleEntry(String id) {
    setState(() {
      if (!_selectedIds.remove(id) && _selectedIds.length < 50) {
        _selectedIds.add(id);
      }
    });
  }

  String _selectionNote(List<JournalEntry> selected) {
    if (selected.isEmpty) {
      return 'Your selections stay private to your account.';
    }
    final missing = selected
        .where((entry) => !entry.transcript.isAvailable)
        .length;
    if (_kind != ExportKind.audio && missing > 0) {
      return '$missing selected ${missing == 1 ? 'session has' : 'sessions have'} no transcript yet and will be skipped for text.';
    }
    return 'The ZIP disappears after its first download or after 24 hours.';
  }

  Future<void> _createExport() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final id = await ref
          .read(archiveRepositoryProvider)
          .createExport(
            journalIds: _selectedIds.toList(growable: false),
            exportKind: _kind,
          );
      if (!mounted) return;
      setState(() {
        _jobId = id;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(_friendlyError(error));
    }
  }

  Future<void> _download(ExportJob job) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final archive = await ref
          .read(archiveRepositoryProvider)
          .downloadExport(job);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [archive.file],
          fileNameOverrides: [archive.filename],
          title: 'Save your Solenne archive',
          subject: 'Solenne journal archive',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your save and share options were opened.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(_friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^.*Exception: '), '');
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.entry,
    required this.kind,
    required this.selected,
    required this.selectionEnabled,
    required this.onTap,
  });

  final JournalEntry entry;
  final ExportKind kind;
  final bool selected;
  final bool selectionEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final transcriptMissing =
        kind != ExportKind.audio && !entry.transcript.isAvailable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectionEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? AppColors.sapphire.withValues(alpha: 0.36)
                  : AppColors.royalBlue.withValues(alpha: 0.22),
              border: Border.all(
                color: selected
                    ? AppColors.quicksand.withValues(alpha: 0.48)
                    : AppColors.shellstone.withValues(alpha: 0.13),
              ),
            ),
            child: Row(
              children: [
                _SessionThumbnail(entry: entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.swanWing.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM d · h:mm a').format(entry.recordedAt)}  ·  ${_duration(entry.durationSeconds)}',
                        style: AppTextStyles.mono(
                          fontSize: 7,
                          color: AppColors.shellstone.withValues(alpha: 0.56),
                        ),
                      ),
                      if (transcriptMissing)
                        Text(
                          'Transcript unavailable · text will be skipped',
                          style: AppTextStyles.body(
                            fontSize: 10,
                            color: AppColors.quicksand.withValues(alpha: 0.72),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? AppColors.quicksand
                      : AppColors.shellstone.withValues(alpha: 0.42),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}

class _SessionThumbnail extends StatelessWidget {
  const _SessionThumbnail({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final url = entry.effectiveThumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 54,
        height: 54,
        color: AppColors.royalBlue.withValues(alpha: 0.5),
        child: url.isEmpty
            ? const Icon(Icons.videocam_outlined, color: AppColors.quicksand)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.quicksand,
                ),
              ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 25),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.shellstone.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
