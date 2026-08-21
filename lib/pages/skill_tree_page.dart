import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/questify_logo.dart';

class SkillTreePage extends StatelessWidget {
  const SkillTreePage({super.key});

  static const _skills = [
    (
      name: 'Intellect',
      desc: 'Learn, read & grow',
      icon: 'book',
      tint: Color(0xFF4F8CFF),
      xp: 1820,
      target: 2200,
    ),
    (
      name: 'Fitness',
      desc: 'Move & train daily',
      icon: 'dumbbell',
      tint: Color(0xFFFF6B35),
      xp: 1250,
      target: 1600,
    ),
    (
      name: 'Discipline',
      desc: 'Stay consistent',
      icon: 'shield',
      tint: Color(0xFF8C9AB1),
      xp: 640,
      target: 1000,
    ),
    (
      name: 'Focus',
      desc: 'Deep-work sessions',
      icon: 'target',
      tint: Color(0xFFE8634A),
      xp: 300,
      target: 800,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppState>();
    final level = 1 + (app.xp ~/ 500);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const QuestifyLogo(size: 38, shape: QuestifyLogoShape.circle),
                    ),
                    const SizedBox(width: 10),
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
                    _IconButton(icon: 'bell'),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Skill Tree',
                            style: AppFonts.display.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Complete quests to level up each skill.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDeep],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lv $level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _SkillCard(skill: _skills[i], isDark: isDark),
                  childCount: _skills.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill, required this.isDark});

  final ({String name, String desc, String icon, Color tint, int xp, int target}) skill;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final progress = (skill.xp / skill.target).clamp(0.0, 1.0);
    final level = skill.xp ~/ 500;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassDark : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.glassEdge, width: 1),
        boxShadow: [AppSpacing.glassShadow],
      ),
      child: Stack(
        children: [
          // Gradient tint at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skill.tint.withValues(alpha: isDark ? 0.12 : 0.08),
                    skill.tint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: skill.tint),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: skill.tint.withValues(alpha: isDark ? 0.20 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: AppIcons.stroke(
                          skill.icon,
                          size: 20,
                          color: skill.tint,
                          strokeWidth: 2.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lv $level',
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.inkLight : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  skill.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark ? AppColors.gaugeTrackDark : AppColors.gaugeTrack,
                    valueColor: AlwaysStoppedAnimation(skill.tint),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${skill.xp}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.inkLight : AppColors.ink,
                      ),
                    ),
                    Text(
                      ' / ${skill.target} XP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.mutedLightDark : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassDark : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassEdge, width: 1),
        boxShadow: [AppSpacing.glassShadow],
      ),
      child: Center(
        child: AppIcons.stroke(
          icon,
          size: 19,
          color: isDark ? AppColors.mutedLightDark : AppColors.muted,
        ),
      ),
    );
  }
}
