import "dart:math" as math;

import "package:ciyue/viewModels/audio.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

/// A compact animated icon rendering bouncing equalizer waveform bars.
class AudioWaveformIcon extends StatefulWidget {
  final Color? color;
  final double size;

  const AudioWaveformIcon({super.key, this.color, this.size = 24.0});

  @override
  State<AudioWaveformIcon> createState() => _AudioWaveformIconState();
}

class _AudioWaveformIconState extends State<AudioWaveformIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _WaveformPainter(
              progress: _controller.value,
              color: effectiveColor,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  static const List<double> _phases = [0.0, 1.3, 2.6, 3.9];

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _phases.length;
    final barWidth = size.width * 0.12;
    final gap = size.width * 0.12;
    final totalWidth = barCount * barWidth + (barCount - 1) * gap;
    final leftStart = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;

    final minHeight = size.height * 0.25;
    final maxHeight = size.height * 0.85;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final t = progress * 2 * math.pi;

    for (int i = 0; i < barCount; i++) {
      final hFactor = (math.sin(t + _phases[i]) + 1.0) / 2.0;
      final height = minHeight + (maxHeight - minHeight) * hFactor;
      final x = leftStart + i * (barWidth + gap);
      final top = centerY - height / 2;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Wraps a widget (such as a FloatingActionButton) with an animated pulsing ripple ring.
class PulsingFab extends StatefulWidget {
  final Widget child;
  final bool isPulsing;
  final Color? ringColor;

  const PulsingFab({
    super.key,
    required this.child,
    required this.isPulsing,
    this.ringColor,
  });

  @override
  State<PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<PulsingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPulsing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat();
      } else {
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) {
      return widget.child;
    }

    final effectiveColor =
        widget.ringColor ?? Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _PulseRingPainter(
              progress: _controller.value,
              color: effectiveColor,
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.shortestSide / 2;
    const maxExtraRadius = 8.0;
    final currentRadius = baseRadius + progress * maxExtraRadius;
    final alpha = ((1.0 - progress) * 0.45).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// A floating audio status pill that slides in when audio is playing and displays
/// animated waveform feedback, the word/audio label, and a stop button.
class FloatingAudioIndicator extends StatelessWidget {
  const FloatingAudioIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final audioModel = Provider.of<AudioModel?>(context);
    final isPlaying = audioModel?.isPlaying ?? false;
    final playingWord = audioModel?.playingWord ?? "";

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return IgnorePointer(
      ignoring: !isPlaying,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: isPlaying ? Offset.zero : const Offset(0, 1.4),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          opacity: isPlaying ? 1.0 : 0.0,
          child: Center(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              color: colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AudioWaveformIcon(
                      size: 18,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    if (playingWord.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          playingWord,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => audioModel?.stopAudio(),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colorScheme.onSecondaryContainer.withValues(
                            alpha: 0.8,
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
      ),
    );
  }
}
