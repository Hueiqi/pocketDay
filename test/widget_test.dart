import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketday/app.dart';
import 'package:pocketday/store/pocket_store.dart';
import 'package:pocketday/models/entry.dart';
import 'package:pocketday/models/goal.dart';
import 'package:pocketday/utils/money.dart';

void main() {
  late PocketStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PocketStore(await SharedPreferences.getInstance());
  });
  test('Money input preserves cents and rejects invalid values', () {
    expect(parseCents('2.01'), 201);
    expect(parseCents('0.10'), 10);
    for (final value in ['0', '-2', 'NaN', '1.001', '1e3', '']) {
      expect(parseCents(value), isNull);
    }
  });
  test(
    'Currencies, persistence, deletion, and savings are independent',
    () async {
      await store.add(
        Entry(
          id: '1',
          title: 'Salary',
          currency: 'MYR',
          kind: 'Income',
          category: 'Salary',
          cents: 100000,
          date: DateTime.now(),
        ),
      );
      await store.add(
        Entry(
          id: '2',
          title: 'Lunch',
          currency: 'SGD',
          kind: 'Expense',
          category: 'Food & drinks',
          cents: 650,
          date: DateTime.now(),
        ),
      );
      final goal = Goal(
        id: 'g',
        title: 'Holiday',
        currency: 'MYR',
        target: 20000,
      );
      await store.addGoal(goal);
      await store.contribute(goal, 200);
      await store.contribute(goal, 200);
      final restored = PocketStore(await SharedPreferences.getInstance());
      expect(restored.total('MYR', 'Income'), 100000);
      expect(restored.total('MYR', 'Expense'), 0);
      expect(restored.total('SGD', 'Expense'), 650);
      expect(restored.goals.single.saved, 400);
      await restored.remove('2');
      expect(restored.total('SGD', 'Expense'), 0);
    },
  );
  test('Rate refresh caches a validated rate and retains it offline', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'base': 'SGD',
          'quote': 'MYR',
          'rate': 3.2,
          'date': '2026-09-28',
        }),
        200,
      ),
    );
    await store.refreshRate(client: client);
    expect(store.rate, 3.2);
    expect(store.offline, false);
    await store.refreshRate(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    expect(store.rate, 3.2);
    expect(store.offline, true);
    final restored = PocketStore(await SharedPreferences.getInstance());
    expect(restored.rate, 3.2);
    expect(restored.offline, true);
  });
  test('Rejects mismatched currency pairs', () async {
    await store.refreshRate(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'base': 'USD',
            'quote': 'MYR',
            'rate': 4.2,
            'date': '2026-09-28',
          }),
          200,
        ),
      ),
    );
    expect(store.rate, isNull);
  });
  testWidgets('Mobile navigation and transaction creation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PocketDayApp(store: store, autoRefresh: false));
    expect(find.text('Daily'), findsOneWidget);
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '12.50');
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(store.entries.single.cents, 1250);
    await tester.tap(find.text('Exchange').last);
    await tester.pumpAndSettle();
    expect(find.text('Across the border.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
