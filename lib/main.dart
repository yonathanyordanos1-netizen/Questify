import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'pages/ranks_page.dart';
import 'pages/tasks_page.dart';
import 'modals/photo_proof_sheet.dart';
import 'providers/app_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/stats_provider.dart';
import 'services/supabase_service.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/premium_backdrop.dart';
import 'widgets/questify_logo.dart';
import 'widgets/soft_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface every error to the console, even if the on-screen error widget
  // can't paint (broken renderer, etc.) — the boot logs below then pinpoint
  // exactly where the app stalls.
  FlutterError.onError = (details) {
    debugPrint('[questify] FlutterError: ${details.exception}');
    debugPrint('[questify] ${details.stack}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[questify] zone error: $error\n$stack');
    return true;
  };

  await runZonedGuarded(() async {
    debugPrint('[boot] ensureInitialized done');
    // `.env` is bundled as an asset; values fall back to demo-mode placeholders.
    await dotenv.load();
    debugPrint('[boot] .env loaded');

    // Initialize Supabase with hardcoded credentials (zero-trust backend).
    // The .env values are the same; this ensures the client is ready before
    // any UI that references Supabase.instance.client.
    const supabaseUrl = 'https://qnbrrxwctokuwxglcdjd.supabase.co';
    const supabaseKey = 'sb_publishable_qTECh9PHTWpUUUVZeSjoCw_k9vzYCaj';
    assert(supabaseUrl.isNotEmpty, 'Supabase URL must not be empty');
    assert(supabaseKey.isNotEmpty, 'Supabase anon key must not be empty');
    assert(
      supabaseKey.startsWith('sb_'),
      'Supabase key must start with sb_',
    );
    if (kDebugMode) {
      debugPrint('[boot] Supabase URL: $supabaseUrl');
      debugPrint('[boot] Supabase key: ${supabaseKey.substring(0, 12)}…');
    }
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      );
      debugPrint('[boot] Supabase initialized');
    } catch (e) {
      debugPrint('[boot] Supabase init failed (demo mode): $e');
      if (kDebugMode) {
        debugPrint('[boot] ─── SUPABASE INIT FAILURE DETAILS ───');
        debugPrint('[boot] URL: $supabaseUrl');
        debugPrint('[boot] Key: $supabaseKey');
        debugPrint('[boot] Error type: ${e.runtimeType}');
        debugPrint('[boot] Error: $e');
        debugPrint('[boot] ─────────────────────────────────────');
      }
    }

    final state = await AppState.load();
    debugPrint('[boot] AppState loaded '
        '(onboardingDone=${state.onboardingDone})');
    final settings = await SettingsProvider.load();
    debugPrint('[boot] Settings loaded (theme=${settings.themeMode.name})');
    final stats = StatsProvider();
    debugPrint('[boot] StatsProvider created');
    debugPrint('[boot] calling runApp…');
    runApp(QuestifyApp(state: state, settings: settings, stats: stats));
    debugPrint('[boot] runApp returned — first frame should paint now');
    // Hydrate from the backend in the background so a slow or unreachable
    // network never blocks the first frame — the splash paints instantly and
    // the app stays responsive while sync happens.
    unawaited(state.hydrateFromSupabase());
    // Deep-link & auth-state listener. Fires on:
    //   • signedIn   — Google OAuth redirect, OTP verify, deep-link callback
    //   • tokenRefreshed — silent token rotation keeps the session alive
    //   • signedOut  — user tapped "Sign out" or session was revoked
    //
    // BootScreen watches AppState.onboardingDone via a Consumer, so hydrate
    // automatically flips new users to the dashboard without an explicit
    // Navigator push — no white-screen gap between auth and home.
    SupabaseService.instance.authState.listen((authState) {
      final event = authState.event;
      final session = authState.session;
      debugPrint('[auth] event=$event');
      if (kDebugMode) {
        debugPrint('[auth] hasSession=${session != null}');
        debugPrint('[auth] userId=${session?.user.id}');
        debugPrint('[auth] email=${session?.user.email}');
        debugPrint('[auth] emailConfirmed=${session?.user.emailConfirmedAt}');
      }
      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          unawaited(state.hydrateFromSupabase());
          break;
        case AuthChangeEvent.signedOut:
          debugPrint('[auth] session ended');
          break;
        default:
          break;
      }
    });
  }, (error, stack) {
    debugPrint('[questify] uncaught zone error: $error\n$stack');
  });
}

class QuestifyApp extends StatelessWidget {
  const QuestifyApp({super.key, required this.state, required this.settings, required this.stats});

  final AppState state;
  final SettingsProvider settings;
  final StatsProvider stats;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<StatsProvider>.value(value: stats),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Questify',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const BootScreen(),
        ),
      ),
    );
  }
}

