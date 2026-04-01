import 'dart:async';

import 'package:flutter/material.dart';

/// A compact vertical fast scroller to jump between ayahs.
class AyahFastScroller extends StatefulWidget {
  final ScrollController scrollController;
  final int totalAyahs;
  final int currentAyah;
  final ValueChanged<int> onAyahSelected;
  final Map<int, GlobalKey> ayahKeys;

  const AyahFastScroller({
    super.key,
    required this.scrollController,
    required this.totalAyahs,
    required this.currentAyah,
    required this.onAyahSelected,
    required this.ayahKeys,
  });

  @override
  State<AyahFastScroller> createState() => _AyahFastScrollerState();
}

class _AyahFastScrollerState extends State<AyahFastScroller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  bool _isDragging = false;
  int? _previewAyah;
  Timer? _hideTimer;

  void _onScrollActivity() {
    _showScroller();
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    widget.scrollController.addListener(_onScrollActivity);
  }

  @override
  void didUpdateWidget(covariant AyahFastScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollActivity);
      widget.scrollController.addListener(_onScrollActivity);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.scrollController.removeListener(_onScrollActivity);
    _animController.dispose();
    super.dispose();
  }

  void _showScroller() {
    _hideTimer?.cancel();
    _animController.forward();
    _hideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_isDragging) {
        _animController.reverse();
      }
    });
  }

  void _updateFromLocalDy(double localDy, double trackHeight) {
    final clamped = localDy.clamp(0.0, trackHeight);
    final progress = trackHeight <= 0 ? 0.0 : clamped / trackHeight;
    final targetAyah = ((widget.totalAyahs - 1) * progress).round() + 1;
    final ayah = targetAyah.clamp(1, widget.totalAyahs);

    if (_previewAyah != ayah) {
      setState(() => _previewAyah = ayah);
    }
  }

  void _jumpToAyah(int ayahNumber) {
    widget.onAyahSelected(ayahNumber);
  }

  double _thumbTop(double trackHeight) {
    final progress = widget.totalAyahs <= 1
        ? 0.0
        : (widget.currentAyah - 1) / (widget.totalAyahs - 1);
    final thumbHeight = 44.0;
    return (progress * (trackHeight - thumbHeight)).clamp(0.0, trackHeight);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        // Align to right edge FIRST so the Listener only captures the 52 px
        // strip — the ListView beneath remains fully scrollable everywhere else.
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 52,
            child: MouseRegion(
              onEnter: (_) => _showScroller(),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  setState(() => _isDragging = true);
                  _hideTimer?.cancel();
                  _updateFromLocalDy(event.localPosition.dy, trackHeight);
                },
                onPointerMove: (event) {
                  if (_isDragging) {
                    _updateFromLocalDy(event.localPosition.dy, trackHeight);
                  }
                },
                onPointerUp: (_) {
                  final targetAyah = _previewAyah;
                  setState(() => _isDragging = false);
                  if (targetAyah != null) {
                    _jumpToAyah(targetAyah);
                  }
                  _showScroller();
                },
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final hidden = !_isDragging && _animController.value <= 0.01;
                    return IgnorePointer(
                      ignoring: hidden,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: _thumbTop(trackHeight),
                        child: Container(
                          width: 8,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D9E75),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      if (_isDragging && _previewAyah != null)
                        Positioned(
                          right: 28,
                          top: (_thumbTop(trackHeight) - 4).clamp(0.0, trackHeight - 48),
                          child: Material(
                            color: const Color(0xFF1D9E75),
                            borderRadius: BorderRadius.circular(10),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                '$_previewAyah',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
