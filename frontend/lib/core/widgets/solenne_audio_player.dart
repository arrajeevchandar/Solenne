import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../theme/app_theme.dart';

class SolenneAudioPlayer extends StatefulWidget {
  const SolenneAudioPlayer({
    super.key,
    required this.source,
    this.localFile = false,
  });

  final String source;
  final bool localFile;

  @override
  State<SolenneAudioPlayer> createState() => _SolenneAudioPlayerState();
}

class _SolenneAudioPlayerState extends State<SolenneAudioPlayer> {
  late final AudioPlayer _player;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.localFile && !widget.source.startsWith('blob:')) {
        await _player.setFilePath(widget.source);
      } else {
        await _player.setUrl(widget.source);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Audio could not be loaded.');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SolenneGlass(
    padding: const EdgeInsets.all(16),
    borderRadius: 20,
    tint: AppColors.sapphire,
    child: _error != null
        ? Row(
            children: [
              const Icon(Icons.error_outline_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Audio could not be loaded.',
                  style: AppTextStyles.body(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Retry',
                onPressed: () {
                  setState(() => _error = null);
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          )
        : Column(
            children: [
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = _player.duration ?? Duration.zero;
                  final max = duration.inMilliseconds
                      .toDouble()
                      .clamp(1, double.infinity)
                      .toDouble();
                  return Column(
                    children: [
                      Slider(
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(0, max)
                            .toDouble(),
                        max: max,
                        onChanged: (value) =>
                            _player.seek(Duration(milliseconds: value.round())),
                        activeColor: AppColors.quicksand,
                        inactiveColor: AppColors.shellstone.withValues(
                          alpha: 0.18,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _duration(position),
                            style: AppTextStyles.mono(fontSize: 8),
                          ),
                          const Spacer(),
                          Text(
                            _duration(duration),
                            style: AppTextStyles.mono(fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing = state?.playing ?? false;
                  final complete =
                      state?.processingState == ProcessingState.completed;
                  return IconButton.filled(
                    tooltip: complete
                        ? 'Replay'
                        : playing
                        ? 'Pause'
                        : 'Play',
                    onPressed: () async {
                      if (complete) await _player.seek(Duration.zero);
                      if (playing) {
                        await _player.pause();
                      } else {
                        await _player.play();
                      }
                    },
                    icon: Icon(
                      complete
                          ? Icons.replay_rounded
                          : playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.quicksand,
                      foregroundColor: AppColors.royalBlue,
                    ),
                  );
                },
              ),
            ],
          ),
  );

  static String _duration(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
