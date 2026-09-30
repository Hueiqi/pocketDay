import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketday/app.dart';
import 'package:pocketday/store/pocket_store.dart';

void main() {
  late PocketStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PocketStore(await SharedPreferences.getInstance());
  });

  test('Custom accounts persist with balances and validate names', () async {
    expect(store.accounts, ['Cash', 'Bank', 'E-wallet']);
    await store.addAccount(' Maybank ');
    await store.setAccountBalance('Maybank', 'MYR', 12500);
    final restored = PocketStore(store.prefs);
    expect(restored.accounts, ['Cash', 'Bank', 'E-wallet', 'Maybank']);
    expect(restored.accountBalance('Maybank', 'MYR'), 12500);
    for (final name in ['', '  ', ' MAYBANK ', 'All', 'x' * 41]) {
      expect(() => restored.addAccount(name), throwsArgumentError);
    }
  });

  testWidgets('Add account on phone and select it in a transaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PocketDayApp(store: store, autoRefresh: false));
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Cash');
    await tester.tap(find.text('Save account category'));
    await tester.pumpAndSettle();
    expect(find.text('This account category already exists'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Maybank');
    await tester.tap(find.text('Save account category'));
    await tester.pumpAndSettle();
    expect(find.text('Maybank'), findsOneWidget);
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
    await tester.enterText(find.byType(TextFormField).at(1), '12.50');
    final account = find.byType(DropdownButtonFormField<String>).at(2);
    await tester.ensureVisible(account);
    await tester.tap(account);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(store.entries.single.account, 'Maybank');
    expect(PocketStore(store.prefs).accountBalance('Maybank', 'MYR'), -1250);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
