import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/rank_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/liquid_glass_card.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Consumer<AppState>(
          builder: (context, app, _) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _hero(context, app)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                  children: [
                    _statPill(context, 'flame', '${app.streak}', 'Day Streak', const Color(0xFFFF6B35)),
                    _statPill(context, 'zap', _fmt(app.xp), 'Total XP', AppColors.primary),
                    _statPill(context, 'check', '${app.weeklyRate}%', 'Verify Rate', AppColors.success),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: _weekCard(context, app)),
              SliverToBoxAdapter(child: _badgesCard(context, app)),
              SliverToBoxAdapter(child: _accountCard(context, app)),
              SliverToBoxAdapter(child: _aboutCard(context, app)),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.glassDark : AppColors.glassLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassEdge, width: 1),
                boxShadow: [AppSpacing.glassShadow],
              ),
              child: AppIcons.stroke('settings', size: 20, color: muted, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final palette = app.avatarColors(app.avatar);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: palette.last.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      app.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppColors.glassDark : Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              app.displayName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              '@${app.username}',
              style: TextStyle(fontSize: 13.5, color: muted, fontWeight: FontWeight.w600),
            ),
            if (app.email.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(app.email, style: TextStyle(fontSize: 12.5, color: muted)),
            ],
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chip(AppColors.gold, app.memberSinceLabel),
                  const SizedBox(width: 8),
                  _chip(AppColors.accent, '\ud83e\udd48 Silver'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _rankBadge(context, app),
            const SizedBox(height: 16),
            _totalXpBlock(context, app.xp),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _editProfile(context, app),
              child: Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.center,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcons.stroke('edit', size: 16, color: Colors.white, strokeWidth: 2),
                    const SizedBox(width: 6),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _rankBadge(BuildContext context, AppState app) {
    final tier = RankService.tierForXp(app.xp, totalCompletions: app.completedCount);
    final rankColor = tier.color;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: rankColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: rankColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tier.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              tier.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalXpBlock(BuildContext context, int xp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = 1 + (xp ~/ 500);
    final intoLevel = xp - (level - 1) * 500;
    final toNext = (level * 500) - xp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TOTAL XP',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.mutedLight,
                ),
              ),
              const Spacer(),
              Text(
                '$xp / ${level * 500}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.inkLight : AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (intoLevel / 500).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.gaugeTrack,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$toNext XP to Level ${level + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.mutedLightDark : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, AppState app) {
    final nameCtrl = TextEditingController(text: app.displayName);
    final userCtrl = TextEditingController(text: app.username);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.glassDark : AppColors.glassLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
              border: Border.all(color: AppColors.glassEdge),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 16),
                _sheetField(nameCtrl, 'Full Name', 'user', isDark),
                const SizedBox(height: 12),
                _sheetField(userCtrl, 'Username', 'sparkle', isDark),
                const SizedBox(height: 6),
                Text(
                  '3\u201316 chars \u00b7 letters, numbers, _ \u2014 usernames are unique to you.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final error = await context.read<AppState>().setProfile(
                          name: nameCtrl.text,
                          username: userCtrl.text,
                        );
                    if (!sheetContext.mounted) return;
                    if (error != null) {
                      ScaffoldMessenger.of(sheetContext)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, String icon, bool isDark) {
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
        border: Border.all(color: AppColors.glassEdge),
      ),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(13),
            child: AppIcons.stroke(icon, size: 18, color: AppColors.primary),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _statPill(BuildContext context, String icon, String value, String label, Color accent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: AppIcons.stroke(icon, size: 12, color: accent),
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: muted),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _weekCard(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final bars = app.weeklyXpBars;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = app.todayIndex;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Weekly XP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${app.completedCount} verified',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BarChartWidget(
              values: bars,
              labels: labels,
              activeIndex: today,
              height: 180,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgesCard(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Badges', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
                const Spacer(),
                Text(
                  '${app.badges.where((b) => b.earned).length}/${app.badges.length} earned',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in app.badges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: badge.earned
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : (isDark ? AppColors.chip : AppColors.chipMuted),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: badge.earned
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.borderDark,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(badge.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badge.earned ? AppColors.primaryDeep : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final signedIn = app.isSignedIn;

    final accent = signedIn
        ? AppColors.success
        : (app.isDemo ? AppColors.gold : muted);
    final providerLabel = signedIn
        ? 'Signed in with Google \u00b7 synced'
        : (app.isDemo ? 'Local demo \u2014 backend not connected' : 'Not signed in');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: signedIn ? Colors.white : (isDark ? AppColors.chip : AppColors.chipMuted),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassEdge, width: 1),
              ),
              child: Center(
                child: signedIn
                    ? AppIcons.googleLogo(size: 22)
                    : AppIcons.stroke(
                        app.isDemo ? 'shield' : 'user',
                        size: 20,
                        color: accent,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn && app.email.isNotEmpty ? app.email : app.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    providerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutRow(String icon, String label, String value, Color accent, Color muted, Color ink) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          icon == 'replay'
              ? Icon(Icons.replay, size: 18, color: accent)
              : AppIcons.stroke(icon, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    Widget row(String icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              AppIcons.stroke(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: muted)),
              ),
              Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row('info', 'App Version', '1.0.0'),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                app.resetOnboardingForReplay();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: _aboutRow('replay', 'Replay Onboarding', 'Walk through the 17-step wizard again', AppColors.primary, muted, ink),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final settings = context.read<SettingsProvider>();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Your local progress is saved. Sign in again anytime to re-sync.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                settings.tap();
                await context.read<AppState>().signOut();
              },
              child: Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
