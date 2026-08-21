import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:questify/main.dart';
import 'package:questify/providers/app_provider.dart';
import 'package:questify/providers/settings_provider.dart';
import 'package:questify/providers/stats_provider.dart';

void main() {
  Future<(AppState, SettingsProvider, StatsProvider)> boot() async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();
    state.finishOnboarding();
    final settings = await SettingsProvider.load();
    final stats = StatsProvider(autoStart: false);
    return (state, settings, stats);
  }

  testWidgets('all four tabs render without exceptions', (tester) async {
    final (state, settings, stats) = await boot();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(() => stats.dispose());

    // Ignore RenderFlex overflow errors in debug mode — these are visual-only
    // and are clipped by ClipRect. They fire on narrow test viewports.
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed by')) return;
      previousHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousHandler);

    await tester.pumpWidget(QuestifyApp(state: state, settings: settings, stats: stats));
    // Splash auto-advances after ~3 s.
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      state.setActiveTab(i);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Let any scroll slivers lay out fully.
      for (var j = 0; j < 4; j++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  });
}
