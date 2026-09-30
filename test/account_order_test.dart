import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketday/app.dart';
import 'package:pocketday/models/entry.dart';
import 'package:pocketday/store/pocket_store.dart';

void main() {
  late PocketStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PocketStore(await SharedPreferences.getInstance());
  });

  test('Reordering persists without changing records or balances', () async {
    await store.addAccount('Maybank');
    await store.add(
      Entry(
        id: '1',
        title: 'Lunch',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Food',
        cents: 500,
        date: DateTime(2026),
        account: 'Maybank',
      ),
    );
    await store.setAccountBalance('Maybank', 'MYR', 10000);
    await store.reorderAccounts(['Maybank', 'E-wallet', 'Cash', 'Bank']);
    final restored = PocketStore(store.prefs);
    expect(restored.accounts, ['Maybank', 'E-wallet', 'Cash', 'Bank']);
    expect(restored.entries.single.account, 'Maybank');
    expect(restored.accountBalance('Maybank', 'MYR'), 10000);
    expect(() => store.reorderAccounts(['Cash']), throwsArgumentError);
    expect(
      () => store.reorderAccounts(['Cash', 'Cash', 'Bank', 'Maybank']),
      throwsArgumentError,
    );
    expect(
      () => store.reorderAccounts(['Cash', 'Bank', 'Maybank', 'Unknown']),
      throwsArgumentError,
    );
  });

  testWidgets('Drag accounts in both directions, save and cancel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PocketDayApp(store: store, autoRefresh: false));
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder account categories'));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byTooltip('Drag to reorder Cash'),
      const Offset(0, 150),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cash')).dy,
      greaterThan(tester.getTopLeft(find.text('E-wallet')).dy),
    );
    await tester.tap(find.text('Save order'));
    await tester.pumpAndSettle();
    expect(store.accounts, ['Bank', 'E-wallet', 'Cash']);
    expect(PocketStore(store.prefs).accounts, store.accounts);
    await tester.tap(find.text('Reorder account categories'));
    await tester.pumpAndSettle();
    await tester.timedDrag(
      find.byTooltip('Drag to reorder Cash'),
      const Offset(0, -150),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cash')).dy,
      lessThan(tester.getTopLeft(find.text('Bank')).dy),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.accounts, ['Bank', 'E-wallet', 'Cash']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
