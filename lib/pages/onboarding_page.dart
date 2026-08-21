import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthResponse;

import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/qubi_mascot.dart';
import '../modals/otp_verification_sheet.dart';

/// 17-step onboarding wizard with live Inspector panel and Replay mode.
///
/// When [replayMode] is true the wizard starts with existing responses
/// pre-filled so the user can tweak and re-submit.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.replayMode = false});

  /// When `true`, pre-fills all steps from existing [AppState.responses].
  final bool replayMode;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _step = 0;

  static const _progress = [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 78, 84, 92, 100];

  static const _googleLogo =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
      '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
      '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
      '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
      '</svg>';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  String? _authMode; // 'google' | 'email'
  String _googleName = '';
  String _googleEmail = '';
  bool _authBusy = false;
  String? _authError;
  bool _signInMode = false;

  // ── Inspector toggle ──────────────────────────────────────────────────
  bool _showInspector = false;

  AppState get _app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    if (widget.replayMode) _prefillFromExisting();
    debugPrint('[ui] OnboardingPage built (step 0: welcome, '
        'replay=${widget.replayMode})');
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Pre-populate text fields and selections from the user's existing data.
  void _prefillFromExisting() {
    _nameCtrl.text = _app.displayName;
    _usernameCtrl.text = _app.username;
    // Other fields are choice grids — they read from _app.responses in build.
  }

  void _next() {
    if (_step >= _progress.length - 1) return;
    setState(() => _step++);
    _controller.animateToPage(
      _step,
      duration: 320.ms,
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _controller.animateToPage(
      _step,
      duration: 320.ms,
      curve: Curves.easeOutCubic,
    );
  }

  void _launch() {
    _app.finishOnboarding();
  }

  // ── Auth wiring ─────────────────────────────────────────────────────────

  Future<void> _continueWithGoogle() async {
    if (_authBusy) return;
    setState(() {
      _authBusy = true;
      _authError = null;
    });
    try {
      final res = await SupabaseService.instance
          .signInWithGoogle()
          .timeout(const Duration(seconds: 5));
      final returning = await _afterAuthSuccess(res);
      if (!mounted) return;
      if (returning) return; // Previous device — BootScreen routes to dashboard.
      _authMode = 'google';
      // Pre-fill name from Google profile.
      if (_googleName.isNotEmpty && _nameCtrl.text.isEmpty) {
        _nameCtrl.text = _googleName;
      }
      setState(() => _authBusy = false);
      _next();
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyGoogleError(e);
      setState(() {
        _authBusy = false;
        _authError = message;
      });
    }
  }

  String _friendlyGoogleError(Object e) {
    final s = e.toString();
    if (s.contains('cancelled') || s.contains('CANCELED')) {
      return 'Sign-in was cancelled. Try again or use email instead.';
    }
    if (s.contains('network') || s.contains('timeout') || s.contains('Socket')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (s.contains('ID token') || s.contains('idToken')) {
      return 'Google sign-in failed to complete. Make sure Google Play Services is installed and up to date.';
    }
    if (s.contains('did not launch') || s.contains('DEVELOPER_ERROR')) {
      return 'Google sign-in is not configured. Add your OAuth client ID to the Android manifest and Supabase dashboard.';
    }
    return 'Google sign-in failed. Try again or use email instead.';
  }

  Future<bool> _afterAuthSuccess(AuthResponse res) async {
    final user = res.user;
    if (user != null) {
      _googleName = (user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email ??
              '')
          .toString();
      _googleEmail = user.email ?? '';
      if (_googleName.isEmpty) _googleName = _googleEmail.split('@').first;
    }
    await _app.hydrateFromSupabase();
    return _app.onboardingDone;
  }

  Future<void> _continueWithEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _authError = 'Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _authError = 'Password needs at least 6 characters.');
      return;
    }
    if (_authBusy) return;
    setState(() {
      _authError = null;
      _authBusy = true;
    });
    try {
      if (_signInMode) {
        // ── SIGN IN ────────────────────────────────────────────────────
        final res = await SupabaseService.instance.signInExistingUser(email, pass);
        if (!res.success) {
          // Unverified email → send a fresh Resend code and route to OTP sheet.
          if (res.errorType == AuthErrorType.emailNotVerified) {
            if (!mounted) return;
            setState(() => _authBusy = false);
            // Send a fresh verification code via Resend.
            final sendResult =
                await SupabaseAuthService.instance.sendResendCode(email);
            if (sendResult['status'] == 'error') {
              if (!mounted) return;
              setState(() {
                _authBusy = false;
                _authError = sendResult['message'] ??
                    'Failed to send verification code. Please try again.';
              });
              return;
            }
            if (!mounted) return;
            final verified =
                await showOtpVerificationSheet<bool>(context, email: email);

            if (verified == true) {
              // Code verified — confirm the email in Supabase via admin API.
              // Even if this fails, try signing in (email may already be confirmed).
              if (!mounted) return;
              setState(() => _authBusy = true);
              try {
                try {
                  await SupabaseAuthService.instance.confirmUserEmail(email);
                } catch (confirmErr) {
                  debugPrint('[auth] confirmUserEmail failed (will still try sign-in): $confirmErr');
                }
                // Retry sign-in regardless — email may already be confirmed.
                final retryRes = await SupabaseService.instance.signInExistingUser(email, pass);
                if (!mounted) return;
                if (retryRes.success) {
                  final returning = await _afterAuthSuccess(retryRes.response!);
                  if (!mounted) return;
                  if (returning) return;
                  _authMode = 'email';
                  setState(() => _authBusy = false);
                  _next();
                  return;
                }
                setState(() {
                  _authBusy = false;
                  _authError = retryRes.friendlyMessage;
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _authBusy = false;
                  _authError = 'Email verified but sign-in failed. Please try signing in.';
                });
              }
            }
            return;
          }
          // Other errors.
          if (!mounted) return;
          setState(() {
            _authBusy = false;
            _authError = res.friendlyMessage;
          });
          return;
        }
        // Successful sign-in.
        final returning = await _afterAuthSuccess(res.response!);
        if (!mounted) return;
        if (returning) return;
        _authMode = 'email';
        setState(() => _authBusy = false);
        _next();
      } else {
        // ── SIGN UP ────────────────────────────────────────────────────
        // Step 1: Create Supabase account. We only need Supabase to hold
        // the user record — ALL verification goes through our custom
        // Resend Edge Function, so we intentionally ignore Supabase's
        // built-in confirmation email.
        try {
          await SupabaseService.instance.prepareNewAccountSession();
          final response = await SupabaseService.instance.client.auth.signUp(
            email: email,
            password: pass,
          );
          debugPrint('[auth] signUp: account created for $email');

          // Email confirmation OFF — user is already logged in.
          // Sign out immediately; we require OTP verification first.
          if (response.session != null) {
            await SupabaseService.instance.client.auth.signOut();
            debugPrint('[auth] signUp: signed out (confirmation OFF, will verify via OTP)');
          }
        } on AuthException catch (e) {
          final lower = e.message.toLowerCase();
          // Already registered but unverified — that's fine, send a fresh code.
          if (lower.contains('already registered') ||
              lower.contains('already been registered') ||
              lower.contains('user already exists')) {
            debugPrint('[auth] signUp: account already exists, sending fresh Resend code');
          } else if (lower.contains('already been confirmed') ||
              lower.contains('email already confirmed')) {
            // Already verified — tell the user to sign in.
            if (!mounted) return;
            setState(() {
              _authBusy = false;
              _authError = 'An account already exists for this email. Try signing in.';
            });
            return;
          } else if (lower.contains('email') &&
              (lower.contains('send') ||
               lower.contains('confirmation') ||
               lower.contains('smtp') ||
               lower.contains('error sending'))) {
            // Supabase tried to send its own confirmation email and failed
            // (SMTP not configured). The user likely exists — proceed with
            // our custom OTP flow anyway.
            debugPrint('[auth] signUp: Supabase email send failed ($e), proceeding with custom OTP');
          } else {
            if (!mounted) return;
            setState(() {
              _authBusy = false;
              _authError = e.message;
            });
            return;
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _authBusy = false;
            _authError = _friendlyAuthError(e);
          });
          return;
        }

        // Step 2: Send verification code via Resend Edge Function.
        final sendResult = await SupabaseAuthService.instance.sendResendCode(email);

        if (sendResult['status'] == 'error') {
          if (!mounted) return;
          setState(() {
            _authBusy = false;
            _authError = sendResult['message'] ?? 'Failed to send verification code.';
          });
          return;
        }

        // Step 3: Open OTP verification sheet.
        if (!mounted) return;
        setState(() => _authBusy = false);
        final verified = await showOtpVerificationSheet<bool>(context, email: email);

        // Step 4: If verified, confirm email in Supabase and sign in.
        if (verified == true) {
          if (!mounted) return;
          setState(() => _authBusy = true);
          try {
            // Confirm email via admin API. Even if this fails, still try
            // signing in — the email may already be confirmed.
            try {
              await SupabaseAuthService.instance.confirmUserEmail(email);
            } catch (confirmErr) {
              debugPrint('[auth] confirmUserEmail failed (will still try sign-in): $confirmErr');
            }

            // Sign in to establish a session.
            final signInRes = await SupabaseService.instance.signInExistingUser(email, pass);
            if (!mounted) return;

            if (signInRes.success) {
              final returning = await _afterAuthSuccess(signInRes.response!);
              if (!mounted) return;
              if (returning) return;
              _authMode = 'email';
              setState(() => _authBusy = false);
              _next();
            } else {
              setState(() {
                _authBusy = false;
                _authError = signInRes.friendlyMessage;
              });
            }
          } catch (e) {
            if (!mounted) return;
            debugPrint('[auth] signUp post-verify error: $e');
            setState(() {
              _authBusy = false;
              _authError = 'Email verified but sign-in failed. Please try signing in.';
            });
          }
          return;
        }
        return;
      }
    } on StateError {
      _authMode = 'email';
      if (!mounted) return;
      setState(() => _authBusy = false);
      _next();
    } on Error {
      _authMode = 'email';
      if (!mounted) return;
      setState(() => _authBusy = false);
      _next();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authBusy = false;
        _authError = _friendlyAuthError(e);
      });
    }
  }

  String _friendlyAuthError(Object e) {
    final message = e is AuthException ? e.message : e.toString();
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already_registered')) {
      return 'An account already exists for this email — switch to "Sign in".';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_confirm') ||
        lower.contains('email confirmation')) {
      return 'Please verify your email before signing in.';
    }
    if (lower.contains('confirm') || lower.contains('confirmation')) {
      return message;
    }
    if (lower.contains('weak password') ||
        lower.contains('password should be at least')) {
      return 'Password is too weak — use at least 6 characters.';
    }
    return 'Could not sign in right now. Check your connection and try again.';
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final username = _deriveUsername(name);
    if (_authMode == 'google') {
      _app.applyGoogleAuth(name: name, email: _googleEmail);
    } else {
      _app.createAccount(
        name: name,
        username: username,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    }
    await _app.setProfile(name: name, username: username);
    if (!mounted) return;
    _next();
  }

  String _deriveUsername(String name) {
    var u = name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (u.isEmpty) u = 'player';
    if (u.length < 3) u = u.padRight(3, '0');
    if (u.length > 16) u = u.substring(0, 16);
    return u;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header bar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      if (_step > 0) ...[
                        _IconButtonRound(
                          icon: 'chevronLeft',
                          onTap: _back,
                          tooltip: 'Back',
                        ),
                      ] else
                        const SizedBox(width: 38),
                      const Spacer(),
                      if (_step > 2)
                        Text(
                          'Step ${_step + 1} of ${_progress.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        )
                      else
                        Text(
                          'Questify',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: ink,
                          ),
                        ),
                      const Spacer(),
                      // Inspector toggle
                      GestureDetector(
                        onTap: () => setState(() => _showInspector = !_showInspector),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _showInspector
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : (isDark ? AppColors.cardDark : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _showInspector
                                  ? AppColors.primary
                                  : (isDark ? AppColors.borderDark : AppColors.border),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '\ud83d\udd0d',
                              style: TextStyle(
                                fontSize: 16,
                                color: _showInspector ? AppColors.primary : AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Progress bar ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress[_step] / 100,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? AppColors.gaugeTrackDark
                          : AppColors.gaugeTrack,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // ── Page view ────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep01Welcome(),
                      _buildStep02Auth(),
                      _buildStep03Name(),
                      _buildStep04Username(),
                      _buildStep05Age(),
                      _buildStep06Gender(),
                      _buildStep07WakeTime(),
                      _buildStep08Bedtime(),
                      _buildStep09TopGoals(),
                      _buildStep10DailyQuests(),
                      _buildStep11HabitCategories(),
                      _buildStep12PriorityHabits(),
                      _buildStep13ReadinessGoals(),
                      _buildStep14MascotVoice(),
                      _buildStep15TimeBudget(),
                      _buildStep16Theme(),
                      _buildStep17Confirm(),
                    ],
                  ),
                ),
              ],
            ),
            // ── Inspector overlay ─────────────────────────────────────
            if (_showInspector) _buildInspectorPanel(isDark),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // 17 STEPS
  // ══════════════════════════════════════════════════════════════════════

  // ── 1. Welcome ──────────────────────────────────────────────────────
  Widget _buildStep01Welcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _mascot(160),
          const SizedBox(height: 32),
          const Text(
            'Let\u2019s build your streak!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Snap proof. Stack XP. Climb the leagues.\nQubi will keep you on track.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5),
          ),
          const Spacer(flex: 3),
          _primaryButton(label: 'Start Your Streak', onTap: _next),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── 2. Auth (Google + email) ────────────────────────────────────────
  Widget _buildStep02Auth() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          const Spacer(),
          _mascot(96),
          const SizedBox(height: 20),
          Text(
            _signInMode ? 'Welcome back' : 'Create your account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _signInMode
                ? 'Sign in and pick up right where you left off.'
                : 'Your quests, streaks & leagues sync everywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 26),
          _socialButton(
            icon: _authBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.string(
                    _googleLogo,
                    width: 20,
                    height: 20,
                    placeholderBuilder: (_) => const SizedBox.shrink(),
                  ),
            label: 'Continue with Google',
            background: isDark ? AppColors.cardDark : Colors.white,
            onTap: _continueWithGoogle,
          ),
          const SizedBox(height: 20),
          _dividerLine(),
          const SizedBox(height: 20),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: TextStyle(
              color: isDark ? AppColors.inkLight : AppColors.ink,
              fontSize: 16,
            ),
            decoration: _inputDecoration('Email', 'you@example.com', fieldBg, border),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            style: TextStyle(
              color: isDark ? AppColors.inkLight : AppColors.ink,
              fontSize: 16,
            ),
            decoration: _inputDecoration('Password', '6+ characters', fieldBg, border),
            onChanged: (_) => setState(() {}),
          ),
          if (_authError != null) ...[
            const SizedBox(height: 10),
            Text(
              _authError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _primaryButton(
            label: _signInMode ? 'Sign in' : 'Create account',
            onTap: _continueWithEmail,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _signInMode = !_signInMode;
              _authError = null;
            }),
            child: Text(
              _signInMode
                  ? 'New to Questify? Create an account'
                  : 'Already have an account? Sign in',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'By continuing you agree to the Terms & Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  // ── 3. Name ─────────────────────────────────────────────────────────
  Widget _buildStep03Name() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    return _scaffold(
      mascot: _mascot(64),
      title: 'What\u2019s your name?',
      subtitle: 'Qubi will cheer you on by it.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('onboarding_name'),
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              color: isDark ? AppColors.inkLight : AppColors.ink,
              fontSize: 16,
            ),
            decoration: _inputDecoration('Your name', 'e.g. Alex', fieldBg, border),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          _primaryButton(label: 'Continue', onTap: _saveName),
        ],
      ),
    );
  }

  // ── 4. Username ─────────────────────────────────────────────────────
  Widget _buildStep04Username() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? AppColors.cardDark : Colors.white;
    final border = isDark ? AppColors.borderDark : AppColors.border;

    return _scaffold(
      mascot: _mascot(52),
      title: 'Pick a username',
      subtitle: 'This is your unique handle on the leaderboard.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameCtrl,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(
              color: isDark ? AppColors.inkLight : AppColors.ink,
              fontSize: 16,
            ),
            decoration: _inputDecoration('Username', '@yourname', fieldBg, border,
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('@', style: TextStyle(fontSize: 16, color: AppColors.muted)),
                )),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          _primaryButton(
            label: 'Continue',
            onTap: () async {
              final username = _usernameCtrl.text.trim().toLowerCase();
              if (username.isEmpty) return;
              await _app.setProfile(
                name: _app.displayName,
                username: username,
              );
              if (!mounted) return;
              _next();
            },
          ),
        ],
      ),
    );
  }

  // ── 5. Age ──────────────────────────────────────────────────────────
  Widget _buildStep05Age() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'How old are you?',
      subtitle: 'So Qubi can set goals that actually fit your life.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'age_group',
        options: const [
          _ChoiceOption(icon: 'star', label: 'Under 18', emoji: '\ud83d\udc23', value: 'under_18'),
          _ChoiceOption(icon: 'flame', label: '18 \u2013 24', emoji: '\ud83d\udd25', value: '18_24'),
          _ChoiceOption(icon: 'briefcase', label: '25 \u2013 34', emoji: '\ud83d\udcbc', value: '25_34'),
          _ChoiceOption(icon: 'rocket', label: '35+', emoji: '\ud83d\ude80', value: '35_plus'),
        ],
      ),
    );
  }

  // ── 6. Gender ───────────────────────────────────────────────────────
  Widget _buildStep06Gender() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'How do you identify?',
      subtitle: 'Optional \u2014 helps us personalise your experience.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'gender',
        options: const [
          _ChoiceOption(icon: 'user', label: 'Male', value: 'male'),
          _ChoiceOption(icon: 'user', label: 'Female', value: 'female'),
          _ChoiceOption(icon: 'user', label: 'Non-binary', value: 'non_binary'),
          _ChoiceOption(icon: 'user', label: 'Prefer not to say', value: 'prefer_not'),
        ],
      ),
    );
  }

  // ── 7. Wake Time ────────────────────────────────────────────────────
  Widget _buildStep07WakeTime() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'What time do you wake up?',
      subtitle: 'Qubi will schedule your morning quests.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'wake_time',
        options: const [
          _ChoiceOption(icon: 'sun', label: '5:00 AM', emoji: '\ud83c\udf05', value: '05'),
          _ChoiceOption(icon: 'sun', label: '6:00 AM', emoji: '\u2600\ufe0f', value: '06'),
          _ChoiceOption(icon: 'sun', label: '7:00 AM', emoji: '\ud83c\udf1f', value: '07'),
          _ChoiceOption(icon: 'sun', label: '8:00 AM', emoji: '\ud83c\udf24\ufe0f', value: '08'),
          _ChoiceOption(icon: 'sun', label: '9:00 AM', emoji: '\ud83c\udf23\ufe0f', value: '09'),
        ],
      ),
    );
  }

  // ── 8. Bedtime ──────────────────────────────────────────────────────
  Widget _buildStep08Bedtime() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'When do you go to bed?',
      subtitle: 'We\u2019ll wind down your evening quests.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'bedtime',
        options: const [
          _ChoiceOption(icon: 'moon', label: '9:00 PM', emoji: '\ud83c\udf19', value: '21'),
          _ChoiceOption(icon: 'moon', label: '10:00 PM', emoji: '\ud83c\udf1b', value: '22'),
          _ChoiceOption(icon: 'moon', label: '11:00 PM', emoji: '\ud83c\udf03', value: '23'),
          _ChoiceOption(icon: 'moon', label: '12:00 AM', emoji: '\u2b50', value: '00'),
        ],
      ),
    );
  }

  // ── 9. Top Goals ────────────────────────────────────────────────────
  Widget _buildStep09TopGoals() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'What are your top goals?',
      subtitle: 'Pick up to 3 \u2014 we\u2019ll prioritise these.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'top_goals',
        multiSelect: true,
        maxSelect: 3,
        options: const [
          _ChoiceOption(icon: 'dumbbell', label: 'Get fit', emoji: '\ud83c\udfcb\ufe0f', value: 'fitness'),
          _ChoiceOption(icon: 'zap', label: 'Be productive', emoji: '\u26a1', value: 'productivity'),
          _ChoiceOption(icon: 'book', label: 'Learn more', emoji: '\ud83d\udcda', value: 'learning'),
          _ChoiceOption(icon: 'leaf', label: 'Be mindful', emoji: '\ud83c\udf3f', value: 'mindfulness'),
          _ChoiceOption(icon: 'heart', label: 'Mental health', emoji: '\ud83d\udc9c', value: 'mental_health'),
          _ChoiceOption(icon: 'homeOutlined', label: 'Organise home', emoji: '\ud83e\uddf9', value: 'organise'),
        ],
      ),
    );
  }

  // ── 10. Daily Quest Count ───────────────────────────────────────────
  Widget _buildStep10DailyQuests() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'How many quests per day?',
      subtitle: 'Start small and build up \u2014 consistency beats volume.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'daily_quests',
        options: const [
          _ChoiceOption(icon: 'star', label: '3 quests (Easy start)', value: '3'),
          _ChoiceOption(icon: 'flame', label: '5 quests (Balanced)', value: '5'),
          _ChoiceOption(icon: 'rocket', label: '7 quests (All in)', value: '7'),
        ],
      ),
    );
  }

  // ── 11. Habit Categories ────────────────────────────────────────────
  Widget _buildStep11HabitCategories() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'Which categories interest you?',
      subtitle: 'We\u2019ll suggest habits from these.',
      body: _choiceGrid(
        columns: 2,
        responseKey: 'habit_categories',
        multiSelect: true,
        maxSelect: 4,
        options: const [
          _ChoiceOption(icon: 'dumbbell', label: 'Fitness', emoji: '\ud83c\udfcb\ufe0f', value: 'fitness'),
          _ChoiceOption(icon: 'book', label: 'Learning', emoji: '\ud83d\udcda', value: 'learning'),
          _ChoiceOption(icon: 'leaf', label: 'Wellness', emoji: '\ud83c\udf3f', value: 'wellness'),
          _ChoiceOption(icon: 'briefcase', label: 'Career', emoji: '\ud83d\udcbc', value: 'career'),
          _ChoiceOption(icon: 'homeOutlined', label: 'Home', emoji: '\ud83c\udfe0', value: 'home'),
          _ChoiceOption(icon: 'heart', label: 'Social', emoji: '\ud83d\udc91', value: 'social'),
        ],
      ),
    );
  }

  // ── 12. Priority Habits ─────────────────────────────────────────────
  Widget _buildStep12PriorityHabits() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'Pick your starter habits',
      subtitle: 'Choose 2\u20134 habits to begin with.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'priority_habits',
        multiSelect: true,
        maxSelect: 4,
        options: const [
          _ChoiceOption(icon: 'droplet', label: 'Drink 2L water', emoji: '\ud83d\udca7', value: 'hydrate'),
          _ChoiceOption(icon: 'dumbbell', label: 'Gym session', emoji: '\ud83c\udfcb\ufe0f', value: 'gym'),
          _ChoiceOption(icon: 'book', label: 'Read 20 min', emoji: '\ud83d\udcda', value: 'reading'),
          _ChoiceOption(icon: 'moon', label: 'Meditate', emoji: '\ud83e\ude18', value: 'meditation'),
          _ChoiceOption(icon: 'homeOutlined', label: 'Clean room', emoji: '\ud83e\uddf9', value: 'cleanroom'),
          _ChoiceOption(icon: 'zap', label: 'Morning jog', emoji: '\ud83c\udfc3', value: 'jog'),
        ],
      ),
    );
  }

  // ── 13. Readiness Goals ─────────────────────────────────────────────
  Widget _buildStep13ReadinessGoals() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'What\u2019s your readiness target?',
      subtitle: 'The gauge on your dashboard tracks this daily.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'readiness_target',
        options: const [
          _ChoiceOption(icon: 'target', label: '70% \u2014 Stay consistent', value: '70'),
          _ChoiceOption(icon: 'target', label: '80% \u2014 Push harder', value: '80'),
          _ChoiceOption(icon: 'target', label: '90% \u2014 Near perfect', value: '90'),
          _ChoiceOption(icon: 'star', label: '100% \u2014 All or nothing', value: '100'),
        ],
      ),
    );
  }

  // ── 14. Mascot Voice ────────────────────────────────────────────────
  Widget _buildStep14MascotVoice() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'How should Qubi talk to you?',
      subtitle: 'Pick the tone that keeps you motivated.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'mascot_voice',
        options: const [
          _ChoiceOption(icon: 'zap', label: 'Coach \u2014 Direct and punchy', value: 'coach'),
          _ChoiceOption(icon: 'heart', label: 'Friend \u2014 Warm and encouraging', value: 'friend'),
          _ChoiceOption(icon: 'star', label: 'Mentor \u2014 Calm and wise', value: 'mentor'),
        ],
      ),
    );
  }

  // ── 15. Daily Time Budget ───────────────────────────────────────────
  Widget _buildStep15TimeBudget() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'How much time per day?',
      subtitle: 'We\u2019ll fit your quests into this window.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'daily_time_budget',
        options: const [
          _ChoiceOption(icon: 'clock', label: '15 minutes', value: '15'),
          _ChoiceOption(icon: 'clock', label: '30 minutes', value: '30'),
          _ChoiceOption(icon: 'clock', label: '45 minutes', value: '45'),
          _ChoiceOption(icon: 'clock', label: '60+ minutes', value: '60'),
        ],
      ),
    );
  }

  // ── 16. Theme Preference ────────────────────────────────────────────
  Widget _buildStep16Theme() {
    return _scaffold(
      mascot: _mascot(52),
      title: 'Pick your vibe',
      subtitle: 'Light, dark, or match your system.',
      body: _choiceGrid(
        columns: 1,
        responseKey: 'theme_preference',
        options: const [
          _ChoiceOption(icon: 'sun', label: 'Light mode', emoji: '\u2600\ufe0f', value: 'light'),
          _ChoiceOption(icon: 'moon', label: 'Dark mode', emoji: '\ud83c\udf19', value: 'dark'),
          _ChoiceOption(icon: 'settings', label: 'Follow system', emoji: '\ud83d\udcbb', value: 'system'),
        ],
      ),
    );
  }

  // ── 17. Confirm & Launch ────────────────────────────────────────────
  Widget _buildStep17Confirm() {
    final responses = _app.responses;
    final firstName = _app.displayName.split(' ').first;
    final focus = _focusLabel(responses['focus'] ?? responses['top_goals']);
    final wake = responses['wake_time'] ?? '?';
    final bed = responses['bedtime'] ?? '?';
    final quests = responses['daily_quests'] ?? '3';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Stack(
              alignment: Alignment.center,
              children: [
                QubiMascot(size: 92, celebrating: true, bob: false),
                const Positioned(
                  top: -6,
                  right: -6,
                  child: Text('\ud83c\udf89', style: TextStyle(fontSize: 26)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You\u2019re all set, $firstName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Here\u2019s your plan — $quests quests/day, wake $wake:00, bed $bed:00.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _summaryCard(icon: 'target', title: 'Focus \u00b7 $focus', subtitle: 'Your quests are tuned around it', accent: AppColors.primary),
                const SizedBox(height: 10),
                _summaryCard(icon: 'clock', title: 'Wake $wake:00 \u00b7 Bed $bed:00', subtitle: 'We\u2019ll schedule around your rhythm', accent: AppColors.accent),
                const SizedBox(height: 10),
                _summaryCard(icon: 'flame', title: '+50 XP Starter Boost', subtitle: 'Banked \u00b7 your streak begins today', accent: AppColors.gold),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _primaryButton(label: 'Lock Plan & Launch Dashboard \ud83d\ude80', onTap: _launch),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // INSPECTOR PANEL
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildInspectorPanel(bool isDark) {
    final data = _app.onboardingDataJson;
    final pretty = const JsonEncoder.withIndent('  ').convert(data);

    return Positioned(
      top: 80,
      right: 12,
      left: 12,
      bottom: 100,
      child: GestureDetector(
        onVerticalDragEnd: (_) => setState(() => _showInspector = false),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xE60F172A)
                : const Color(0xF0FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '\ud83d\udd0d Inspector \u2014 Live JSON',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showInspector = false),
                    child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${_step + 1}/${_progress.length} \u00b7 profiles.onboarding_data',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      pretty,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF93C5FD),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 200.ms)
          .slideY(begin: -0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════

  Widget _scaffold({
    required Widget mascot,
    required String title,
    String? subtitle,
    required Widget body,
    bool centerTitle = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
            child: mascot,
          ),
          SizedBox(height: centerTitle ? 20 : 16),
          Text(
            title,
            textAlign: centerTitle ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 26),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _mascot(double size) => QubiMascot(size: size, bob: true);

  Widget _choiceGrid({
    required List<_ChoiceOption> options,
    required String responseKey,
    int columns = 1,
    bool multiSelect = false,
    int maxSelect = 3,
  }) {
    return _MultiChoiceGrid(
      options: options,
      responseKey: responseKey,
      columns: columns,
      multiSelect: multiSelect,
      maxSelect: maxSelect,
      existingValues: _app.responses[responseKey]?.split(','),
      onPick: (key, value) {
        _app.saveResponse(key, value);
        if (!multiSelect) Future.delayed(250.ms, _next);
      },
      onMultiComplete: () {
        if (multiSelect) Future.delayed(250.ms, _next);
      },
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDeep],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required Widget icon,
    required String label,
    required Color background,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
          boxShadow: [AppSpacing.shadow],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.inkLight : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dividerLine() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or with email',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: isDark ? AppColors.borderDark : AppColors.border),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
    Color bg,
    Color border, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.5), fontSize: 15),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  String _focusLabel(String? v) {
    if (v == null) return 'Your goals';
    if (v.contains('fitness')) return 'Fitness';
    if (v.contains('productivity')) return 'Productivity';
    if (v.contains('learning')) return 'Learning';
    if (v.contains('mindfulness')) return 'Mindfulness';
    if (v.contains('mental')) return 'Mental Health';
    if (v.contains('organise')) return 'Home Organising';
    return 'Your goals';
  }

  Widget _summaryCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.20),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: AppIcons.stroke(icon, size: 20, color: accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkLight : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SHARED SUB-WIDGETS
// ════════════════════════════════════════════════════════════════════════

class _ChoiceOption {
  const _ChoiceOption({
    required this.icon,
    required this.label,
    required this.value,
    this.emoji,
  });

  final String icon;
  final String label;
  final String value;
  final String? emoji;
}

class _MultiChoiceGrid extends StatefulWidget {
  const _MultiChoiceGrid({
    required this.options,
    required this.responseKey,
    required this.columns,
    required this.multiSelect,
    required this.maxSelect,
    this.existingValues,
    required this.onPick,
    required this.onMultiComplete,
  });

  final List<_ChoiceOption> options;
  final String responseKey;
  final int columns;
  final bool multiSelect;
  final int maxSelect;
  final List<String>? existingValues;
  final void Function(String key, String value) onPick;
  final VoidCallback onMultiComplete;

  @override
  State<_MultiChoiceGrid> createState() => _MultiChoiceGridState();
}

class _MultiChoiceGridState extends State<_MultiChoiceGrid> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingValues?.toSet() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: widget.columns == 1 ? 64 : 100,
            ),
            itemCount: widget.options.length,
            itemBuilder: (context, i) {
              final opt = widget.options[i];
              final isSelected = _selected.contains(opt.value);
              return _ChoiceCard(
                option: opt,
                compact: widget.columns > 1,
                selected: isSelected,
                onTap: () {
                  if (widget.multiSelect) {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(opt.value);
                      } else if (_selected.length < widget.maxSelect) {
                        _selected.add(opt.value);
                      }
                    });
                  } else {
                    setState(() => _selected = {opt.value});
                    widget.onPick(widget.responseKey, opt.value);
                  }
                },
              );
            },
          ),
        ),
        if (widget.multiSelect && _selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              widget.onPick(widget.responseKey, _selected.join(','));
              widget.onMultiComplete();
            },
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Text(
                'Continue (${_selected.length} selected)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.onTap,
    this.compact = false,
    this.selected = false,
  });

  final _ChoiceOption option;
  final VoidCallback onTap;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opt = option;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: 160.ms,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.border),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected ? [] : [AppSpacing.shadow],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.chip : AppColors.chipMuted),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: opt.emoji != null
                      ? Text(opt.emoji!, style: const TextStyle(fontSize: 20))
                      : AppIcons.stroke(
                          opt.icon,
                          size: 20,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  opt.label,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkLight : AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButtonRound extends StatelessWidget {
  const _IconButtonRound({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final String icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
            boxShadow: [AppSpacing.shadow],
          ),
          child: Center(
            child: AppIcons.stroke(
              icon,
              size: 18,
              color: isDark ? AppColors.inkLight : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
