import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'app_icons.dart';
import 'pressable.dart';

/// Questify v9 — Cal AI–inspired split floating navigation with liquid
/// sliding indicator.
///
/// Layout: [==== White Tab Pill (4 tabs) ====] [● Dark Camera FAB]
/// A grey highlight pill slides continuously between tabs using
/// `AnimatedPositioned` for a smooth liquid-glass transition feel.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onVerify,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onVerify;

  static const tabs = [
    ('home', 'Home'),
    ('calendar', 'Tasks'),
    ('trophy', 'Ranks'),
    ('user', 'Profile'),
  ];

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  final List<GlobalKey> _tabKeys = List.generate(4, (_) => GlobalKey());
  double _indicatorX = 0;
  double _indicatorW = 0;
  bool _measured = false;

  @override
  void didUpdateWidget(FloatingNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _measureTab(widget.currentIndex);
    }
  }

  void _measureTab(int index) {
    final box = _tabKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final pillBox = _tabKeys[0].currentContext?.findRenderObject() as RenderBox?;
      if (pillBox != null) {
        final pillOffset = pillBox.localToGlobal(Offset.zero);
        final tabOffset = box.localToGlobal(Offset.zero);
        setState(() {
          _indicatorX = tabOffset.dx - pillOffset.dx;
          _indicatorW = box.size.width;
          _measured = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Measure initial tab after first frame.
    if (!_measured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureTab(widget.currentIndex);
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: Row(
        children: [
          // ── Main nav pill (4 tabs + sliding indicator) ──────────
          Expanded(
            child: SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Pill background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFAFFFFFF),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: const Color(0x1F0F172A),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sliding liquid indicator
                  if (_measured)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      left: _indicatorX + 6,
                      top: 6,
                      width: _indicatorW,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDF2),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),

                  // Tab row
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          for (var i = 0; i < FloatingNavBar.tabs.length; i++)
                            _NavTab(
                              key: _tabKeys[i],
                              icon: FloatingNavBar.tabs[i].$1,
                              label: FloatingNavBar.tabs[i].$2,
                              active: widget.currentIndex == i,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onSelect(i);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Warm orange circular camera FAB ────────────────────
          Pressable(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onVerify();
            },
            scale: 0.90,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFE76F51)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.4, end: 0, duration: 450.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 350.ms);
  }
}

/// Cal AI–style nav tab: icon + label rendered without background.
/// The sliding indicator (in parent Stack) handles the active highlight.
class _NavTab extends StatelessWidget {
  const _NavTab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  static const _darkSlate = Color(0xFF0F172A);
  static const _inactiveColor = Color(0x800F172A);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcons.stroke(
              icon,
              size: 20,
              color: active ? _darkSlate : _inactiveColor,
              strokeWidth: active ? 2.2 : 1.9,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? _darkSlate : _inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
