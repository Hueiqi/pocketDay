import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketday/app.dart';
import 'package:pocketday/models/entry.dart';
import 'package:pocketday/store/pocket_store.dart';
import 'package:pocketday/utils/money.dart';

void main() {
  late PocketStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PocketStore(await SharedPreferences.getInstance());
  });

  test('Balance input supports zero and debt with exact cents', () {
    expect(parseBalanceCents('0'), 0);
    expect(parseBalanceCents('-12.05'), -1205);
    expect(parseBalanceCents(' 120.50 '), 12050);
    for (final value in ['', 'NaN', '1.234', '1e3']) {
      expect(parseBalanceCents(value), isNull);
    }
  });

  test(
    'Corrections persist separately from records and currency totals',
    () async {
      await store.add(
        Entry(
          id: '1',
          title: 'Lunch',
          currency: 'MYR',
          kind: 'Expense',
          category: 'Food & drinks',
          cents: 1200,
          date: DateTime.now(),
          account: 'Bank',
        ),
      );
      await store.setAccountBalance('Bank', 'MYR', 50000);
      await store.setAccountBalance('Bank', 'SGD', -1000);
      await store.setAccountBalance('Cash', 'MYR', 0);
      await store.setAccountBalance('Bank', 'MYR', 45000);
      await store.add(
        Entry(
          id: '2',
          title: 'Bus',
          currency: 'MYR',
          kind: 'Expense',
          category: 'Transport',
          cents: 500,
          date: DateTime.now(),
          account: 'Bank',
        ),
      );
      final restored = PocketStore(store.prefs);
      expect(restored.accountBalance('Bank', 'MYR'), 44500);
      expect(restored.accountBalance('Bank', 'SGD'), -1000);
      expect(restored.accountBalance('Cash', 'MYR'), 0);
      expect(restored.total('MYR', 'Income'), 0);
      expect(restored.total('MYR', 'Expense'), 1700);
      expect(restored.entries.length, 2);
      await restored.remove('2');
      expect(restored.accountBalance('Bank', 'MYR'), 45000);
    },
  );

  testWidgets('Edit balance and add multiple account records on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PocketDayApp(store: store, autoRefresh: false));
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit balance').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '100.00');
    await tester.tap(find.text('Save balance'));
    await tester.pumpAndSettle();
    expect(store.accountBalance('Cash', 'MYR'), 10000);
    expect(find.text('RM 100.00'), findsOneWidget);
    await tester.tap(find.text('Add record').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '12.50');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(store.entries.length, 1);
    expect(find.text('Add transaction'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField).at(0));
    await tester.enterText(find.byType(TextFormField).at(0), 'Bus');
    await tester.enterText(find.byType(TextFormField).at(1), '2.00');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(store.entries.length, 2);
    expect(store.entries.every((e) => e.account == 'Cash'), isTrue);
    expect(store.accountBalance('Cash', 'MYR'), 8550);
    expect(PocketStore(store.prefs).accountBalance('Cash', 'MYR'), 8550);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
