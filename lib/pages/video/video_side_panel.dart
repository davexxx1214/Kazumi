import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/side_panel_transition.dart';

class VideoSidePanel extends StatefulWidget {
  const VideoSidePanel({
    super.key,
    required this.fullscreen,
    required this.child,
    this.disableAnimations = false,
    this.onOpened,
    this.onClosed,
  });

  final bool fullscreen;
  final bool disableAnimations;
  final Widget child;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<VideoSidePanel> createState() => VideoSidePanelState();
}

class VideoSidePanelState extends State<VideoSidePanel>
    with SingleTickerProviderStateMixin {
  LocalHistoryEntry? _historyEntry;
  bool _isShown = false;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: SidePanelTransition.duration,
  );
  late final Animation<double> _opacity =
      _animation.drive(CurveTween(curve: Curves.easeIn));

  bool get isOpen => _isShown;

  void toggle() {
    if (_isShown) {
      close();
    } else {
      _isShown = true;
      late final LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (_historyEntry != entry) return;
          _historyEntry = null;
          if (mounted) close();
        },
      );
      _historyEntry = entry;
      ModalRoute.of(context)?.addLocalHistoryEntry(entry);
      if (widget.disableAnimations) {
        _animation.value = 1;
      } else {
        _animation.forward();
      }
      widget.onOpened?.call();
    }
  }

  void close() {
    if (!_isShown) return;
    _isShown = false;
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
    if (widget.disableAnimations) {
      _animation.value = 0;
    } else {
      _animation.reverse();
    }
    widget.onClosed?.call();
  }

  @override
  void didUpdateWidget(VideoSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset before rendering the new mode to avoid a sidebar flash.
    if (oldWidget.fullscreen != widget.fullscreen) {
      final wasOpen = _isShown;
      _animation.value = 0;
      if (wasOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) close();
        });
      }
    }
  }

  @override
  void dispose() {
    final wasOpen = _isShown;
    _isShown = false;
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
    if (wasOpen) {
      final onClosed = widget.onClosed;
      WidgetsBinding.instance.addPostFrameCallback((_) => onClosed?.call());
    }
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (_animation.isDismissed) return const SizedBox.shrink();
            return Stack(
              alignment: Alignment.centerRight,
              children: [
                FadeTransition(
                  opacity: _opacity,
                  child: GestureDetector(
                    onTap: close,
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SidePanelTransition(animation: _animation, child: child!),
              ],
            );
          },
          child: SizedBox(
            // Keep space outside the panel for dismissal.
            width: math.min(constraints.maxWidth * 0.9,
                (constraints.maxWidth / 3).clamp(320.0, 420.0)),
            height: constraints.maxHeight,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(28),
                bottomStart: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              // Consume the hidden status-bar inset for the entire overlay.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SafeArea(child: widget.child),
              ),
            ),
          ),
        ),
      );
}
