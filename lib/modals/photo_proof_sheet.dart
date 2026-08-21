import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/openrouter_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/qubi_mascot.dart';

/// Quick-verify entry: pick a pending quest (or jump straight in when only one
/// is left) and run the camera-only proof flow.
Future<void> showQuickVerify(BuildContext context) async {
  final app = context.read<AppState>();
  final pending = app.pendingTodayHabits;
  if (pending.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('All quests verified today — nice! 🎉')),
      );
    return;
  }
  if (pending.length == 1) {
    await showPhotoProofSheet(context, pending.first);
    return;
  }
  final habit = await showModalBottomSheet<Habit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PendingPicker(habits: pending),
  );
  if (habit != null) {
    if (!context.mounted) return;
    await showPhotoProofSheet(context, habit);
  }
}

class _PendingPicker extends StatelessWidget {
  const _PendingPicker({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassDark : AppColors.glassLight,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet),
          ),
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose a quest to verify',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Camera-only proof · AI verified · +50 XP',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 14),
            for (final h in habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, h),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                        border: Border.all(color: AppColors.glassEdge),
                      ),
                      child: Row(
                        children: [
                          Text(h.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.name,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  '${h.category} · ${h.time}',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          AppIcons.stroke('chevronRight', size: 16, color: muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the in-app camera proof flow as a full-screen modal.
Future<void> showPhotoProofSheet(BuildContext context, Habit habit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => _PhotoProofSheet(habit: habit),
  );
}

enum _ProofStage { camera, analyzing, verified, rejected }

class _PhotoProofSheet extends StatefulWidget {
  const _PhotoProofSheet({required this.habit});

  final Habit habit;

  @override
  State<_PhotoProofSheet> createState() => _PhotoProofSheetState();
}

class _PhotoProofSheetState extends State<_PhotoProofSheet> {
  _ProofStage _stage = _ProofStage.camera;
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _busy = false;
  bool _flashOn = false;
  Uint8List? _captured;
  bool _usingDemoCapture = false;
  VisionVerdict? _verdict;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _usingDemoCapture = true);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _usingDemoCapture = true;
          _cameraReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  Future<void> _shutter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final settings = context.read<SettingsProvider>();
    if (settings.haptics) HapticFeedback.lightImpact();

    Uint8List? bytes;
    String? captureError;
    try {
      if (_cameraController != null && _cameraReady) {
        final xFile = await _cameraController!.takePicture();
        bytes = await xFile.readAsBytes();
        bytes = await _compress(bytes);
      } else {
        // Simulated capture for desktop/testing
        bytes = null;
      }
    } catch (e) {
      if (_allowDemoCapture) {
        bytes = null;
      } else {
        captureError = _cameraErrorMessage(e);
      }
    }

    if (!mounted) return;
    if (captureError != null) {
      setState(() {
        _busy = false;
        _stage = _ProofStage.rejected;
        _verdict = VisionVerdict(
          verified: false,
          confidence: 0,
          reason: captureError ?? 'Could not capture photo.',
        );
        _error = null;
      });
      return;
    }

    final demo = bytes == null;
    setState(() {
      _captured = bytes;
      _usingDemoCapture = demo;
      _busy = false;
      _stage = _ProofStage.analyzing;
    });

    await _analyze(bytes, demo);
  }

  static bool get _allowDemoCapture {
    if (kIsWeb) return true;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    return false;
  }

  static String _cameraErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Camera permission was denied. Allow camera access in your '
          'phone settings, then come back and retake.';
    }
    if (text.contains('no camera') ||
        text.contains('not available') ||
        text.contains('unavailable')) {
      return 'No camera is available on this device.';
    }
    return 'The camera could not be opened. Tap Retake to try again.';
  }

  Future<Uint8List> _compress(Uint8List input) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: 1200,
        quality: 82,
      );
      if (out.isNotEmpty) return out;
    } catch (_) {}
    return input;
  }

  Future<void> _analyze(Uint8List? bytes, bool demo) async {
    final settings = context.read<SettingsProvider>();
    final app = context.read<AppState>();
    VisionVerdict verdict;
    try {
      verdict = await OpenRouterService.instance.verifyPhoto(
        bytes: bytes ?? Uint8List(0),
        expected: widget.habit.name,
      );
    } catch (e) {
      if (!mounted) return;
      final reason = switch (e) {
        AiHttpException() => e.userMessage,
        _ => 'The verifier is unreachable right now. Try again.',
      };
      setState(() {
        _stage = _ProofStage.rejected;
        _verdict = VisionVerdict(
          verified: false,
          confidence: 0,
          reason: reason,
        );
        _error = null;
      });
      return;
    }

    if (verdict.verified) {
      String? proofPath;
      if (SupabaseService.instance.isConfigured && bytes != null) {
        try {
          proofPath = await SupabaseService.instance.uploadPhotoProof(bytes);
        } catch (_) {}
      }
      settings.celebrate();
      await app.verifyHabit(
        widget.habit.id,
        proofPath: proofPath,
      );
    }

    if (!mounted) return;
    setState(() {
      _verdict = verdict;
      _stage = verdict.verified ? _ProofStage.verified : _ProofStage.rejected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SizedBox(
      height: height * 0.92,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: switch (_stage) {
              _ProofStage.camera => _cameraView(),
              _ProofStage.analyzing => _analyzingView(),
              _ProofStage.verified => _verifiedView(),
              _ProofStage.rejected => _rejectedView(),
            },
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Snap Photo Proof',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.habit.emoji} ${widget.habit.name} · ${widget.habit.time}',
                  style: TextStyle(
                    color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.mutedLight),
          ),
        ],
      ),
    );
  }

  // ── Camera view ─────────────────────────────────────────────────────────

  Widget _cameraView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E0F10), Color(0xFF1D1F21)],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Live camera preview or placeholder
                    if (_cameraReady && _cameraController != null)
                      Center(
                        child: CameraPreview(_cameraController!),
                      )
                    else if (_captured != null)
                      Image.memory(_captured!, fit: BoxFit.cover)
                    else
                      Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFF242628),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Center(
                            child: AppIcons.stroke(
                              widget.habit.icon,
                              size: 58,
                              color: AppColors.mutedLight,
                              strokeWidth: 1.6,
                            ),
                          ),
                        ),
                      ),
                    // Viewfinder overlay
                    const _ReticleCorners(),
                    // Habit badge
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _HabitBadge(habit: widget.habit),
                    ),
                    // Flash toggle
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _FlashButton(
                        flashOn: _flashOn,
                        onTap: _toggleFlash,
                      ),
                    ),
                    // Scan line
                    const _ScanLine(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete the quest first, then capture the evidence — no gallery, '
            'no uploads from disk. AI verifies the object in your photo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.mutedLight : AppColors.muted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          // Shutter button
          Center(
            child: GestureDetector(
              onTap: _busy ? null : _shutter,
              child: AnimatedScale(
                scale: _busy ? 0.94 : 1,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 4),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Analyzing view ──────────────────────────────────────────────────────

  Widget _analyzingView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_captured != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Image.memory(_captured!, fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242628),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: AppIcons.stroke(
                        widget.habit.icon,
                        size: 44,
                        color: AppColors.mutedLight,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3.5,
                  ),
                ),
                const SizedBox(height: 18),
                // Liquid-glass scanning bar
                _LiquidScanningBar(),
                const SizedBox(height: 6),
                const Text(
                  'Analyzing photo proof…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _usingDemoCapture
                      ? 'Demo capture — camera unavailable on this device'
                      : 'Qubi is inspecting your proof... \uD83D\uDD0D',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedLight,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Verified view ───────────────────────────────────────────────────────

  Widget _verifiedView() {
    final v = _verdict!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      QubiMascot(size: 110, celebrating: true, bob: false)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.06, 1.06),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
                          ),
                      const _TreatConfetti(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(v.confidence * 100).round()}% Match · Verified!',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '+50 XP',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LevelProgress(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Treat earned · Streak +1 · Rank protected 🔥',
                  style: TextStyle(
                    color: AppColors.mutedLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    v.reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _doneButton('Done — Back to Dashboard'),
        ],
      ),
    );
  }

  // ── Rejected view ───────────────────────────────────────────────────────

  Widget _rejectedView() {
    final v = _verdict!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QubiMascot(size: 104, bob: false),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Proof rejected',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    v.reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No XP was banked. Re-capture the evidence and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedLight, fontSize: 12.5),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedLight, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderDark),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _captured = null;
                      _verdict = null;
                      _stage = _ProofStage.camera;
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doneButton(String label) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDeep],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Overlay widgets ─────────────────────────────────────────────────────────

