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

  test(
    'Categories persist; deletion preserves records, icons and balances',
    () async {
      await store.addCategory('Pets', 'Expense', 'pets');
      await store.add(
        Entry(
          id: 'pet',
          title: 'Cat food',
          currency: 'MYR',
          kind: 'Expense',
          category: 'Pets',
          cents: 2000,
          date: DateTime.now(),
        ),
      );
      await store.setAccountBalance('Cash', 'MYR', 10000);
      await store.deleteCategory(store.categoryFor('Pets', 'Expense'));
      final restored = PocketStore(store.prefs);
      expect(
        restored.categoriesFor('Expense').any((c) => c.name == 'Pets'),
        false,
      );
      expect(restored.entries.single.category, 'Pets');
      expect(restored.categoryFor('Pets', 'Expense').icon, 'pets');
      expect(restored.accountBalance('Cash', 'MYR'), 10000);
      await restored.addCategory('pets', 'Expense', 'food');
      expect(
        restored.categoriesFor('Expense').where((c) => c.name == 'Pets').length,
        1,
      );
      expect(
        () => restored.addCategory(' PETS ', 'Expense', 'pets'),
        throwsStateError,
      );
      await restored.addCategory('Pets', 'Income', 'gift');
      expect(
        PocketStore(store.prefs).categoryFor('Pets', 'Income').icon,
        'gift',
      );
    },
  );

  testWidgets('Create icon category, use it in a record, and delete it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PocketDayApp(store: store, autoRefresh: false));
    await tester.tap(find.byTooltip('Category settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Pets');
    await tester.tap(find.byTooltip('pets'));
    await tester.tap(find.text('Save category'));
    await tester.pumpAndSettle();
    expect(store.categoryFor('Pets', 'Expense').icon, 'pets');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Cat food');
    await tester.enterText(find.byType(TextFormField).at(1), '20');
    final categoryDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(categoryDropdown);
    await tester.tap(categoryDropdown);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pets').last);
    await tester.tap(find.text('Pets').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(store.entries.single.category, 'Pets');
    expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
    await tester.tap(find.byTooltip('Category settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Delete Pets'));
    await tester.tap(find.byTooltip('Delete Pets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Pets'), findsNothing);
    expect(store.entries.single.category, 'Pets');
    expect(
      PocketStore(
        store.prefs,
      ).categoriesFor('Expense').any((c) => c.name == 'Pets'),
      false,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
