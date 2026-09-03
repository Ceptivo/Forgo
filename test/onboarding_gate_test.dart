import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:forgo/app.dart';
import 'package:forgo/features/onboarding/application/onboarding_providers.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('First launch shows onboarding before login', (
    WidgetTester tester,
  ) async {
    final prefs = await _prefsWith({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ForgoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Put your money on your goals'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('Skip on onboarding lands on login and persists the flag', (
    WidgetTester tester,
  ) async {
    final prefs = await _prefsWith({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ForgoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(prefs.getBool('has_seen_onboarding'), isTrue);
  });

  testWidgets('Returning user skips onboarding entirely', (
    WidgetTester tester,
  ) async {
    final prefs = await _prefsWith({'has_seen_onboarding': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const ForgoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Put your money on your goals'), findsNothing);
  });
}
