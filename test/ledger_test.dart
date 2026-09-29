import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketday/app.dart';
import 'package:pocketday/store/pocket_store.dart';
import 'package:pocketday/models/entry.dart';
import 'package:pocketday/utils/entry_filters.dart';

void main() {
  test(
    'Period boundaries and combined filters preserve currency separation',
    () {
      Entry row(
        String id,
        DateTime date, {
        String currency = 'MYR',
        String account = 'Cash',
      }) => Entry(
        id: id,
        title: 'Lunch',
        currency: currency,
        kind: 'Expense',
        category: 'Food & drinks',
        cents: 1200,
        date: date,
        account: account,
      );
      final entries = [
        row('start', DateTime(2026, 9, 1)),
        row('end', DateTime(2026, 10, 1)),
        row('sgd', DateTime(2026, 9, 8), currency: 'SGD'),
        row('bank', DateTime(2026, 9, 9), account: 'Bank'),
      ];
      final selected = selectEntries(
        entries,
        currency: 'MYR',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 10, 1),
        account: 'Cash',
        category: 'Food & drinks',
        query: 'lunch',
      );
      expect(selected.map((e) => e.id), ['start']);
      expect(
        selectEntries(
          entries,
          currency: 'MYR',
          start: DateTime(2026, 9, 1),
          end: DateTime(2026, 10, 1),
          allTime: true,
        ).length,
        3,
      );
    },
  );
  test('Legacy records default to Cash and account is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final legacy = Entry.fromJson({
      'id': '1',
      'title': 'Salary',
      'currency': 'MYR',
      'kind': 'Income',
      'category': 'Salary',
      'cents': 10000,
      'date': '2026-09-01',
    });
    expect(legacy.account, 'Cash');
    final store = PocketStore(prefs);
    await store.add(
      Entry(
        id: '2',
        title: 'Lunch',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Food & drinks',
        cents: 500,
        date: DateTime.now(),
        account: 'E-wallet',
      ),
    );
    expect(PocketStore(prefs).entries.single.account, 'E-wallet');
  });
  testWidgets('Calendar, statistics, accounts, and filters work on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = Platform.environment['POCKETDAY_PREVIEW_FONT'];
    if (font != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              '${File(font).parent.path}/materialicons-regular.otf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await icons.load();
      });
    }
    SharedPreferences.setMockInitialValues({});
    final store = PocketStore(await SharedPreferences.getInstance());
    final now = DateTime.now();
    for (final e in [
      Entry(
        id: '1',
        title: 'Monthly salary',
        currency: 'MYR',
        kind: 'Income',
        category: 'Salary',
        cents: 320000,
        date: DateTime(now.year, now.month, 1),
        account: 'Bank',
      ),
      Entry(
        id: '2',
        title: 'Lunch with friends',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Food & drinks',
        cents: 1850,
        date: DateTime(now.year, now.month, 12),
      ),
      Entry(
        id: '3',
        title: 'Train to work',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Transport',
        cents: 640,
        date: DateTime(now.year, now.month, 12),
        account: 'E-wallet',
      ),
      Entry(
        id: '4',
        title: 'Groceries',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Shopping',
        cents: 8200,
        date: DateTime(now.year, now.month, 11),
      ),
      Entry(
        id: '5',
        title: 'Internet bill',
        currency: 'MYR',
        kind: 'Expense',
        category: 'Bills',
        cents: 9900,
        date: DateTime(now.year, now.month, 10),
        account: 'Bank',
      ),
    ]) {
      await store.add(e);
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: PocketDayApp(store: store, autoRefresh: false),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      if (font == null) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/previews').create(recursive: true);
      await File(
        'build/previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await tester.runAsync(() => capture('transactions'));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    expect(find.text('Lunch with friends'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await tester.runAsync(() => capture('calendar'));
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Food & drinks'), findsOneWidget);
    await tester.runAsync(() => capture('statistics'));
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('RM 3,101.00'), findsOneWidget);
    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter transactions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch with friends'), findsNothing);
    expect(find.text('Clear filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
