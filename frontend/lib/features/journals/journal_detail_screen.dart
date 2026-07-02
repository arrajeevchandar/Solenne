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
        showGrid: true,
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
                children: [
                  SolenneSectionTitle(
                    eyebrow: DateFormat(
                      'MMMM d, y - h:mm a',
                    ).format(entry.recordedAt),
                    title: 'Reflection',
                    subtitle: entry.prompt,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: AspectRatio(
                      aspectRatio: _controller?.value.aspectRatio ?? 9 / 16,
                      child: _controller == null
                          ? const ColoredBox(
                              color: AppColors.cardElevated,
                              child: Center(child: CircularProgressIndicator()),
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
                  const SizedBox(height: 18),
                  SolenneCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.prompt,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SolenneStatusChip(
                              label: '${entry.durationSeconds}s',
                              color: AppColors.aqua,
                              icon: Icons.timer_outlined,
                            ),
                            SolenneStatusChip(
                              label: entry.uploadStatus,
                              color: AppColors.violet,
                              icon: Icons.cloud_done_outlined,
                            ),
                            SolenneStatusChip(
                              label: entry.analysisStatus.replaceAll('_', ' '),
                              color: AppColors.coral,
                              icon: Icons.auto_awesome_outlined,
                            ),
                          ],
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
