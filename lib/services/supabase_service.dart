import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves environment config from `.env` and reports whether real backend
/// credentials are present. With placeholder values the app runs in a fully
/// offline DEMO mode so development and widget tests never hit a network.
class AppConfig {
  AppConfig._();

  static const String _placeholderUrl = 'https://YOUR-PROJECT.supabase.co';

  /// Reads an env var, tolerating a not-yet-loaded (or test) environment.
  static String _env(String key, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    return dotenv.get(key, fallback: fallback);
  }

  static String get supabaseUrl => _env('SUPABASE_URL', '');
  static String get supabaseAnonKey => _env('SUPABASE_ANON_KEY', '');
  static String get openRouterKey => _env('OPENROUTER_API_KEY', '');
  static String get openRouterModel =>
      _env('OPENROUTER_MODEL', 'nvidia/nemotron-3.5-lightning:free');
  static String get openRouterVisionModel =>
      _env('OPENROUTER_VISION_MODEL', 'google/gemma-4-26b-a4b-it:free');

  /// True when the app should talk to a real Supabase project.
  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl != _placeholderUrl &&
      !supabaseAnonKey.startsWith('your-');

  /// True when a real OpenRouter key is present (sk-or-v1- + hex suffix).
  /// Placeholders like `sk-or-v1-your-key-here` fail the hex check, so the app
  /// falls back to demo mode instead of hammering the API with a fake token.
  static bool get aiConfigured =>
      RegExp(r'^sk-or-v1-[a-f0-9]{20,}$').hasMatch(openRouterKey);
}

/// Classified auth errors so the UI can render specific guidance instead of
/// catching raw [AuthException] strings.
enum AuthErrorType {
  alreadyRegistered,
  rateLimited,
  emailDeliveryFailed,
  emailNotVerified,
  weakPassword,
  invalidCredentials,
  invalidEmail,
  cancelled,
  networkError,
  unknown,
}

/// Structured result from auth operations. Callers inspect [errorType] for
/// specific UI guidance instead of parsing raw exception strings.
class AuthResult {
  const AuthResult._({
    required this.success,
    this.response,
    this.errorType,
    this.message,
  });

  const AuthResult.success(AuthResponse response)
      : this._(success: true, response: response);

  const AuthResult.failure(AuthErrorType errorType, String message)
      : this._(success: false, errorType: errorType, message: message);

  final bool success;
  final AuthResponse? response;
  final AuthErrorType? errorType;
  final String? message;

  String get friendlyMessage {
    switch (errorType) {
      case AuthErrorType.alreadyRegistered:
        return 'An account already exists for this email — try signing in.';
      case AuthErrorType.rateLimited:
        return 'Too many attempts. Wait a minute and try again.';
      case AuthErrorType.emailDeliveryFailed:
        return 'We couldn\'t send the confirmation email — check your address and try again.';
      case AuthErrorType.emailNotVerified:
        return 'Please verify your email before signing in.';
      case AuthErrorType.weakPassword:
        return 'Password is too weak — use at least 6 characters.';
      case AuthErrorType.invalidCredentials:
        return 'Invalid email or password. Please check your credentials or create a new account.';
      case AuthErrorType.invalidEmail:
        return 'Please enter a valid email address.';
      case AuthErrorType.cancelled:
        return 'Sign-in was cancelled.';
      case AuthErrorType.networkError:
        return 'Network error — check your connection and try again.';
      case AuthErrorType.unknown:
        return message ?? 'Something went wrong. Please try again.';
      case null:
        return message ?? 'Something went wrong. Please try again.';
    }
  }
}

