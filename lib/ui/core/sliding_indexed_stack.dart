import "package:material_ui/material_ui.dart";

/// An [IndexedStack] whose page switches slide horizontally.
///
/// Like [IndexedStack], every child stays mounted, so page state (scroll
/// position, text input, web views) survives switching. Unlike
/// [IndexedStack], the incoming page slides in from the side and the
/// outgoing page slides out the other side:
///
/// * switching to a later page slides the new page in from the trailing
///   side (from the right in left-to-right locales);
/// * switching to an earlier page slides it in from the leading side.
///
/// The direction flips in right-to-left locales. When animations are
/// disabled ([MediaQuery.disableAnimations], e.g. e-ink mode) the switch
/// is instant.
///
/// The wrapper around every child — [Positioned] → [Transform] →
/// [Offstage] — is identical in every state; only the translate offset
/// and the [Offstage.offstage] flag change. Switching therefore never
/// unmounts a page, so its state survives exactly like [IndexedStack].
///
/// A switch started while a previous switch is still animating reuses the
/// page currently sliding in as the outgoing page, starting from wherever
/// it has reached; the page that was sliding out snaps back offstage.
/// Reversing direction mid-flight therefore jumps the re-entering page to
/// the far side before it slides back in.
class SlidingIndexedStack extends StatefulWidget {
  const SlidingIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.fastOutSlowIn,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<SlidingIndexedStack> createState() => _SlidingIndexedStackState();
}

class _SlidingIndexedStackState extends State<SlidingIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  int _currentIndex = 0;
  int? _outgoingIndex;
  // Offset of the outgoing page, in units of the stack width, at the
  // moment the current transition started. Zero when idle; non-zero only
  // when a new switch interrupts a transition in flight.
  double _outgoingStart = 0;
  // +1: the new page comes from the trailing side; -1: from the leading
  // side. Already adjusted for text direction.
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _outgoingIndex = null;
          _outgoingStart = 0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(SlidingIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.index == _currentIndex) {
      return;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = widget.index > _currentIndex;
    final direction = (forward ? 1.0 : -1.0) * (rtl ? -1.0 : 1.0);
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _currentIndex = widget.index;
        _outgoingIndex = null;
        _outgoingStart = 0;
      });
      return;
    }
    // If a transition is in flight, the page currently sliding in becomes
    // the outgoing page, starting from wherever it has reached.
    final inFlight = _outgoingIndex != null && _controller.isAnimating;
    final outgoingStart = inFlight
        ? _direction * (1.0 - _animation.value)
        : 0.0;
    setState(() {
      _outgoingIndex = _currentIndex;
      _outgoingStart = outgoingStart;
      _currentIndex = widget.index;
      _direction = direction;
    });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final transitioning = _outgoingIndex != null;
        final t = _animation.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  _buildChild(i, width, t, transitioning),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChild(int i, double width, double t, bool transitioning) {
    // The offset is zero for every child that is not part of the
    // transition, so the wrapper structure stays identical for all
    // children in all states and no page is ever unmounted by a switch.
    var offset = Offset.zero;
    if (transitioning) {
      if (i == _currentIndex) {
        offset = Offset(_direction * width * (1.0 - t), 0);
      } else if (i == _outgoingIndex) {
        offset = Offset(
          (_outgoingStart * (1.0 - t) + (-_direction) * t) * width,
          0,
        );
      }
    }
    return Positioned.fill(
      child: Transform.translate(
        offset: offset,
        child: Offstage(
          offstage: i != _currentIndex && i != _outgoingIndex,
          child: widget.children[i],
        ),
      ),
    );
  }
}
