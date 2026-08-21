import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/qubi_mascot.dart';

/// In-app 6-digit OTP verification sheet shown after sign-up when using
/// Resend-based email verification. Keeps the user inside the app — no
/// browser redirect needed.
///
/// On success the sheet closes and returns `true` to the caller, which
/// handles account creation and navigation.
Future<T?> showOtpVerificationSheet<T>(
  BuildContext context, {
  required String email,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _OtpSheet(email: email),
  );
}

class _OtpSheet extends StatefulWidget {
  const _OtpSheet({required this.email});
  final String email;

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  static const _length = 6;

  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_length, (_) => FocusNode());

  bool _verifying = false;
  String? _error;
  bool _resending = false;
  int _resendCooldown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ── Resend cooldown ──────────────────────────────────────────────────

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  // ── PIN helpers ──────────────────────────────────────────────────────

  String get _code => _controllers.map((c) => c.text).join();

  void _clearFields() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == _length) {
      _verify();
    }
  }

  // ── Verify ──────────────────────────────────────────────────────────

  Future<void> _verify() async {
    final code = _code;
    if (code.length != _length) return;
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final success = await SupabaseAuthService.instance.verifyResendCode(
        email: widget.email,
        code: code,
      );
      if (!mounted) return;

      if (!success) {
        setState(() {
          _verifying = false;
          _error = 'Verification failed. Please try again or resend a new code.';
        });
        _clearFields();
        return;
      }

      // Code verified — pop with true so the caller can create the account.
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email verified! Welcome to Questify.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
          ),
        ),
      );
    } on String catch (msg) {
      if (!mounted) return;
      String displayMessage;
      final lower = msg.toLowerCase();
      if (lower.contains('invalid') ||
          lower.contains('expired') ||
          lower.contains('token') ||
          lower.contains('code')) {
        displayMessage = 'The code entered is invalid or expired. Tap Resend Code.';
      } else if (lower.contains('rate') || lower.contains('429')) {
        displayMessage = 'Rate limit reached. Please wait 60 seconds before requesting a new code.';
      } else {
        displayMessage = msg;
      }
      setState(() {
        _verifying = false;
        _error = displayMessage;
      });
      _clearFields();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Verification failed — please try again.';
      });
      _clearFields();
    }
  }

  // ── Resend ──────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      final result = await SupabaseAuthService.instance.sendResendCode(widget.email);
      if (!mounted) return;

      if (result['status'] == 'error') {
        setState(() => _error = result['message'] ?? 'Failed to resend code. Try again.');
        return;
      }

      // Clear all fields for the fresh code.
      _clearFields();

      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fresh 6-digit code sent to ${widget.email}!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
          ),
        ),
      );
    } on String catch (e) {
      // Rate-limit message.
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not resend code. Try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final bg = isDark ? AppColors.glassDark : AppColors.glassLight;
    final fieldBg = isDark ? AppColors.surfaceContainer : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSheet),
            ),
            border: Border.all(color: AppColors.glassEdge),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const QubiMascot(size: 56),
              const SizedBox(height: 14),
              Text(
                'Verify your email',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent a 6-digit code to',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              Text(
                widget.email,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // 6-digit PIN fields
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_length, (i) {
                  return Container(
                    width: 46,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey ==
                                LogicalKeyboardKey.backspace &&
                            _controllers[i].text.isEmpty &&
                            i > 0) {
                          _controllers[i - 1].clear();
                          _focusNodes[i - 1].requestFocus();
                        }
                      },
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                            borderSide: BorderSide(
                              color: _error != null
                                  ? AppColors.error
                                  : AppColors.glassEdge,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                            borderSide: BorderSide(
                              color: AppColors.glassEdge,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    ),
                  );
                }),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      onTap: _verifying ? null : _verify,
                      child: Center(
                        child: _verifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Verify & Launch Questify',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Resend code
              TextButton(
                onPressed: _resendCooldown > 0 || _resending ? null : _resend,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend code in ${_resendCooldown}s'
                      : (_resending ? 'Sending...' : 'Resend code'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _resendCooldown > 0
                        ? muted
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