/// Single source of truth for Supabase access. Every query is scoped by the
/// authenticated user — the database enforces the same rule via RLS
/// (`auth.uid() = user_id`), so a leaked anon key cannot read another user.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;
  bool _initializing = false;
  bool _backendOnline = false;

  /// The underlying client. Throws if Supabase is not configured/initialized.
  SupabaseClient get client {
    if (!isConfigured) {
      throw StateError('Supabase is not configured (demo mode).');
    }
    return Supabase.instance.client;
  }

  bool get isConfigured => AppConfig.supabaseConfigured;

  /// True only when the configured credentials were verified against the
  /// live project (ping succeeds). Prevents a broken/mismatched key from
  /// masquerading as a synced backend.
  bool get backendOnline => isConfigured && _backendOnline;

  bool get isSignedIn => backendOnline && client.auth.currentSession != null;

  String? get userId => isSignedIn ? client.auth.currentUser?.id : null;

  /// Async-init is a no-op when keys are placeholders (demo mode). When
  /// configured, it verifies the credentials work. Supabase.initialize is
  /// already called in main.dart with hardcoded credentials, so this method
  /// only performs the ping check.
  Future<void> init() async {
    if (!AppConfig.supabaseConfigured || _initialized || _initializing) return;
    _initializing = true;
    try {
      // Supabase.initialize is already called in main.dart — skip re-init.
      // Just verify the backend is reachable.
      _backendOnline = await _ping();
      _initialized = true;
    } catch (_) {
      _initialized = false;
      _backendOnline = false;
    } finally {
      _initializing = false;
    }
  }

  /// Lightweight health probe: the auth settings endpoint accepts any valid
  /// project key and rejects bad ones with 401 — perfect for a boot check.
  Future<bool> _ping() async {
    try {
      final res = await http
          .get(
            Uri.parse('${AppConfig.supabaseUrl}/auth/v1/settings'),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            },
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fires whenever auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthState> get authState {
    if (!isConfigured) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Classifies a raw [Exception] into an [AuthErrorType] by inspecting the
  /// message text — Supabase surfaces different strings per error code.
  static AuthErrorType _classifyError(Object error) {
    if (error is SocketException) {
      return AuthErrorType.networkError;
    }
    if (error is HandshakeException) {
      return AuthErrorType.networkError;
    }
    final msg = error is AuthException ? error.message : error.toString();
    final lower = msg.toLowerCase();

    if (lower.contains('already_registered') ||
        lower.contains('already been registered') ||
        lower.contains('user already exists')) {
      return AuthErrorType.alreadyRegistered;
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_confirm') ||
        lower.contains('email confirmation')) {
      return AuthErrorType.emailNotVerified;
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('email rate limit exceeded')) {
      return AuthErrorType.rateLimited;
    }
    if (lower.contains('email') &&
        (lower.contains('delivery') ||
            lower.contains('bounce') ||
            lower.contains('not a valid email'))) {
      return AuthErrorType.emailDeliveryFailed;
    }
    if (lower.contains('weak password') ||
        lower.contains('password should be at least')) {
      return AuthErrorType.weakPassword;
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return AuthErrorType.invalidCredentials;
    }
    if (lower.contains('invalid email') || lower.contains('valid email')) {
      return AuthErrorType.invalidEmail;
    }
    if (lower.contains('timeout') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return AuthErrorType.networkError;
    }
    return AuthErrorType.unknown;
  }

  /// Google OAuth. On web this performs a redirect flow; on mobile/desktop it
  /// exchanges a native ID token (works on Android/iOS).
  Future<AuthResponse> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final launched = await client.auth.signInWithOAuth(OAuthProvider.google);
        if (!launched) {
          throw Exception('Google sign-in did not launch.');
        }
        return AuthResponse(
          session: client.auth.currentSession,
          user: client.auth.currentUser,
        );
      }
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Google sign-in did not return an ID token.');
      }
      return await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );
    } on SocketException catch (e) {
      debugPrint('[auth] signInWithGoogle SocketException: ${e.message}');
      throw Exception(
        'Unable to reach the server — check your internet connection.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[auth] signInWithGoogle HandshakeException: ${e.message}');
      throw Exception(
        'SSL connection failed — check your network or try another Wi-Fi.',
      );
    }
  }

  /// Clears any lingering local session before attempting a new sign-up.
  ///
  /// Previous test accounts or stale sessions can pollute the auth state —
  /// calling this before `signUp` ensures a clean slate so the new account
  /// isn't silently attached to an old session.
  Future<void> prepareNewAccountSession() async {
    if (!isConfigured) return;
    if (client.auth.currentSession != null) {
      await client.auth.signOut();
    }
  }

  /// Email/password sign-up with robust error handling.
  ///
  /// When Supabase reports the email is **already registered**, this method
  /// returns [AuthResult.failure] with [AuthErrorType.alreadyRegistered] —
  /// the caller should toggle its UI to the sign-in tab while preserving the
  /// entered email so the user only needs to type their password.
  ///
  /// Returns `response.session == null` when email confirmation is ON — the
  /// caller must route to the OTP verification sheet.
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      await prepareNewAccountSession();
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      return AuthResult.success(response);
    } on AuthException catch (e) {
      final type = _classifyError(e);
      if (type == AuthErrorType.alreadyRegistered) {
        return AuthResult.failure(
          AuthErrorType.alreadyRegistered,
          'An account with this email already exists.',
        );
      }
      return AuthResult.failure(type, e.message);
    } on SocketException catch (e) {
      debugPrint('[auth] signUp SocketException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'Unable to reach the server — check your internet connection.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[auth] signUp HandshakeException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'SSL connection failed — check your network or try another Wi-Fi.',
      );
    } on TimeoutException {
      return AuthResult.failure(
        AuthErrorType.networkError,
        'Sign-up timed out — check your connection.',
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorType.unknown, e.toString());
    }
  }

  /// Email/password sign-in for existing accounts only.
  ///
  /// After a successful password check, this method inspects
  /// `user.emailConfirmedAt` — if the email is **not yet verified** the
  /// session is immediately destroyed and an [AuthResult] with
  /// [AuthErrorType.emailNotVerified] is returned so the UI can route to
  /// the OTP verification sheet.
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      // Block unverified emails from accessing the app.
      if (user != null && user.emailConfirmedAt == null) {
        await client.auth.signOut();
        return const AuthResult.failure(
          AuthErrorType.emailNotVerified,
          'Please verify your email before signing in.',
        );
      }
      return AuthResult.success(response);
    } on AuthException catch (e) {
      return AuthResult.failure(_classifyError(e), e.message);
    } on SocketException catch (e) {
      debugPrint('[auth] signIn SocketException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'Unable to reach the server — check your internet connection.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[auth] signIn HandshakeException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'SSL connection failed — check your network or try another Wi-Fi.',
      );
    } on TimeoutException {
      return AuthResult.failure(
        AuthErrorType.networkError,
        'Sign-in timed out — check your connection.',
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorType.unknown, e.toString());
    }
  }

  // ── In-app 6-digit OTP ─────────────────────────────────────────────────

  /// Attempts sign-up and auto-resends a fresh OTP code.
  ///
  /// If the account was just created, the signUp call itself dispatches the
  /// first code. If the email is already registered but unverified, this
  /// method catches the error and calls `auth.resend` to guarantee a fresh
  /// 6-digit code is in the user's inbox.
  ///
  /// Returns a status map:
  /// - `{'status': 'code_sent'}` — code dispatched, show the OTP sheet.
  /// - `{'status': 'already_verified'}` — account exists and is verified,
  ///   the caller should switch to sign-in mode.
  /// - `{'status': 'error', 'message': '...'}` — something went wrong.
  Future<Map<String, String>> signUpOrResendOtp(
    String email,
    String password,
  ) async {
    try {
      await prepareNewAccountSession();
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      // Email confirmation OFF → user is already logged in.
      if (response.session != null) {
        return {'status': 'code_sent'};
      }
      // Email confirmation ON → code was sent with the signUp call.
      return {'status': 'code_sent'};
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      // Already registered but unverified — resend a fresh code.
      if (lower.contains('already_registered') ||
          lower.contains('already been registered') ||
          lower.contains('user already exists')) {
        try {
          await client.auth.resend(
            type: OtpType.signup,
            email: email.trim(),
          );
          debugPrint('[auth] signUpOrResendOtp: resent code to $email');
          return {'status': 'code_sent'};
        } on AuthException catch (resendErr) {
          if (resendErr.statusCode == '429' ||
              (resendErr.code?.contains('over_email_send_rate_limit') ??
                  false)) {
            return {
              'status': 'error',
              'message': 'Please wait 60 seconds before requesting another code.',
            };
          }
          return {'status': 'error', 'message': resendErr.message};
        }
      }
      // Already verified → tell the caller to switch to sign-in.
      if (lower.contains('already been confirmed') ||
          lower.contains('email already confirmed') ||
          lower.contains('already_verified')) {
        return {'status': 'already_verified'};
      }
      return {'status': 'error', 'message': e.message};
    } on SocketException catch (e) {
      debugPrint('[auth] signUpOrResendOtp SocketException: ${e.message}');
      return {
        'status': 'error',
        'message': 'Unable to reach the server — check your internet connection.',
      };
    } on HandshakeException catch (e) {
      debugPrint('[auth] signUpOrResendOtp HandshakeException: ${e.message}');
      return {
        'status': 'error',
        'message': 'SSL connection failed — check your network or try another Wi-Fi.',
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'Request timed out — check your connection.',
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Signs in an existing user and blocks unverified emails.
  ///
  /// On success returns [AuthResult.success]. If the password is correct but
  /// `emailConfirmedAt` is null, the session is destroyed and
  /// [AuthResult.failure] with [AuthErrorType.emailNotVerified] is returned
  /// so the caller can open the OTP verification sheet.
  Future<AuthResult> signInExistingUser(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user != null && user.emailConfirmedAt == null) {
        await client.auth.signOut();
        debugPrint('[auth] signInExistingUser: unverified email, session cleared');
        return const AuthResult.failure(
          AuthErrorType.emailNotVerified,
          'Account unverified. Please enter the verification code sent to your email.',
        );
      }
      return AuthResult.success(response);
    } on AuthException catch (e) {
      return AuthResult.failure(_classifyError(e), e.message);
    } on SocketException catch (e) {
      debugPrint('[auth] signInExistingUser SocketException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'Unable to reach the server — check your internet connection.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[auth] signInExistingUser HandshakeException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'SSL connection failed — check your network or try another Wi-Fi.',
      );
    } on TimeoutException {
      return AuthResult.failure(
        AuthErrorType.networkError,
        'Sign-in timed out — check your connection.',
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorType.unknown, e.toString());
    }
  }

  /// Verifies the 6-digit OTP code, persists the session locally, and
  /// returns the verified [AuthResponse] so the UI can navigate immediately.
  ///
  /// Returns the raw [AuthResponse] on success and rethrows [AuthException]
  /// on failure — the OTP sheet catches and displays the error directly.
  Future<AuthResponse> verifyAndLoginOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.signup,
      );
      if (response.session != null) {
        await client.auth.setSession(response.session!.refreshToken!);
        debugPrint('[auth] verifyAndLoginOtp: session persisted for ${response.user?.email}');
        return response;
      }
      throw const AuthException(
        'Verification succeeded, but session could not be established.',
      );
    } on SocketException catch (e) {
      debugPrint('[auth] verifyAndLoginOtp SocketException: ${e.message}');
      throw Exception('Unable to reach the server — check your internet connection.');
    } on HandshakeException catch (e) {
      debugPrint('[auth] verifyAndLoginOtp HandshakeException: ${e.message}');
      throw Exception('SSL connection failed — check your network or try another Wi-Fi.');
    }
  }

  /// Dispatches a fresh 6-digit OTP code to the given email.
  ///
  /// Intercepts HTTP 429 / rate-limit errors and returns a human-readable
  /// cooldown string. Rethrows all other [AuthException]s.
  Future<void> triggerResendCode(String email) async {
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      debugPrint('[auth] triggerResendCode: fresh code sent to $email');
    } on AuthException catch (e) {
      if (e.statusCode == '429' ||
          (e.code?.contains('over_email_send_rate_limit') ?? false)) {
        throw 'Rate limit reached. Please wait 60 seconds before requesting a new code.';
      }
      rethrow;
    }
  }

  /// Sends a 6-digit verification code via Supabase Auth.
  ///
  /// When [isSignUp] is true the account is created alongside the OTP send.
  /// Kept for backward compatibility — prefer [signUpOrResendOtp] for new
  /// sign-up flows.
  Future<AuthResult> sendOtp(String email, {bool isSignUp = true}) async {
    try {
      if (isSignUp) {
        await prepareNewAccountSession();
        await client.auth.signUp(email: email, password: email);
      } else {
        await client.auth.signInWithOtp(email: email);
      }
      return const AuthResult._(success: true);
    } on AuthException catch (e) {
      final type = _classifyError(e);
      if (isSignUp && type == AuthErrorType.alreadyRegistered) {
        return AuthResult.failure(
          AuthErrorType.alreadyRegistered,
          'An account with this email already exists.',
        );
      }
      return AuthResult.failure(type, e.message);
    } on SocketException catch (e) {
      debugPrint('[auth] sendOtp SocketException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'Unable to reach the server — check your internet connection.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[auth] sendOtp HandshakeException: ${e.message}');
      return const AuthResult.failure(
        AuthErrorType.networkError,
        'SSL connection failed — check your network or try another Wi-Fi.',
      );
    } on TimeoutException {
      return AuthResult.failure(
        AuthErrorType.networkError,
        'OTP send timed out — check your connection.',
      );
    } catch (e) {
      return AuthResult.failure(AuthErrorType.unknown, e.toString());
    }
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await GoogleSignIn().signOut();
    await client.auth.signOut();
  }

  // ── Profiles ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isConfigured || userId == null) return null;
    final rows = await client
        .from('profiles')
        .select()
        .eq('id', userId!)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertProfile(Map<String, dynamic> values) async {
    if (!isConfigured || userId == null) return;
    await client
        .from('profiles')
        .update(values)
        .eq('id', userId!);
  }

  /// Case-insensitive availability pre-check for a desired username.
  ///
  /// Returns `true` when the name is free, `false` when taken, and `null`
  /// when the check can't run (demo/offline) — callers should treat `null`
  /// as "proceed; the unique index is the real gatekeeper."
  Future<bool?> usernameAvailable(String username) async {
    if (!isConfigured || userId == null) return null;
    try {
      final rows = await client.rpc(
        'username_available',
        params: {'p_username': username.trim()},
      );
      return rows as bool;
    } catch (_) {
      return null;
    }
  }

  // ── Habits ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchHabits() async {
    if (!isConfigured || userId == null) return [];
    final rows = await client
        .from('habits')
        .select()
        .eq('user_id', userId!)
        .order('sort_order');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> insertHabit(Map<String, dynamic> values) async {
    if (!isConfigured || userId == null) return;
    await client.from('habits').insert({...values, 'user_id': userId});
  }

  Future<void> deleteHabit(String habitId) async {
    if (!isConfigured || userId == null) return;
    await client.from('habits').delete().eq('id', habitId).eq('user_id', userId!);
  }

  // ── Habit completions ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCompletions({DateTime? since}) async {
    if (!isConfigured || userId == null) return [];
    var q = client
        .from('habit_completions')
        .select()
        .eq('user_id', userId!);
    if (since != null) {
      q = q.gte('completed_on', since.toIso8601String().substring(0, 10));
    }
    final rows = await q;
    return rows.cast<Map<String, dynamic>>();
  }

  /// Upserts the ledger row for (habit, day) — RLS guarantees owner scoping.
  /// Returns the row id so the `verify_completion` RPC can be called with it.
  Future<String?> upsertCompletion({
    required String habitId,
    required DateTime day,
    required String status,
    String? proofUrl,
  }) async {
    if (!isConfigured || userId == null) return null;
    final date = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final rows = await client.from('habit_completions').upsert({
      'user_id': userId,
      'habit_id': habitId,
      'completed_on': date,
      'status': status,
      'proof_url': ?proofUrl,
    }).select('id');
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  /// Banks +50 XP atomically server-side. Only fires when not already verified.
  Future<void> verifyCompletion(String completionId, {String? proofUrl}) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('verify_completion', params: {
      'p_completion_id': completionId,
      'p_proof_url': proofUrl ?? '',
    });
  }

  Future<void> incrementXp(int amount) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('increment_xp', params: {'amount': amount});
  }

  /// Real-time subscription: fires when any of MY completions change.
  Stream<List<Map<String, dynamic>>> watchCompletions() {
    if (!isConfigured || userId == null) return const Stream.empty();
    final controller = StreamController<List<Map<String, dynamic>>>();
    final channel = client
        .channel('completions:${userId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'habit_completions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId!,
          ),
          callback: (payload) async {
            controller.add(await fetchCompletions());
          },
        )
        .subscribe();
    controller.onCancel = () => channel.unsubscribe();
    return controller.stream;
  }

  // ── Qubi chats ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchChats({int limit = 100}) async {
    if (!isConfigured || userId == null) return [];
    final rows = await client
        .from('qubi_chats')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).reversed.cast<Map<String, dynamic>>().toList();
  }

  Future<void> insertChat(Map<String, dynamic> values) async {
    if (!isConfigured || userId == null) return;
    await client.from('qubi_chats').insert({...values, 'user_id': userId});
  }

  Future<void> clearChats() async {
    if (!isConfigured || userId == null) return;
    await client.from('qubi_chats').delete().eq('user_id', userId!);
  }

  // ── User settings ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchSettings() async {
    if (!isConfigured || userId == null) return null;
    final rows = await client.from('user_settings').select().eq('user_id', userId!);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertSettings(Map<String, dynamic> values) async {
    if (!isConfigured || userId == null) return;
    await client.from('user_settings').upsert({
      'user_id': userId,
      ...values,
    });
  }

  // ── Storage (photo proofs) ────────────────────────────────────────────────

  /// Uploads a compressed proof image to the private `photo_proofs` bucket
  /// under `photo_proofs/{uid}/{uuid}.jpg`. Returns the public read path.
  Future<String?> uploadPhotoProof(Uint8List bytes, {String? ext}) async {
    if (!isConfigured || userId == null) return null;
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}.${ext ?? 'jpg'}';
    final path = '${userId!}/$name';
    await client.storage.from('photo_proofs').uploadBinary(path, bytes);
    return path;
  }

  // ── Friends ──────────────────────────────────────────────────────────────

  /// Search users by username (for adding friends).
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (!isConfigured || userId == null) return [];
    try {
      final rows = await client.rpc(
        'search_users',
        params: {'p_query': query, 'p_limit': 20},
      );
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Send a friend request to another user.
  Future<void> sendFriendRequest(String receiverId) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('send_friend_request', params: {
      'p_receiver_id': receiverId,
    });
  }

  /// Accept a pending friend request.
  Future<void> acceptFriendRequest(String requestId) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('accept_friend_request', params: {
      'p_request_id': requestId,
    });
  }

  /// Decline a pending friend request.
  Future<void> declineFriendRequest(String requestId) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('decline_friend_request', params: {
      'p_request_id': requestId,
    });
  }

  /// Remove a bidirectional friendship.
  Future<void> removeFriend(String friendId) async {
    if (!isConfigured || userId == null) return;
    await client.rpc('remove_friend', params: {
      'p_friend_id': friendId,
    });
  }

  /// List all accepted friends with profile data.
  Future<List<Map<String, dynamic>>> getFriends() async {
    if (!isConfigured || userId == null) return [];
    try {
      final rows = await client.rpc('get_friends');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// List pending inbound friend requests.
  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    if (!isConfigured || userId == null) return [];
    try {
      final rows = await client.rpc('get_friend_requests');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get the global leaderboard.
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    if (!isConfigured) return [];
    try {
      final rows = await client.rpc('get_leaderboard', params: {
        'p_limit': limit,
      });
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

/// Fetches a public URL for a stored proof (for thumbnails in the matrix).
Future<Uri?> publicProofUrl(String path) async {
  if (!AppConfig.supabaseConfigured) return null;
  final signed = await SupabaseService.instance.client.storage
      .from('photo_proofs')
      .createSignedUrl(path, 3600);
  return Uri.tryParse(signed);
}

/// Wraps raw bytes in a base64 data-URI for vision model payloads.
String base64DataUri(Uint8List bytes, String mimeType) {
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

// ═══════════════════════════════════════════════════════════════════════════
// SupabaseAuthService — Production-grade Signup + OTP pipeline
// ═══════════════════════════════════════════════════════════════════════════

/// Dedicated auth service for the sign-up → OTP → session pipeline.
///
/// Consumed by the OTP verification sheet and the onboarding auth UI.
/// Returns plain status maps (`'code_sent'`, `'logged_in'`, `'error'`)
/// so callers never have to inspect raw Supabase types.
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── 1. Sign up or resend code ──────────────────────────────────────────

  /// Attempts sign-up. If the email is already registered but unverified,
  /// automatically resends a fresh 6-digit code.
  ///
  /// Returns:
  /// - `{'status': 'code_sent', 'message': '...'}` — show the OTP sheet.
  /// - `{'status': 'logged_in', 'message': '...'}` — email confirmation OFF.
  /// - `{'status': 'error', 'message': '...'}` — show error in UI.
  Future<Map<String, String>> signUpWithOtp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
      );

      // Email confirmation ON — user created, awaiting verification.
      if (response.user != null && response.session == null) {
        return {
          'status': 'code_sent',
          'message': 'Verification code sent to $cleanEmail',
        };
      }

      // Email confirmation OFF — user logged in immediately.
      if (response.session != null) {
        return {
          'status': 'logged_in',
          'message': 'Account created successfully!',
        };
      }

      // Fallback — treat as code_sent.
      return {
        'status': 'code_sent',
        'message': 'Check your email for the verification code.',
      };
    } on AuthException catch (e) {
      // Existing unverified account — force a fresh resend.
      if (e.message.contains('already registered') ||
          e.code == 'user_already_exists') {
        try {
          await _client.auth.resend(
            type: OtpType.signup,
            email: cleanEmail,
          );
          debugPrint('[auth] signUpWithOtp: resent code to $cleanEmail');
          return {
            'status': 'code_sent',
            'message': 'Account pending verification. A fresh code was sent to $cleanEmail',
          };
        } on AuthException catch (resendError) {
          if (resendError.statusCode == '429' ||
              (resendError.code?.contains('over_email_send_rate_limit') ??
                  false)) {
            return {
              'status': 'error',
              'message': 'Rate limit reached. Please wait 60 seconds before trying again.',
            };
          }
          return {'status': 'error', 'message': resendError.message};
        }
      }
      return {'status': 'error', 'message': e.message};
    } on SocketException catch (e) {
      debugPrint('[auth] signUpWithOtp SocketException: ${e.message}');
      return {
        'status': 'error',
        'message': 'Unable to reach the server — check your internet connection.',
      };
    } on HandshakeException catch (e) {
      debugPrint('[auth] signUpWithOtp HandshakeException: ${e.message}');
      return {
        'status': 'error',
        'message': 'SSL connection failed — check your network or try another Wi-Fi.',
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'Request timed out — check your connection.',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // ── 2. Verify OTP and establish session ────────────────────────────────

  /// Verifies the 6-digit OTP, persists the session locally, and returns
  /// `true` on success. Throws a human-readable string on failure.
  Future<bool> verifyOtpAndLogin({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );

      if (response.session != null) {
        await _client.auth.setSession(response.session!.refreshToken!);
        debugPrint('[auth] verifyOtpAndLogin: session persisted for ${response.user?.email}');
        return true;
      }
      return false;
    } on AuthException catch (e) {
      throw e.message;
    } on SocketException catch (e) {
      debugPrint('[auth] verifyOtpAndLogin SocketException: ${e.message}');
      throw 'Unable to reach the server — check your internet connection.';
    } on HandshakeException catch (e) {
      debugPrint('[auth] verifyOtpAndLogin HandshakeException: ${e.message}');
      throw 'SSL connection failed — check your network or try another Wi-Fi.';
    } catch (e) {
      throw 'Failed to verify code: $e';
    }
  }

  // ── 3. Resend fresh OTP code ──────────────────────────────────────────

  /// Dispatches a fresh 6-digit OTP code. Throws a human-readable string
  /// on rate-limit (429) and rethrows the original [AuthException] otherwise.
  Future<void> resendOtpCode(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
      debugPrint('[auth] resendOtpCode: fresh code sent to $email');
    } on AuthException catch (e) {
      if (e.statusCode == '429' ||
          e.code == 'over_email_send_rate_limit') {
        throw 'Rate limit reached. Please wait 60 seconds before trying again.';
      }
      rethrow;
    }
  }

  // ── Resend verification via Edge Function ────────────────────────────

  /// Generates a random 6-digit numeric code.
  static String _generateCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  /// Sends a 6-digit verification code via the Resend Edge Function.
  ///
  /// Returns `{'status': 'code_sent'}` on success.
  /// Returns `{'status': 'error', 'message': '...'}` on failure.
  Future<Map<String, String>> sendResendCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final code = _generateCode();

    try {
      final supabaseUrl = AppConfig.supabaseUrl;
      final anonKey = AppConfig.supabaseAnonKey;
      final url = '$supabaseUrl/functions/v1/send-verification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'action': 'send',
          'email': cleanEmail,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[auth] sendResendCode: code sent to $cleanEmail');
        return {'status': 'code_sent'};
      }

      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? 'Failed to send verification email';

      // Rate limit from Edge Function or Resend.
      if (response.statusCode == 429) {
        return {
          'status': 'error',
          'message': 'Rate limit reached. Please wait a moment before trying again.',
        };
      }

      debugPrint('[auth] sendResendCode error ${response.statusCode}: $errorMsg');
      return {'status': 'error', 'message': errorMsg};
    } on SocketException catch (e) {
      debugPrint('[auth] sendResendCode SocketException: ${e.message}');
      return {
        'status': 'error',
        'message': 'Unable to reach the server — check your internet connection.',
      };
    } on HandshakeException catch (e) {
      debugPrint('[auth] sendResendCode HandshakeException: ${e.message}');
      return {
        'status': 'error',
        'message': 'SSL connection failed — check your network or try another Wi-Fi.',
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'Request timed out — check your connection.',
      };
    } catch (e) {
      debugPrint('[auth] sendResendCode unexpected: $e');
      return {'status': 'error', 'message': 'Failed to send verification email.'};
    }
  }

  /// Verifies the 6-digit code via the Resend Edge Function.
  ///
  /// Returns `true` on success. Throws a human-readable string on failure.
  Future<bool> verifyResendCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    try {
      final supabaseUrl = AppConfig.supabaseUrl;
      final anonKey = AppConfig.supabaseAnonKey;
      final url = '$supabaseUrl/functions/v1/send-verification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'action': 'verify',
          'email': cleanEmail,
          'code': cleanCode,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[auth] verifyResendCode: verified for $cleanEmail');
        return true;
      }

      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? 'Verification failed';
      throw errorMsg;
    } on SocketException catch (e) {
      debugPrint('[auth] verifyResendCode SocketException: ${e.message}');
      throw 'Unable to reach the server — check your internet connection.';
    } on HandshakeException catch (e) {
      debugPrint('[auth] verifyResendCode HandshakeException: ${e.message}');
      throw 'SSL connection failed — check your network or try another Wi-Fi.';
    } on TimeoutException {
      throw 'Request timed out — check your connection.';
    } on String {
      rethrow;
    } catch (e) {
      debugPrint('[auth] verifyResendCode unexpected: $e');
      throw 'Failed to verify code. Please try again.';
    }
  }

  /// Confirms a Supabase user's email via the Edge Function admin API.
  ///
  /// Used after Resend verification for legacy accounts where Supabase
  /// email confirmation is ON and the user hasn't confirmed yet.
  /// Returns `true` on success. Throws a human-readable string on failure.
  Future<bool> confirmUserEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final supabaseUrl = AppConfig.supabaseUrl;
      final anonKey = AppConfig.supabaseAnonKey;
      final url = '$supabaseUrl/functions/v1/send-verification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'action': 'confirm-email',
          'email': cleanEmail,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[auth] confirmUserEmail: confirmed for $cleanEmail');
        return true;
      }

      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? 'Failed to confirm email';
      throw errorMsg;
    } on SocketException catch (e) {
      debugPrint('[auth] confirmUserEmail SocketException: ${e.message}');
      throw 'Unable to reach the server — check your internet connection.';
    } on HandshakeException catch (e) {
      debugPrint('[auth] confirmUserEmail HandshakeException: ${e.message}');
      throw 'SSL connection failed — check your network or try another Wi-Fi.';
    } on TimeoutException {
      throw 'Request timed out — check your connection.';
    } on String {
      rethrow;
    } catch (e) {
      debugPrint('[auth] confirmUserEmail unexpected: $e');
      throw 'Failed to confirm email. Please try again.';
    }
  }
}
