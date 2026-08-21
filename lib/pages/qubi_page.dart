import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_provider.dart';
import '../services/openrouter_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/qubi_mascot.dart';
import '../widgets/soft_widgets.dart';

Future<void> openQubi(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const QubiPage()),
  );
}

class QubiPage extends StatefulWidget {
  const QubiPage({super.key});

  @override
  State<QubiPage> createState() => _QubiPageState();
}

class _QubiPageState extends State<QubiPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _streaming = false;
  String _streamingText = '';
  AiToolCall? _toolPlan;

  static const _suggestions = [
    '🌅 What\'s your ideal day?',
    '📋 Generate my routine',
    'Optimize my routine',
    'What hurts my streak?',
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Consumer<AppState>(
          builder: (context, app, _) => Column(
            children: [
              _header(context, app),
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _greetingCard(context, app),
                    const SizedBox(height: 14),
                    ..._chips(context),
                    const SizedBox(height: 12),
                    for (final message in app.chat)
                      _chatBubble(context, message, app),
                    if (_streamingText.isNotEmpty || _streaming)
                      _streamingBubble(context),
                    if (_toolPlan != null) _planProposal(context, app),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              _chatInput(context, app),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final online = OpenRouterService.instance.isConfigured;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: AppIcons.stroke('chevronLeft', size: 24, color: ink, strokeWidth: 2.2),
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Qubi AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.primaryFixedDim : AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(
                      online ? 'live' : 'demo',
                      variant: online ? AppBadgeVariant.success : AppBadgeVariant.gold,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your streak coach, 24/7',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
          if (app.chat.isNotEmpty)
            IconButton(
              onPressed: () {
                context.read<AppState>().clearChats();
                setState(() => _toolPlan = null);
              },
              icon: AppIcons.stroke('trash', size: 19, color: muted, strokeWidth: 2),
              tooltip: 'Clear chat',
            ),
        ],
      ),
    );
  }

  // ── Greeting card ───────────────────────────────────────────────────────

  Widget _greetingCard(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLightDark : AppColors.muted;
    final firstName = app.displayName.split(' ').first;

    return LiquidGlassCard(
      radius: AppSpacing.radiusCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(child: QubiMascot(size: 72, bob: false)),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.canvasDark.withValues(alpha: 0.5) : AppColors.canvas.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: Text(
                "Hey $firstName! You're on a ${app.streak}-day streak. "
                "Snap your proofs to hold #${app.position}.",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink, height: 1.4),
              ),
            ),
          ),
          if (!OpenRouterService.instance.isConfigured) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                children: [
                  AppIcons.stroke('zap', size: 15, color: AppColors.gold, strokeWidth: 2.3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo mode \u2014 add your OpenRouter API key to .env and Qubi goes live.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Suggestion chips ────────────────────────────────────────────────────

  List<Widget> _chips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _suggestions)
            GestureDetector(
              onTap: _streaming
                  ? null
                  : () {
                      if (s.startsWith('📋')) {
                        _generateRoutine(_inputCtrl.text);
                      } else {
                        _send(s);
                      }
                    },
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcons.stroke('sparkle', size: 12, color: AppColors.primary, strokeWidth: 2.2),
                    const SizedBox(width: 6),
                    Text(
                      s,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }

  // ── Bubbles ─────────────────────────────────────────────────────────────

  Widget _chatBubble(BuildContext context, ChatMessage message, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final user = message.fromUser;
    final isRoutineSuccess = message.text.contains('Tasks tab! 📋✨');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!user) ...[
                QubiMascot(size: 30, bob: false),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: user
                        ? AppColors.primary
                        : (isDark ? AppColors.glassDark : AppColors.glassLight),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(user ? 18 : 6),
                      bottomRight: Radius.circular(user ? 6 : 18),
                    ),
                    border: user ? null : Border.all(color: AppColors.glassEdge, width: 1),
                    boxShadow: [
                      if (!user) AppSpacing.glassShadow,
                      if (user)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: user ? Colors.white : ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (user) const SizedBox(width: 8),
            ],
          ),
          if (isRoutineSuccess && !user)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: GestureDetector(
                onTap: () {
                  context.read<AppState>().setActiveTab(1);
                  Navigator.of(context).maybePop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        '📋 Go to Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _streamingBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QubiMascot(size: 30, bob: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isDark ? AppColors.glassDark : AppColors.glassLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.glassEdge, width: 1),
              ),
              child: _streamingText.isEmpty
                  ? const _TypingDots()
                  : Text(
                      _streamingText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan proposal ───────────────────────────────────────────────────────

  Widget _planProposal(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    final muted = isDark ? AppColors.mutedLight : AppColors.muted;
    final plan = (_toolPlan!.args['habits'] as List? ?? []).cast<Map<String, dynamic>>();
    final planned = [for (final h in plan) PlannedHabit.fromArgs(h)];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        radius: AppSpacing.radiusCard,
        padding: const EdgeInsets.all(16),
        tint: AppColors.primary.withValues(alpha: 0.08),
        borderColor: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AppIcons.stroke('sparkle', size: 18, color: Colors.white, strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Routine plan proposed',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _toolPlan = null),
                  child: AppIcons.stroke('close', size: 16, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final h in planned)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AppIcons.stroke('check', size: 16, color: AppColors.success, strokeWidth: 2.8),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          h.title,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          h.timeOfDay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                context.read<AppState>().applyAiPlan(planned);
                context.read<AppState>().addAssistantMessage(
                      'Added ${planned.length} quest${planned.length == 1 ? '' : 's'} to your plan. '
                      'Snap a photo proof to bank your first +50 XP!',
                    );
                setState(() => _toolPlan = null);
              },
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSoft),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  'Approve & Add to Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input ───────────────────────────────────────────────────────────────

  Widget _chatInput(BuildContext context, AppState app) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkLight : AppColors.ink;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1318) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.glassDark : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.glassEdge,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  enabled: !_streaming,
                  style: TextStyle(color: ink, fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Ask Qubi anything\u2026',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _streaming ? null : () => _send(_inputCtrl.text),
              child: AnimatedContainer(
                duration: 200.ms,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: _streaming
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.primaryDeep],
                        ),
                  color: _streaming ? AppColors.muted : null,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!_streaming)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: _streaming
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : AppIcons.stroke('arrowUp', size: 22, color: Colors.white, strokeWidth: 2.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat logic ──────────────────────────────────────────────────────────

  String _systemPrompt(AppState app) {
    final r = app.responses;
    return [
      'You are Qubi, the friendly AI habit coach inside Questify \u2014 a '
          'photo-verified habit app. Be concise: max 3 short sentences.',
      'User profile:',
      '- Name: ${app.displayName}',
      '- Focus: ${r['focus'] ?? 'general'}',
      '- Streak style: ${r['streak_commitment'] ?? '\u2014'}',
      '- Wake: ${_prettyTime(r['wake_time'])} \u00b7 Bedtime: ${_prettyTime(r['bedtime'])}',
      '- Daily budget: ${r['daily_time_budget'] ?? '30'} min',
      '- Obstacle: ${r['obstacle'] ?? '\u2014'}',
      '- League: ${r['league'] ?? '\u2014'} \u00b7 Shield: ${r['shield'] == 'on' ? 'on' : 'off'}',
      '- Mascot voice: ${r['mascot_voice'] ?? 'Peppy'}',
      '- Targets: ${r['daily_quests'] ?? 3} quests/day',
      'Current stats: ${app.xp} XP, ${app.streak}-day streak, #${app.position} '
          'in Silver, ${app.weeklyRate}% week completion.',
      'Rules:',
      '- To build or change the user\u2019s routine, call the create_routine_plan '
          'tool with habits (title, category, frequency_days 0=Mon..6=Sun, '
          'time_of_day). The app shows an Approve & Add to Plan card.',
      '- Only call the tool when asked to build/change/optimize a routine.',
      '- All proofs are camera-captured; never suggest screenshots or gallery.',
      '- Write in the selected mascot voice (${r['mascot_voice'] ?? 'Peppy'}).',
    ].join('\n');
  }

  String _prettyTime(String? code) {
    if (code == null) return '\u2014';
    final hour = int.tryParse(code);
    if (hour == null) return code;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:00 $ampm';
  }

  List<AiMessage> _buildMessages() {
    final app = context.read<AppState>();
    final history = app.chat.length > 20 ? app.chat.sublist(app.chat.length - 20) : app.chat;
    return [
      AiMessage(role: 'system', content: _systemPrompt(app)),
      for (final m in history) AiMessage(role: m.fromUser ? 'user' : 'assistant', content: m.text),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: 400.ms,
        curve: Curves.easeOut,
      );
    });
  }

  // ── Routine generation (tool-calling) ────────────────────────────────

  String _routineSystemPrompt(AppState app, String idealDayDescription) {
    final r = app.responses;
    return [
      'You are Qubi, a habit coaching AI inside Questify — a photo-verified habit app.',
      'The user described their ideal daily schedule or wants a personalized routine.',
      '',
      if (idealDayDescription.isNotEmpty) ...[
        'User\'s ideal day description:',
        '"$idealDayDescription"',
        '',
      ],
      'User profile:',
      '- Name: ${app.displayName}',
      '- Focus: ${r['focus'] ?? 'general'}',
      '- Streak style: ${r['streak_commitment'] ?? '—'}',
      '- Wake: ${_prettyTime(r['wake_time'])} · Bedtime: ${_prettyTime(r['bedtime'])}',
      '- Daily budget: ${r['daily_time_budget'] ?? '30'} min',
      '- Obstacle: ${r['obstacle'] ?? '—'}',
      '',
      'Create a structured Notion-style routine plan with time blocks, habit categories,',
      'target times, and XP values. Use the create_routine_plan tool to output the plan.',
      '',
      'After the tool call, respond with a brief confirmation like:',
      '"That sounds amazing! Here\'s your personalized Notion-style Routine & Task system."',
      'Keep your text reply short — 1-2 sentences max.',
    ].join('\n');
  }

  Future<void> _generateRoutine(String idealDayDescription) async {
    final app = context.read<AppState>();

    app.addUserMessage(
      idealDayDescription.isNotEmpty
          ? 'Here\'s my ideal day: $idealDayDescription'
          : 'Generate my routine',
    );
    _inputCtrl.clear();
    _scrollToBottom();

    setState(() {
      _streaming = true;
      _streamingText = '';
      _toolPlan = null;
    });
    _scrollToBottom();

    try {
      final messages = [
        AiMessage(role: 'system', content: _routineSystemPrompt(app, idealDayDescription)),
        ...app.chat
            .sublist(math.max(0, app.chat.length - 10))
            .map((m) => AiMessage(role: m.fromUser ? 'user' : 'assistant', content: m.text)),
      ];

      final completion = await OpenRouterService.instance.complete(messages: messages);

      if (!mounted) return;

      if (completion.wantsToolCall) {
        final tool = completion.toolCalls!.first;
        if (tool.name == 'create_routine_plan') {
          setState(() => _toolPlan = tool);
          final planHabits = (tool.args['habits'] as List? ?? []).cast<Map<String, dynamic>>();
          final planned = [for (final h in planHabits) PlannedHabit.fromArgs(h)];

          context.read<AppState>().applyAiPlan(planned);

          final replyText = completion.text?.trim().isNotEmpty == true
              ? completion.text!.trim()
              : 'That sounds amazing! Here\'s your personalized Notion-style Routine & Task system. ✨';
          context.read<AppState>().addAssistantMessage(
                '$replyText\n\n'
                'Your Notion-style routine is now loaded in the Tasks tab! 📋✨',
              );
        }
      } else {
        final reply = completion.text?.trim() ?? 'Got it! Here\'s your routine.';
        context.read<AppState>().addAssistantMessage(reply);
      }
    } catch (e) {
      if (mounted) {
        final message = switch (e) {
          AiHttpException() => e.userMessage,
          _ => 'I hit a snag building your routine — please try again.',
        };
        context.read<AppState>().addAssistantMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _streaming = false;
          _streamingText = '';
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _streaming) return;
    final app = context.read<AppState>();
    app.addUserMessage(text);
    _inputCtrl.clear();
    _scrollToBottom();

    setState(() {
      _streaming = true;
      _streamingText = '';
      _toolPlan = null;
    });
    _scrollToBottom();

    try {
      await for (final event in OpenRouterService.instance.streamChat(messages: _buildMessages())) {
        switch (event) {
          case AiStreamDelta(:final text):
            if (mounted) setState(() => _streamingText += text);
            _scrollToBottom();
          case AiStreamToolCall(:final toolCall):
            if (mounted) setState(() => _toolPlan = toolCall);
            _scrollToBottom();
          case AiStreamDone():
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        final message = switch (e) {
          AiHttpException() => e.userMessage,
          _ => 'I hit a snag talking to my brain \u2014 please try again.',
        };
        context.read<AppState>().addAssistantMessage(message);
      }
    } finally {
      if (mounted) {
        final hasPlan = _toolPlan != null;
        final reply = _streamingText.trim();
        if (!hasPlan && reply.isNotEmpty) {
          context.read<AppState>().addAssistantMessage(reply);
        }
        setState(() {
          _streaming = false;
          _streamingText = '';
        });
        _scrollToBottom();
      }
    }
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.mutedLightDark : AppColors.muted;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.35 + 0.65 * _pulse(i)),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _pulse(int index) {
    final t = (_controller.value + index * 0.33) % 1.0;
    return (math.sin(t * math.pi * 2) + 1) / 2;
  }
}
