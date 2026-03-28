import 'package:flutter/material.dart';

/// A real-time waveform visualizer for audio recording and playback.
/// Renders animated vertical bars representing audio amplitude levels.
class WaveformVisualizer extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double height;
  final int barCount;

  const WaveformVisualizer({
    super.key,
    required this.isActive,
    this.color = const Color(0xFF1D9E75),
    this.height = 60,
    this.barCount = 30,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _levels;

  @override
  void initState() {
    super.initState();
    _levels = List.generate(widget.barCount, (_) => 0.15);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_onTick);

    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(WaveformVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        _levels = List.generate(widget.barCount, (_) => 0.15);
      });
    }
  }

  void _onTick() {
    if (!widget.isActive) return;
    setState(() {
      // Simulate amplitude variation — in production, feed real
      // amplitude data from the `record` package's amplitude stream.
      for (int i = 0; i < _levels.length; i++) {
        _levels[i] = 0.15 +
            0.85 *
                ((DateTime.now().millisecondsSinceEpoch ~/ 80 + i * 7) %
                    17 /
                    17.0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          final barHeight = widget.height * _levels[i];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: barHeight.clamp(2.0, widget.height),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.4 + 0.6 * _levels[i]),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
