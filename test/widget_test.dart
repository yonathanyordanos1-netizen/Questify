import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:questify/main.dart';
import 'package:questify/providers/app_provider.dart';
import 'package:questify/providers/settings_provider.dart';
import 'package:questify/providers/stats_provider.dart';

/// Tap [finder], then advance in small steps so timers fire and the
/// AnimatedSwitcher has time to build each incoming page (no pumpAndSettle:
/// the Qubi mascot and ambient animations loop forever).
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  for (var i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Simulates a phone-sized viewport so the dashboard fits on one "screen"
/// (the 800px-wide test surface makes every sliver enormous).
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<AppState> newState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState.load();
}

Future<SettingsProvider> newSettings() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsProvider.load();
}

Future<void> completeOnboarding(WidgetTester tester) async {
  usePhoneViewport(tester);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );

  final state = await newState();
  final settings = await newSettings();
  final stats = StatsProvider(autoStart: false);
  addTearDown(() => stats.dispose());
  await tester.pumpWidget(QuestifyApp(state: state, settings: settings, stats: stats));

  await tester.pump(const Duration(milliseconds: 3200));
  await tester.pump();

  // 1 · Welcome → Account
  await tapAndSettle(tester, find.text('Start Your Streak'));

  // 2 · Account → Name. Fill dummy email/password and tap Create account.
  //    In test the Supabase client is uninitialized (StateError), which the
  //    catch block treats as "demo mode" and advances to the next step.
  await tester.enterText(find.byType(TextField).first, 'test@questify.app');
  await tester.enterText(find.byType(TextField).last, 'test1234');
  await tester.pump();
  await tester.tap(find.text('Create account'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 400));

  // 3 · Name → Username
  if (find.byKey(const Key('onboarding_name')).evaluate().isNotEmpty) {
    await tester.enterText(
      find.byKey(const Key('onboarding_name')),
      'Alex Morgan',
    );
    await tapAndSettle(tester, find.text('Continue'));
  }

  // 4 · Username → Age
  if (find.text('Pick a username').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField).first, 'alexmorgan');
    await tapAndSettle(tester, find.text('Continue'));
  }

  // 5 · Age → Gender
  await tapAndSettle(tester, find.text('18 \u2013 24'));

  // 6 · Gender → Wake Time
  await tapAndSettle(tester, find.text('Male'));

  // 7 · Wake Time → Bedtime
  await tapAndSettle(tester, find.text('6:00 AM'));

  // 8 · Bedtime → Top Goals
  await tapAndSettle(tester, find.text('10:00 PM'));

  // 9 · Top Goals → Daily Quests (multi-select: tap choice + Continue button)
  await tapAndSettle(tester, find.text('Get fit'));
  await tapAndSettle(tester, find.textContaining('Continue ('));

  // 10 · Daily Quests → Habit Categories
  await tapAndSettle(tester, find.text('5 quests (Balanced)'));

  // 11 · Habit Categories → Priority Habits (multi-select)
  await tapAndSettle(tester, find.text('Fitness'));
  await tapAndSettle(tester, find.textContaining('Continue ('));

  // 12 · Priority Habits → Readiness Goals (multi-select)
  await tapAndSettle(tester, find.text('Drink 2L water'));
  await tapAndSettle(tester, find.textContaining('Continue ('));

  // 13 · Readiness Goals → Mascot Voice
  await tapAndSettle(tester, find.text('80% \u2014 Push harder'));

  // 14 · Mascot Voice → Time Budget
  await tapAndSettle(tester, find.text('Coach \u2014 Direct and punchy'));

  // 15 · Time Budget → Theme
  await tapAndSettle(tester, find.text('30 minutes'));

  // 16 · Theme → Confirm
  await tapAndSettle(tester, find.text('Light mode'));

  // 17 · Confirm → Dashboard
  await tapAndSettle(tester, find.text('Lock Plan & Launch Dashboard \ud83d\ude80'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('onboarding wizard (intro + questionnaire) leads to the dashboard',
      (tester) async {
    await completeOnboarding(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Daily Readiness'), findsOneWidget);

    // Qubi's mascot banner now leads the dashboard, so scroll the quest list
    // into view before asserting on it.
    await tester.scrollUntilVisible(
      find.text("Today's Quests"),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    // Let the freshly-built cards' one-shot entrance animations finish so no
    // timers leak out of the test. Two passes so animations scheduled by the
    // first frame are also flushed.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text("Today's Quests"), findsOneWidget);
  });

  testWidgets('Qubi AI circle opens the chat from the dashboard',
      (tester) async {
    await completeOnboarding(tester);

    await tapAndSettle(
      tester,
      find.bySemanticsLabel('Open Qubi AI assistant'),
    );

    expect(find.text('Qubi AI'), findsOneWidget);
    expect(find.text('Your streak coach, 24/7'), findsOneWidget);
  });
}
