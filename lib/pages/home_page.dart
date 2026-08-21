import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../modals/photo_proof_sheet.dart';
import '../models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/circular_analytics_gauge.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/neo_surface.dart';
import '../widgets/pressable.dart';
import '../widgets/questify_logo.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/soft_widgets.dart';
import '../widgets/qubi_mascot.dart';
import 'qubi_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _weekLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _categoryColors = {
    'Fitness': Color(0xFFFF6B35),
    'Intellect': Color(0xFF4F8CFF),
    'Discipline': Color(0xFF8C9AB1),
  };

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
              SliverToBoxAdapter(child: _header(context, app)),
              SliverToBoxAdapter(child: _greeting(context, app)),
              if (app.isNewAccount || (app.habits.length <= 4 && app.responses['ideal_day'] == null))
                SliverToBoxAdapter(child: _qubiFirstRunCard(context)),
              SliverToBoxAdapter(child: _hero(context, app)),
              SliverToBoxAdapter(child: _metricPills(context, app)),
              SliverToBoxAdapter(child: _sectionHeader(context, 'Today\'s Quests')),
              if (app.habits.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _emptyQuests(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverList.separated(
                    itemCount: app.habits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _questRow(context, app, app.habits[i], index: i),
                  ),
                ),
              SliverToBoxAdapter(child: _weekCard(context, app)),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open Qubi AI assistant',
            child: GestureDetector(
              onTap: () => openQubi(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: ExcludeSemantics(child: QuestifyLogo(size: 44)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Questify',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppColors.primaryFixedDim : AppColors.primaryDeep,
            ),
          ),
          const Spacer(),
          if (!app.isNewAccount)
            GestureDetector(
              onTap: () => openQubi(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const QubiMascot(size: 36),
              ),
            ),
          if (!app.isNewAccount) const SizedBox(width: 8),
          _RoundIcon(
            icon: 'bell',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 550.ms)
        .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic);
  }

  // ── Greeting ────────────────────────────────────────────────────────────

  Widget _greeting(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = app.displayName.split(' ').first;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(now).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isDark ? AppColors.mutedLightDark : AppColors.mutedLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_greetingWord()}, $firstName!',
            style: AppFonts.display.copyWith(fontSize: 26),
          ),
        ],
      ),
    )
        .animate(delay: 100.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  String _greetingWord() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  // ── Qubi first-run card ──────────────────────────────────────────────────

  Widget _qubiFirstRunCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Material(
        color: isDark ? AppColors.glassDark : AppColors.glassLight,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassEdge, width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF6B35), width: 2),
                    ),
                    child: const Center(child: QubiMascot(size: 48, bob: false)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hey! I\'m Qubi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What does your ideal day look like?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Tell me your wake time, workouts, focus hours, and bedtime...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () => openQubi(context),
                      child: const Center(
                        child: Text(
                          '✨ Describe My Day',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: 130.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  // ── Hero card ───────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = app.pendingTodayCount;
    final doneToday = app.habits.length - pending;
    final total = app.habits.length;
    final pct = total > 0 ? (doneToday / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: LiquidGlassCard(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 20),
        overlay: const GlassSheen(),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircularAnalyticsGauge(
                  value: app.readiness.toDouble(),
                  size: 176,
                  strokeWidth: 14,
                  gradientColors: const [
                    Color(0xFFFF6B35), // warm orange
                    Color(0xFF52B788), // sage green
                  ],
                  scoreText: '$pct%',
                  sublabel: 'complete',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Daily Readiness',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: isDark ? AppColors.inkLight : AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _weekdayLabel(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _heroStat(
                    isDark: isDark,
                    icon: 'camera',
                    value: '$pending',
                    label: pending == 1 ? 'Quest to go' : 'Quests to go',
                    accent: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _heroStat(
                    isDark: isDark,
                    icon: 'check',
                    value: '$doneToday',
                    label: 'Done today',
                    accent: AppColors.success,
                  ),
                ),
              ],
            ),
            if (pending > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AppIcons.stroke('camera', size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the camera below to verify and bank +50 XP each.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: isDark ? AppColors.mutedLight : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: 160.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _heroStat({
    required bool isDark,
    required String icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: neoSurfaceDecoration(isDark, radius: 16),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: AppIcons.stroke(icon, size: 16, color: accent, strokeWidth: 2.3),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? AppColors.inkLight : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isDark ? AppColors.mutedLightDark : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(DateTime d) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[d.weekday - 1];
  }

  // ── Metric tiles ────────────────────────────────────────────────────────

  Widget _metricPills(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _metricPill(
              isDark: isDark,
              icon: 'flame',
              value: '${app.streak}',
              label: 'Day Streak',
              accent: const Color(0xFFFF6B35),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricPill(
              isDark: isDark,
              icon: 'zap',
              value: _fmt(app.xp),
              label: 'Total XP',
              accent: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricPill(
              isDark: isDark,
              icon: 'trophy',
              value: '#${app.position}',
              label: 'League',
              accent: AppColors.gold,
            ),
          ),
        ],
      ),
    )
        .animate(delay: 280.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _metricPill({
    required bool isDark,
    required String icon,
    required String value,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: neoSurfaceDecoration(isDark, radius: 14),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: AppIcons.stroke(icon, size: 15, color: accent, strokeWidth: 2.3),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: isDark ? AppColors.mutedLightDark : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$n';
  }

  // ── Section header ──────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.title.copyWith(fontSize: 20),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.read<AppState>().setActiveTab(1),
            child: Row(
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(width: 2),
                AppIcons.stroke('chevronRight', size: 14, color: AppColors.primaryDeep),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: 360.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  // ── Empty state ─────────────────────────────────────────────────────────

  Widget _emptyQuests(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassDark : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.glassEdge, width: 1),
      ),
      child: Column(
        children: [
          const QubiMascot(size: 64, celebrating: true),
          const SizedBox(height: 16),
          Text(
            'No Quests Created Yet!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.inkLight : AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask Qubi "What\'s your ideal day?" to build your custom routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: isDark ? AppColors.mutedLightDark : AppColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => openQubi(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create Routine with Qubi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quest rows ──────────────────────────────────────────────────────────

  Widget _questRow(BuildContext context, AppState app, Habit habit, {int index = 0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = app.statusOf(habit.id, app.todayIndex);
    final accent = _categoryColors[habit.category] ?? AppColors.primary;
    const xp = 50;

    return Pressable(
      onTap: () {
        if (status == QuestStatus.pending) {
          showPhotoProofSheet(context, habit);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Text('${habit.name} already verified (+$xp XP) ✓'),
              ),
            );
        }
      },
      scale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassDark : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.glassEdge, width: 1),
          boxShadow: [AppSpacing.glassShadow],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  _checkButton(status, onTap: () => showPhotoProofSheet(context, habit)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.inkLight : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(habit.category, color: accent),
                            _chip(habit.time, icon: 'clock'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  switch (status) {
                    QuestStatus.pending => AppBadge('+$xp XP', variant: AppBadgeVariant.primary, dense: true),
                    QuestStatus.verified => AppBadge('✓ Done', variant: AppBadgeVariant.success, dense: true),
                    QuestStatus.missed => AppBadge('Missed', variant: AppBadgeVariant.outline, dense: true),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (420 + index * 60).ms)
        .fadeIn(duration: 550.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _checkButton(QuestStatus status, {required VoidCallback onTap}) {
    final (icon, color) = switch (status) {
      QuestStatus.pending => ('', AppColors.surfaceContainerHighest),
      QuestStatus.verified => ('check', AppColors.success),
      QuestStatus.missed => ('close', AppColors.primaryDeep),
    };

    if (status == QuestStatus.pending) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: AppIcons.stroke('camera', size: 16, color: AppColors.primary, strokeWidth: 2.2),
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: AppIcons.stroke(icon, size: 18, color: Colors.white, strokeWidth: 2.6),
      ),
    );
  }

  Widget _chip(String label, {String? icon, Color? color}) {
    final tint = color ?? AppColors.surfaceContainer;
    final fg = (color == null)
        ? AppColors.muted
        : (color.computeLuminance() > 0.5 ? AppColors.primaryDeep : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: color == null ? 1 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcons.stroke(icon, size: 11, color: AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  // ── This week ───────────────────────────────────────────────────────────

  Widget _weekCard(BuildContext context, AppState app) {
    final today = app.todayIndex;
    final bars = app.weeklyXpBars;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('This Week', style: AppFonts.title),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${app.completedCount} verified',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BarChartWidget(
              values: bars,
              labels: _weekLabels,
              activeIndex: today,
              height: 180,
            ),
          ],
        ),
      ),
    )
        .animate(delay: 640.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});

  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassEdge, width: 1),
          boxShadow: [AppSpacing.glassShadow],
        ),
        child: Center(
          child: AppIcons.stroke(icon, size: 19, color: AppColors.muted),
        ),
      ),
    );
  }
}
