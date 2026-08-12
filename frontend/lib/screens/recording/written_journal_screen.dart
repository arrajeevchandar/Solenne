import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../theme/app_theme.dart';
import 'entry_saved_screen.dart';

class WrittenJournalScreen extends ConsumerStatefulWidget {
  const WrittenJournalScreen({super.key});

  @override
  ConsumerState<WrittenJournalScreen> createState() =>
      _WrittenJournalScreenState();
}

class _WrittenJournalScreenState extends ConsumerState<WrittenJournalScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late final String _journalId;
  bool _reviewing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _journalId = DateTime.now().microsecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _bodyController.text.trim();
    if (user == null || text.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = JournalEntry(
        id: _journalId,
        userId: user.uid,
        prompt: 'What has been on your mind today?',
        recordedAt: DateTime.now(),
        durationSeconds: 0,
        cloudinaryPublicId: '',
        videoUrl: '',
        audioUrl: '',
        thumbnailUrl: '',
        uploadStatus: 'saved',
        analysisStatus: 'queued',
        analysisStep: 'queued',
        analysisVersion: JournalRepository.analysisVersion,
        entryType: 'written',
        writtenText: text,
        mediaMimeType: 'text/plain',
        analysisModalities: const ['text'],
        title: _titleController.text.trim(),
      );
      await ref.read(journalRepositoryProvider).saveJournal(entry);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => EntrySavedScreen(entryId: _journalId),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _bodyController.text.trim();
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: _reviewing ? 'Back to editing' : 'Back',
                      onPressed: _saving
                          ? null
                          : () => _reviewing
                                ? setState(() => _reviewing = false)
                                : Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    Text(
                      'WRITTEN JOURNAL',
                      style: AppTextStyles.mono(fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _reviewing ? 'Keep these words?' : 'A page for today',
                  style: AppTextStyles.display(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  _reviewing
                      ? 'Review the entry before analysis begins.'
                      : 'Write only what you want to keep.',
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.shellstone.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_reviewing) ...[
                  SolenneGlass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    borderRadius: 18,
                    child: TextField(
                      controller: _titleController,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        hintText: 'Give this entry a name (optional)',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: SolenneGlass(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: _reviewing
                        ? SingleChildScrollView(
                            child: SelectableText(
                              body,
                              style: AppTextStyles.body(fontSize: 16),
                            ),
                          )
                        : TextField(
                            controller: _bodyController,
                            onChanged: (_) => setState(() {}),
                            maxLength: 10000,
                            expands: true,
                            minLines: null,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'What is sitting with you?',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${_wordCount(body)} words · ${body.length}/10000',
                      style: AppTextStyles.mono(fontSize: 8),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: body.isEmpty || _saving
                          ? null
                          : _reviewing
                          ? _save
                          : () => setState(() => _reviewing = true),
                      icon: Icon(
                        _reviewing
                            ? Icons.auto_awesome_rounded
                            : Icons.arrow_forward_rounded,
                        size: 17,
                      ),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : _reviewing
                            ? 'Save & analyze'
                            : 'Review',
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.quicksand,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _wordCount(String value) =>
      RegExp(r'\S+').allMatches(value).length;
}
