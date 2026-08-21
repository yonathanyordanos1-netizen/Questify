import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// Wraps a child with a subtle press-down scale so taps feel tactile.
/// A [null] [onTap] renders the child without press feedback (disabled state).
/// Fires a light haptic tick on every tap (respecting the user's haptics
/// preference) so the whole app feels Duolingo-tactile.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.965,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _tick() {
    final settings = _maybeSettings(context);
    if (settings?.haptics ?? true) {
      HapticFeedback.lightImpact();
    }
  }

  /// Reads the haptics preference without requiring the provider to exist
  /// (widget tests may pump `Pressable` without a SettingsProvider).
  static SettingsProvider? _maybeSettings(BuildContext context) {
    try {
      return Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () {
          if (_pressed) setState(() => _pressed = false);
        },
        onTap: () {
          _tick();
          widget.onTap?.call();
        },
        child: widget.child,
      ),
    );
  }
}