/// Boot splash → routes to the 17-step onboarding (new users) or the main
/// shell (existing users). Kicks off the update check on the way.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  int _stage = 0;
  bool _splashVisible = true;
  bool _splashFading = false;
  Timer? _splashTimer;
  Timer? _watchdog;
  bool _updatePromptShown = false;
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().checkForUpdate();
    _splashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _stage = 1);
      // Keep the splash fully opaque until the destination page has actually
      // painted its first frame — if that frame is slow, the splash just
      // holds, so the user never sees a black gap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint('[boot] destination first frame painted, fading splash');
        setState(() => _splashFading = true);
        Timer(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _splashVisible = false);
        });
      });
    });
    // Watchdog: logs every 2s so a stuck UI thread is obvious in the console.
    WidgetsBinding.instance.addPostFrameCallback((_) => _countFrame());
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      debugPrint('[boot] watchdog stage=$_stage frames=$_frames');
    });
  }

  void _countFrame() {
    _frames++;
    WidgetsBinding.instance.addPostFrameCallback((_) => _countFrame());
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (_stage == 1 && !_updatePromptShown && app.updateAvailable == true) {
      _updatePromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdatePrompt(context, app);
      });
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_stage == 1)
            StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final event = snapshot.data?.event;
                final session = snapshot.data?.session;

                // Signed out → always show onboarding (which has auth UI).
                if (event == AuthChangeEvent.signedOut) {
                  return const OnboardingPage();
                }

                // Signed in or token refreshed but email not verified
                // (shouldn't happen via signInWithEmail which already blocks
                // this, but acts as a safety net for direct session restore).
                if (session != null &&
                    session.user.emailConfirmedAt == null &&
                    (event == AuthChangeEvent.signedIn ||
                     event == AuthChangeEvent.tokenRefreshed)) {
                  // Sign out and route to onboarding so the user can verify.
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (mounted) {
                      await SupabaseService.instance.signOut();
                    }
                  });
                  return const OnboardingPage();
                }

                // Default: use AppState routing (onboarding done → main shell).
                final Widget routed =
                    app.onboardingDone ? const MainShell() : const OnboardingPage();
                return routed;
              },
            ),
          if (_splashVisible)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _splashFading ? 0 : 1,
                duration: 350.ms,
                curve: Curves.easeOut,
                child: const _SplashView(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showUpdatePrompt(BuildContext context, AppState app) async {
    final info = app.updateInfo;
    if (info == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Questify ${info.version} (build ${info.buildNumber}) is ready. '
          'Your streaks are saved — grab the update to get the latest quests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(kUpdateServerUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> {
  static const _statuses = [
    'Warming up Qubi…',
    'Syncing your quests…',
    'Preparing your streak…',
  ];

  int _statusIndex = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 950), (_) {
      if (!mounted) return;
      setState(() => _statusIndex = (_statusIndex + 1) % _statuses.length);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLightDark : AppColors.muted;

    return Stack(
      fit: StackFit.expand,
      children: [
        const PremiumBackdrop(),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              QuestifyLogo(size: 140, glow: true)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.94, 0.94),
                    end: const Offset(1.04, 1.04),
                    duration: 1600.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 34),
              Text(
                'Questify',
                style: TextStyle(
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primaryDeep,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Photo-proof every habit. Beat your streak.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 3),
              _SplashProgress(),
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: AnimatedSwitcher(
                  duration: 420.ms,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _statuses[_statusIndex],
                    key: ValueKey(_statusIndex),
                    style: TextStyle(
                      color: ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppBadge('v1.0.0', variant: AppBadgeVariant.secondary, dense: true),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indeterminate progress bar — the shadcn `Progress` analog: a thin pill
/// track with a soft gradient sweep instead of a raw spinner.
class _SplashProgress extends StatefulWidget {
  const _SplashProgress();

  @override
  State<_SplashProgress> createState() => _SplashProgressState();
}

class _SplashProgressState extends State<_SplashProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: 1500.ms,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const trackWidth = 168.0;
    const segment = 64.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: trackWidth,
          height: 4,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? AppColors.gaugeTrackDark : AppColors.gaugeTrack,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -segment + t * (trackWidth + segment),
                top: 0,
                bottom: 0,
                width: segment,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0),
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0),
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

/// The main app shell: an indexed tab stack + the floating glass navigation.
///
/// Tabs build lazily — only the active tab is constructed on first visit — so
/// finishing onboarding doesn't paint all pages at once (that heavy spike
/// could crash underpowered devices/emulators). Built pages stay alive in the
/// IndexedStack, preserving their scroll position and state.
///
/// 4-tab layout: Home (0), Tasks (1), Ranks (2), Profile (3).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 4 pages mapped to the 4 nav tabs (Skills removed from nav).
  static const List<Widget> _pages = [
    HomePage(),
    TasksPage(),
    RanksPage(),
    ProfilePage(),
  ];

  /// Whether each tab has been visited (and therefore built) yet.
  late final List<bool> _built = List<bool>.filled(_pages.length, false);

  @override
  void initState() {
    super.initState();
    debugPrint('[ui] MainShell built');
    _built[0] = true; // Home is the landing tab.
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild only on tab changes (not on every app state notification) so
    // switching tabs never repaints the whole shell or all pages.
    final index = context.select<AppState, int>((app) => app.activeTab);
    if (!_built[index]) _built[index] = true;
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        // Clearance for the Cal AI floating nav pill + camera FAB.
        padding: const EdgeInsets.only(bottom: 110),
        child: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _built[i]
                  ? RepaintBoundary(
                      key: ValueKey('tab_$i'),
                      child: _pages[i],
                    )
                  : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: index,
        onSelect: context.read<AppState>().setActiveTab,
        onVerify: () => showQuickVerify(context),
      ),
    );
  }
}
