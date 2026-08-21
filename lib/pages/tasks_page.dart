import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modals/photo_proof_sheet.dart';
import '../models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/qubi_mascot.dart';
import 'qubi_page.dart';

enum _ViewMode { matrix, list, heatmap }

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _nameController = TextEditingController();
  final _timeController = TextEditingController(text: '8:00 AM');
  String _category = 'Wellness';
  String _emoji = '✅';
  _ViewMode _viewMode = _ViewMode.matrix;

  static const _categories = [
    ('\ud83d\udcaa', 'Fitness'),
    ('\ud83d\udcda', 'Learning'),
    ('\ud83e\uddd8', 'Wellness'),
    ('\ud83e\uddf9', 'Chores'),
    ('\ud83c\udfa8', 'Creative'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

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
              SliverToBoxAdapter(child: _viewSwitcher(context)),
              SliverToBoxAdapter(
                child: switch (_viewMode) {
                  _ViewMode.matrix => _stickyMatrix(context, app),
                  _ViewMode.list => _dailyList(context, app),
                  _ViewMode.heatmap => _calendarHeatmap(context, app),
                },
              ),
              SliverToBoxAdapter(child: _legend(context)),
              SliverToBoxAdapter(child: _sectionHeader(context, 'Manage Quests')),
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
                    itemBuilder: (context, i) => _habitManageRow(context, app, app.habits[i]),
                  ),
                ),
              SliverToBoxAdapter(child: _addHabitCard(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Quest Plan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a today-cell to snap your photo proof.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.mutedLight : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                AppIcons.stroke('flame', size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${app.completedCount} done',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View switcher ───────────────────────────────────────────────────────

  Widget _viewSwitcher(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          // AI Schedule Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.success.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gemini routine optimized for ${context.read<AppState>().readiness}% Readiness',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // View toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainer : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
            ),
            child: Row(
              children: [
                _viewTab('Grid', _ViewMode.matrix, 'grid', ink, muted),
                _viewTab('List', _ViewMode.list, 'list', ink, muted),
                _viewTab('Heat', _ViewMode.heatmap, 'calendar', ink, muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewTab(String label, _ViewMode mode, String icon, Color ink, Color muted) {
    final active = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: active
                ? BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcons.stroke(
                  icon,
                  size: 12,
                  color: active ? Colors.white : muted,
                  strokeWidth: 2.2,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sticky spreadsheet matrix ───────────────────────────────────────────

  Widget _stickyMatrix(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final today = app.todayIndex;

    const nameColWidth = 130.0;
    const cellWidth = 44.0;
    const cellHeight = 48.0;
    const dayHeaderHeight = 40.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: LiquidGlassCard(
        radius: AppSpacing.radiusCard,
        padding: EdgeInsets.zero, // Matrix manages its own internal layout
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Column(
            children: [
              // Header row: QUEST label + day headers
              Container(
                height: dayHeaderHeight,
                color: isDark ? AppColors.surfaceContainer : AppColors.surfaceContainerLow,
                child: Row(
                  children: [
                    // Fixed left column header
                    SizedBox(
                      width: nameColWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'QUEST',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Scrollable day headers
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(
                          children: [
                            for (var d = 0; d < 7; d++)
                              SizedBox(
                                width: cellWidth,
                                child: Center(
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: d == today
                                          ? AppColors.primary
                                          : (isDark ? AppColors.chip : Colors.transparent),
                                      border: d == today
                                          ? null
                                          : Border.all(
                                              color: AppColors.glassEdge,
                                              width: 0.5,
                                            ),
                                    ),
                                    child: Text(
                                      AppState.days[d],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: d == today ? Colors.white : muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
              // Habit rows with sticky left column
              if (app.habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const QubiMascot(size: 48, celebrating: true),
                      const SizedBox(height: 12),
                      Text(
                        'No quests yet — ask Qubi to build your routine!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                for (var r = 0; r < app.habits.length; r++)
                  _stickyMatrixRow(
                    context: context,
                    app: app,
                    habit: app.habits[r],
                    cellWidth: cellWidth,
                    cellHeight: cellHeight,
                    nameColWidth: nameColWidth,
                    today: today,
                    isDark: isDark,
                    ink: ink,
                    muted: muted,
                    isLast: r == app.habits.length - 1,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stickyMatrixRow({
    required BuildContext context,
    required AppState app,
    required Habit habit,
    required double cellWidth,
    required double cellHeight,
    required double nameColWidth,
    required int today,
    required bool isDark,
    required Color ink,
    required Color muted,
    required bool isLast,
  }) {
    return Container(
      height: cellHeight,
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.borderDark.withValues(alpha: 0.6)
                      : AppColors.border.withValues(alpha: 0.7),
                  width: 0.5,
                ),
              ),
            ),
      child: Row(
        children: [
          // Sticky left column — habit name
          GestureDetector(
            onTap: () {
              final status = app.statusOf(habit.id, today);
              if (status == QuestStatus.pending) {
                showPhotoProofSheet(context, habit);
              }
            },
            child: Container(
              width: nameColWidth,
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        Text(
                          habit.time,
                          maxLines: 1,
                          style: TextStyle(fontSize: 9.5, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrollable day cells
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    SizedBox(
                      width: cellWidth,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            if (d == today) {
                              final status = app.statusOf(habit.id, today);
                              if (status == QuestStatus.pending) {
                                showPhotoProofSheet(context, habit);
                              }
                            }
                          },
                          child: _matrixCell(
                            status: app.statusOf(habit.id, d),
                            isToday: d == today,
                            isDark: isDark,
                            size: 30,
                          ),
                        ),
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

  Widget _matrixCell({
    required QuestStatus status,
    required bool isToday,
    required bool isDark,
    double size = 30,
  }) {
    // Cell states per spec:
    // - PENDING (today): solid orange border (#FF6B35), light orange fill
    // - PENDING (future): dotted border (Color(0xFFCBD5E1)), target time
    // - VERIFIED: solid Sage Green (#52B788) fill + checkmark
    // - MISSED: soft muted gray tint (Color(0xFFF1F5F9)) with dash (-)
    final (widget, cellColor) = switch (status) {
      QuestStatus.verified => (
          AppIcons.stroke('check', size: 14, color: AppColors.success, strokeWidth: 2.6),
          AppColors.success,
        ),
      QuestStatus.missed => (
          AppIcons.stroke('minus', size: 14, color: AppColors.muted, strokeWidth: 2.6),
          AppColors.muted,
        ),
      QuestStatus.pending => (
          isToday
              ? AppIcons.stroke('camera', size: 13, color: AppColors.primary, strokeWidth: 2.4)
              : const SizedBox.shrink(),
          AppColors.primary,
        ),
    };

    // Background colors:
    // Verified = sage green tint; Missed = soft gray (0xFFF1F5F9);
    // Today-pending = light orange wash; Future-pending = transparent.
    final bgColor = switch (status) {
      QuestStatus.verified => AppColors.success.withValues(alpha: 0.16),
      QuestStatus.missed => (isDark
          ? const Color(0xFF1E2124)
          : const Color(0xFFF1F5F9)),
      QuestStatus.pending => (isToday
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent),
    };

    // Border styles per spec:
    // Verified = solid green; Missed = solid muted;
    // Today-pending = solid orange; Future-pending = dotted subtle edge.
    final border = switch (status) {
      QuestStatus.verified => Border.all(
          color: AppColors.success.withValues(alpha: 0.5),
          width: 1.4,
        ),
      QuestStatus.missed => Border.all(
          color: AppColors.muted.withValues(alpha: 0.35),
          width: 1.4,
        ),
      QuestStatus.pending => (isToday
          ? Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.4,
            )
          : Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.0,
              // Dashed visual via semi-transparency
            )),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: border,
      ),
      child: widget,
    );
  }

  // ── Daily list view ─────────────────────────────────────────────────────

  Widget _dailyList(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final today = app.todayIndex;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: LiquidGlassCard(
        radius: AppSpacing.radiusCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcons.stroke('calendar', size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Today · ${_todayLabel()}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
                ),
                const Spacer(),
                Text(
                  '${app.completedCount}/${app.habits.length}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (app.habits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const QubiMascot(size: 48, celebrating: true),
                      const SizedBox(height: 12),
                      Text(
                        'No quests yet — ask Qubi to build your routine!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < app.habits.length; i++)
                _dailyListRow(context, app, app.habits[i], today, isDark, ink, muted),
          ],
        ),
      ),
    );
  }

  Widget _dailyListRow(
    BuildContext context,
    AppState app,
    Habit habit,
    int today,
    bool isDark,
    Color ink,
    Color muted,
  ) {
    final status = app.statusOf(habit.id, today);
    const xp = 50;

    return GestureDetector(
      onTap: () {
        if (status == QuestStatus.pending) {
          showPhotoProofSheet(context, habit);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: status == QuestStatus.verified
              ? AppColors.success.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == QuestStatus.verified
                ? AppColors.success.withValues(alpha: 0.2)
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Text(habit.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      decoration: status == QuestStatus.verified
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    habit.time,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            switch (status) {
              QuestStatus.pending => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$xp XP',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              QuestStatus.verified => const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 22,
                ),
              QuestStatus.missed => Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.muted,
                  size: 22,
                ),
            },
          ],
        ),
      ),
    );
  }

  // ── Calendar heatmap view ───────────────────────────────────────────────

  Widget _calendarHeatmap(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: LiquidGlassCard(
        radius: AppSpacing.radiusCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Heatmap',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Darker = more quests verified that day',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 14),
            // Day labels
            Row(
              children: [
                const SizedBox(width: 28),
                for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Heatmap grid — last 5 weeks
            for (var week = 0; week < 5; week++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    // Week label
                    SizedBox(
                      width: 28,
                      child: Text(
                        'W${5 - week}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: muted),
                      ),
                    ),
                    for (var day = 0; day < 7; day++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _heatCell(
                            intensity: _heatIntensity(app, week, day),
                            isDark: isDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Less', style: TextStyle(fontSize: 9, color: muted)),
                const SizedBox(width: 6),
                for (var i = 0; i <= 4; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _heatColor(i / 4, isDark),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Text('More', style: TextStyle(fontSize: 9, color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _heatIntensity(AppState app, int week, int day) {
    final index = day - (4 - week) * 7;
    if (index < 0 || index >= 7) return 0;
    final total = app.habits.length;
    if (total == 0) return 0;
    var verified = 0;
    for (final h in app.habits) {
      if (app.statusOf(h.id, index) == QuestStatus.verified) verified++;
    }
    return verified / total;
  }

  Widget _heatCell({required double intensity, required bool isDark}) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: _heatColor(intensity, isDark),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 0.3,
        ),
      ),
    );
  }

  Color _heatColor(double t, bool isDark) {
    if (t <= 0) {
      return isDark ? AppColors.surfaceContainer : AppColors.surfaceContainerLow;
    }
    final base = AppColors.primary;
    return Color.lerp(
      isDark ? const Color(0xFF2A1A10) : const Color(0xFFFFF0E6),
      base,
      t.clamp(0.0, 1.0),
    )!;
  }

  String _todayLabel() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  // ── Legend ──────────────────────────────────────────────────────────────

  Widget _legend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendDot(AppColors.success, 'Verified', ink),
            const SizedBox(width: 14),
            _legendDot(AppColors.primary, 'Tap to verify', ink),
            const SizedBox(width: 14),
            _legendDot(AppColors.muted, 'Missed', ink),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, Color ink) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ink),
        ),
      ],
    );
  }

  // ── Manage quests ───────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
    );
  }

  Widget _habitManageRow(BuildContext context, AppState app, Habit habit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final isCustom = habit.id.startsWith('custom_');

    return LiquidGlassCard(
      radius: AppSpacing.radiusSoft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(habit.emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${habit.time} · ${habit.category}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          if (isCustom)
            GestureDetector(
              onTap: () => app.removeHabit(habit.id),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppIcons.stroke('trash', size: 16, color: AppColors.error, strokeWidth: 2.2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addHabitCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => _showAddSheet(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcons.stroke('plus', size: 18, color: Colors.white, strokeWidth: 2.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a custom quest',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qubi can also plan this for you in chat.',
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
    );
  }

  Widget _emptyQuests(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLightDark : AppColors.muted;
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
              color: ink,
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
              color: muted,
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

  Future<void> _showAddSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.glassDark : AppColors.glassLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
              border: Border.all(color: AppColors.glassEdge),
            ),
            child: StatefulBuilder(
              builder: (sheetContext, setSheetState) => Column(
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
                  const SizedBox(height: 16),
                  Text(
                    'New Quest',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                      border: Border.all(color: AppColors.glassEdge),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                      decoration: InputDecoration(
                        hintText: 'Quest name',
                        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (emoji, name) in _categories)
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            _category = name;
                            _emoji = emoji;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _category == name
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.chip,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                              border: Border.all(
                                color: _category == name
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$emoji $name',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _category == name ? AppColors.primaryDeep : ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                      border: Border.all(color: AppColors.glassEdge),
                    ),
                    child: TextField(
                      controller: _timeController,
                      keyboardType: TextInputType.datetime,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                      decoration: InputDecoration(
                        hintText: 'Time (e.g. 8:00 AM)',
                        hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(13),
                          child: AppIcons.stroke('clock', size: 18, color: AppColors.primary),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      context.read<AppState>().addHabit(
                            name: name,
                            category: _category,
                            time: _timeController.text.trim().isEmpty
                                ? '8:00 AM'
                                : _timeController.text.trim(),
                            emoji: _emoji,
                          );
                      _nameController.clear();
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
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Add Quest',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
