import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import 'journal_repository.dart';

class JournalDetailScreen extends ConsumerStatefulWidget {
  const JournalDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<JournalDetailScreen> createState() =>
      _JournalDetailScreenState();
}

class _JournalDetailScreenState extends ConsumerState<JournalDetailScreen> {
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(String url) async {
    if (_controller != null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: FutureBuilder(
            future: ref.read(journalRepositoryProvider).getJournal(widget.id),
            builder: (context, snapshot) {
              final entry = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (entry == null) {
                return const Center(child: Text('Journal not found.'));
              }
              _loadVideo(entry.videoUrl);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SectionLabel('Journal playback'),
                  const SizedBox(height: 8),
                  Text(
                    'Reflection',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM d, y - h:mm a').format(entry.recordedAt),
                  ),
                  const SizedBox(height: 18),
                  SolenneCard(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: _controller?.value.aspectRatio ?? 9 / 16,
                        child: _controller == null
                            ? const ColoredBox(
                                color: AppColors.royalBlue,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller!),
                                  IconButton.filled(
                                    iconSize: 42,
                                    onPressed: () {
                                      setState(() {
                                        _controller!.value.isPlaying
                                            ? _controller!.pause()
                                            : _controller!.play();
                                      });
                                    },
                                    icon: Icon(
                                      _controller!.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SolenneCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Prompt'),
                        const SizedBox(height: 10),
                        Text(
                          entry.prompt,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        Text('Duration: ${entry.durationSeconds}s'),
                        Text('Upload: ${entry.uploadStatus}'),
                        Text(
                          'Analysis: ${entry.analysisStatus.replaceAll('_', ' ')}',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