/// Habit badge shown in the top-left of the camera viewfinder.
class _HabitBadge extends StatelessWidget {
  const _HabitBadge({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(habit.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            habit.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flash toggle button for the camera viewfinder.
class _FlashButton extends StatelessWidget {
  const _FlashButton({required this.flashOn, required this.onTap});

  final bool flashOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: flashOn
              ? AppColors.primary.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.5),
        ),
        child: Center(
          child: Icon(
            flashOn ? Icons.flash_on : Icons.flash_off,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Burst of sparkle/star chips that orbit the celebrating mascot.
class _TreatConfetti extends StatelessWidget {
  const _TreatConfetti();

  static const _colors = [
    AppColors.primary,
    AppColors.gold,
    Color(0xFF52B788),
    AppColors.primaryDeep,
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [for (var i = 0; i < 10; i++) _spark(i)],
        ),
      ),
    );
  }

  Widget _spark(int i) {
    final angle = i * math.pi / 5;
    final radius = 48.0 + (i % 3) * 18;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    return Align(
      alignment: Alignment.center,
      child: AppIcons.stroke(
        i.isEven ? 'sparkle' : 'star',
        size: 10 + (i % 3) * 3,
        color: _colors[i % _colors.length],
        strokeWidth: 2,
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .move(
            begin: const Offset(0, 0),
            end: Offset(dx, dy),
            duration: Duration(milliseconds: 850 + i * 70),
            curve: Curves.easeInOut,
          )
          .fade(begin: 0.15, end: 1),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final xp = app.xp;
    final level = 1 + (xp ~/ 500);
    final intoLevel = xp - (level - 1) * 500;
    final progress = (intoLevel / 500).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL $level',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'LEVEL ${level + 1}',
              style: const TextStyle(
                color: AppColors.mutedLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8E9EA),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$xp XP',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final range = constraints.maxHeight - 90;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              left: 22,
              right: 22,
              top: 40 + _controller.value * range,
              child: child!,
            );
          },
          child: Container(
            height: 2.5,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.transparent, AppColors.primary, Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReticleCorners extends StatelessWidget {
  const _ReticleCorners();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    const len = 26.0;
    const thickness = 3.0;

    Widget corner(
      Alignment alignment, {
      required bool flipX,
      required bool flipY,
    }) {
      return Transform.flip(
        flipX: flipX,
        flipY: flipY,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: CustomPaint(
              size: const Size(len, len),
              painter: _CornerPainter(color, thickness),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(Alignment.topLeft, flipX: false, flipY: false),
        corner(Alignment.topRight, flipX: true, flipY: false),
        corner(Alignment.bottomLeft, flipX: false, flipY: true),
        corner(Alignment.bottomRight, flipX: true, flipY: true),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color, this.thickness);

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}

/// Liquid-glass scanning bar shown during AI photo inspection.
/// Animated gradient sweep across a translucent pill track.
class _LiquidScanningBar extends StatefulWidget {
  @override
  State<_LiquidScanningBar> createState() => _LiquidScanningBarState();
}

class _LiquidScanningBarState extends State<_LiquidScanningBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: 200,
          height: 6,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -80 + t * (200 + 80),
                top: 0,
                bottom: 0,
                width: 80,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary,
                        Colors.white,
                        AppColors.primary,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
