import 'package:flutter/material.dart';

/// Shared soft-embossed (neumorphic) surface used by tiles, pills and the
/// nav bar. Kept deliberately subtle — low-alpha dual shadows + a warm tinted
/// fill — so the effect reads calm and premium rather than "obviously neo".
BoxDecoration neoSurfaceDecoration(bool isDark, {double radius = 16}) {
  return BoxDecoration(
    color: isDark ? const Color(0xFF171D24) : const Color(0xFFF7F3EE),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: isDark
        ? [
            BoxShadow(
              color: const Color(0xCC05070B),
              blurRadius: 10,
              offset: const Offset(3, 5),
            ),
            BoxShadow(
              color: const Color(0x1F3B4354),
              blurRadius: 10,
              offset: const Offset(-3, -4),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0x556B5D55),
              blurRadius: 10,
              offset: const Offset(3, 5),
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: const Offset(-3, -4),
            ),
          ],
  );
}
