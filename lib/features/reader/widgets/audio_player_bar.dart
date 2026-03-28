import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/services/audio_service.dart';

/// A mini audio player bar shown at the bottom of the reader when a verse
/// is playing. Shows play/pause, progress, speed control, and ayah label.
class AudioPlayerBar extends StatefulWidget {
  final AudioService audioService;
  final String label;
  final VoidCallback onClose;

  const AudioPlayerBar({
    super.key,
    required this.audioService,
    required this.label,
    required this.onClose,
  });

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  double _speed = 1.0;
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  void _cycleSpeed() {
    final nextIdx = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    _speed = _speeds[nextIdx];
    widget.audioService.setSpeed(_speed);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress slider
            StreamBuilder<Duration>(
              stream: widget.audioService.positionStream,
              builder: (context, posSnap) {
                return StreamBuilder<Duration?>(
                  stream: widget.audioService.durationStream,
                  builder: (context, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final progress = dur.inMilliseconds > 0
                        ? pos.inMilliseconds / dur.inMilliseconds
                        : 0.0;

                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF1D9E75)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(_format(pos),
                                style: Theme.of(context).textTheme.bodySmall),
                            const Spacer(),
                            Text(_format(dur),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 4),

            // Controls row
            Row(
              children: [
                // Ayah label
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Speed button
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${_speed}x',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ),

                const SizedBox(width: 8),

                // Play/Pause
                StreamBuilder<PlayerState>(
                  stream: widget.audioService.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 36,
                        color: const Color(0xFF1D9E75),
                      ),
                      onPressed: () {
                        if (playing) {
                          widget.audioService.pause();
                        } else {
                          widget.audioService.resume();
                        }
                      },
                    );
                  },
                ),

                // Close
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    widget.audioService.stop();
                    widget.onClose();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
