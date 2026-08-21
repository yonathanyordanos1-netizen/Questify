import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/liquid_glass_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) => CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _appearanceCard(context, settings)),
              SliverToBoxAdapter(child: _feedbackCard(context, settings)),
              SliverToBoxAdapter(child: _friendsCard(context)),
              SliverToBoxAdapter(child: _dataCard(context, settings)),
              SliverToBoxAdapter(child: _accountCard(context)),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.glassDark : AppColors.glassLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.glassEdge, width: 1),
                boxShadow: [AppSpacing.glassShadow],
              ),
              child: AppIcons.stroke('chevronLeft', size: 20, color: muted, strokeWidth: 2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: muted),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 50,
      endIndent: 14,
      color: isDark ? AppColors.borderDark : AppColors.border,
    );
  }

  Widget _rowIcon(String icon, {required bool isDark}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: AppIcons.stroke(
          icon,
          size: 18,
          color: isDark ? AppColors.mutedLightDark : AppColors.muted,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String title, String? subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: muted)),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String icon, String title, String? subtitle, Widget trailing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _rowIcon(icon, isDark: isDark),
          const SizedBox(width: 12),
          _label(context, title, subtitle),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _segmentedTheme(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Row(
      children: [
        for (final (mode, label, icon) in [
          (ThemeMode.light, 'Light', 'sun'),
          (ThemeMode.system, 'Auto', 'moonStar'),
          (ThemeMode.dark, 'Dark', 'moon'),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => settings.setThemeMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: settings.themeMode == mode ? AppColors.primary : AppColors.chip,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: settings.themeMode == mode ? AppColors.primary : AppColors.glassEdge,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcons.stroke(
                        icon,
                        size: 16,
                        color: settings.themeMode == mode ? Colors.white : muted,
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: settings.themeMode == mode ? Colors.white : ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _appearanceCard(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _sectionTitle(context, 'Appearance'),
        _sectionCard(
          context,
          [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                children: [
                  _rowIcon('sparkle', isDark: isDark),
                  const SizedBox(width: 12),
                  _label(context, 'Theme', 'Pick a look for Questify'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: _segmentedTheme(context, settings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _feedbackCard(BuildContext context, SettingsProvider settings) {
    return Column(
      children: [
        _sectionTitle(context, 'Feedback'),
        _sectionCard(
          context,
          [
            _row(
              context,
              'zap',
              'Haptics',
              'Tactile taps & celebration buzz',
              Switch(
                value: settings.haptics,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primarySoft,
                onChanged: settings.setHaptics,
              ),
            ),
            _divider(context),
            _row(
              context,
              'bell',
              'Daily Reminder',
              settings.remindersEnabled ? 'Remind me at ${settings.reminderTime}' : 'Notifications off',
              Switch(
                value: settings.remindersEnabled,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primarySoft,
                onChanged: settings.setRemindersEnabled,
              ),
            ),
            if (settings.remindersEnabled) ...[
              _divider(context),
              _row(
                context,
                'clock',
                'Reminder Time',
                'Quest nudge every day',
                GestureDetector(
                  onTap: () => _pickTime(context, settings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(color: AppColors.glassEdge, width: 1),
                    ),
                    child: Text(
                      _prettyTime(settings.reminderTime),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDeep),
                    ),
                  ),
                ),
              ),
            ],
            _divider(context),
            _row(
              context,
              'flame',
              'Streak Alerts',
              'Warn me before my streak slips',
              Switch(
                value: settings.streakAlerts,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primarySoft,
                onChanged: settings.setStreakAlerts,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Friends ─────────────────────────────────────────────────────────────

  Widget _friendsCard(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    return Column(
      children: [
        _sectionTitle(context, 'Friends'),
        _sectionCard(
          context,
          [
            _row(
              context,
              'users',
              'Manage Friends',
              app.isSignedIn
                  ? 'View & accept friend requests'
                  : 'Sign in to add friends',
              GestureDetector(
                onTap: app.isSignedIn ? () => _showFriendsSheet(context) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: app.isSignedIn ? AppColors.primaryDeep : muted,
                    ),
                  ),
                ),
              ),
            ),
            _divider(context),
            _row(
              context,
              'search',
              'Find Players',
              'Search by username',
              GestureDetector(
                onTap: app.isSignedIn ? () => _showSearchSheet(context) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: AppColors.glassEdge, width: 1),
                  ),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: app.isSignedIn ? ink : muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showFriendsSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassDark : AppColors.glassLight,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet),
          ),
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: Column(
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
              'Friends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Friend requests and your friend list',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcons.stroke('users', size: 40, color: AppColors.muted),
                    const SizedBox(height: 14),
                    Text(
                      'No friend requests yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Search for players to add as friends.',
                      style: TextStyle(fontSize: 13, color: muted),
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

  Future<void> _showSearchSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SearchSheet(ink: ink, muted: muted),
    );
  }

  Future<void> _pickTime(BuildContext context, SettingsProvider settings) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(settings.reminderTime) ?? now,
      helpText: 'Daily reminder',
    );
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    settings.setReminderTime(hhmm);
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _prettyTime(String hhmm) {
    final t = _parseTime(hhmm);
    if (t == null) return hhmm;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    var hour = t.hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:${t.minute.toString().padLeft(2, '0')} $period';
  }

  Widget _dataCard(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    return Column(
      children: [
        _sectionTitle(context, 'Data'),
        _sectionCard(
          context,
          [
            _row(
              context,
              'trash',
              'Clear Image Cache',
              'Free up space from proof photos',
              GestureDetector(
                onTap: () => settings.clearCache(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
              ),
            ),
            _divider(context),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.read<AppState>().resetOnboardingForReplay();
                Navigator.of(context).pop();
              },
              child: _row(
                context,
                'replay',
                'Replay Onboarding',
                'Walk through the 17-step wizard again',
                Icon(Icons.chevron_right, size: 20, color: isDark ? AppColors.mutedLight : AppColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _accountCard(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;

    String status() {
      if (app.isSignedIn) return 'Synced to Supabase';
      if (app.isDemo) return 'Local demo — backend not connected';
      return 'Not signed in — sign in to sync';
    }

    Color statusColor() {
      if (app.isSignedIn) return AppColors.success;
      if (app.isDemo) return AppColors.gold;
      return muted;
    }

    return Column(
      children: [
        _sectionTitle(context, 'Account'),
        _sectionCard(
          context,
          [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editProfile(context),
              child: _row(
                context,
                'user',
                'Edit Profile',
                'Name & @username',
                Icon(Icons.chevron_right, size: 20, color: muted),
              ),
            ),
            _divider(context),
            _row(
              context,
              'shield',
              'Sync',
              status(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: statusColor().withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
            ),
            _divider(context),
            _row(
              context,
              'info',
              'App Version',
              'Questify 1.0.0',
              const Text(
                '1.0.0',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDeep),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Sign Out button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
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
              height: 50,
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
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _editProfile(BuildContext context) {
    final app = context.read<AppState>();
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
                _editField(nameCtrl, 'Full Name', isDark),
                const SizedBox(height: 12),
                _editField(userCtrl, 'Username', isDark),
                const SizedBox(height: 6),
                Text(
                  '3\u201316 chars \u00b7 letters, numbers, _ \u2014 usernames are unique.',
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
                      gradient: const LinearGradient(
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

  Widget _editField(TextEditingController ctrl, String hint, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassDark : AppColors.glassLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.glassEdge, width: 1),
      ),
      child: TextField(
        controller: ctrl,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.inkLight : AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? AppColors.mutedLightDark : AppColors.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Search sheet for finding players by username.
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.ink, required this.muted});

  final Color ink;
  final Color muted;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _controller;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final results = await SupabaseService.instance.searchUsers(query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
              'Find Players',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: widget.ink,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.ink,
                ),
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  hintStyle: TextStyle(
                    color: widget.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(13),
                    child: AppIcons.stroke(
                      'search',
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _search,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _results.isEmpty && _searched
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcons.stroke('search', size: 32, color: AppColors.muted),
                              const SizedBox(height: 10),
                              Text(
                                'No players found',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: widget.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try a different username.',
                                style: TextStyle(fontSize: 12, color: widget.muted),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final user = _results[i];
                            final name = (user['display_name'] ?? user['username'] ?? '') as String;
                            final username = (user['username'] ?? '') as String;
                            final userId = (user['id'] ?? '') as String;
                            return _SearchResultRow(
                              name: name,
                              username: username,
                              userId: userId,
                              ink: widget.ink,
                              muted: widget.muted,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.name,
    required this.username,
    required this.userId,
    required this.ink,
    required this.muted,
  });

  final String name;
  final String username;
  final String userId;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
          border: Border.all(color: AppColors.glassEdge),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: userId.isEmpty
                  ? null
                  : () async {
                      try {
                        await SupabaseService.instance.sendFriendRequest(userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Friend request sent!')),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not send request.')),
                          );
                        }
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep,
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
