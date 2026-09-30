import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../store/pocket_store.dart';
import '../theme/app_colors.dart';
import '../widgets/add_account_dialog.dart';
import 'account_order_screen.dart';
import '../utils/money.dart';
import '../utils/entry_filters.dart';
import '../widgets/spending_pie.dart';

class MoneyLedger extends StatefulWidget {
  final PocketStore store;
  final int view;
  final String currency;
  final ValueChanged<String> onCurrency;
  final ValueChanged<Entry> onEntry;
  final ValueChanged<String> onAddRecord;
  final ValueChanged<String> onEditBalance;
  const MoneyLedger({
    super.key,
    required this.store,
    required this.view,
    required this.currency,
    required this.onCurrency,
    required this.onEntry,
    required this.onAddRecord,
    required this.onEditBalance,
  });
  @override
  State<MoneyLedger> createState() => _MoneyLedgerState();
}

class _MoneyLedgerState extends State<MoneyLedger> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int? selectedDay;
  String period = 'Daily',
      account = 'All',
      category = 'All',
      kind = 'All',
      query = '',
      chartKind = 'Expense';
  bool search = false;
  List<Entry> get items => selectEntries(
    widget.store.entries,
    currency: widget.currency,
    start: month,
    end: DateTime(month.year, month.month + 1),
    account: account,
    category: category,
    kind: kind,
    query: query,
    allTime: period == 'Total' && widget.view == 0,
  );
  int sum(Iterable<Entry> rows, String type) =>
      rows.where((e) => e.kind == type).fold(0, (s, e) => s + e.cents);
  @override
  Widget build(BuildContext context) {
    final rows = items;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(() {
                  month = DateTime(month.year, month.month - 1);
                  selectedDay = null;
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  period == 'Total' && widget.view == 0
                      ? 'All time'
                      : DateFormat('yyyy MMM').format(month),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(() {
                  month = DateTime(month.year, month.month + 1);
                  selectedDay = null;
                }),
                icon: const Icon(Icons.chevron_right),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.currency,
                  items: const [
                    DropdownMenuItem(value: 'MYR', child: Text('MYR')),
                    DropdownMenuItem(value: 'SGD', child: Text('SGD')),
                  ],
                  onChanged: (v) => widget.onCurrency(v!),
                ),
              ),
              IconButton(
                tooltip: 'Search transactions',
                onPressed: () => setState(() {
                  search = !search;
                  if (!search) query = '';
                }),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Filter transactions',
                onPressed: filters,
                icon: Icon(
                  Icons.tune,
                  color: account != 'All' || category != 'All' || kind != 'All'
                      ? ledgerRed
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (search)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Search description, category, account',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        if (widget.view == 0)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Daily', 'Calendar', 'Weekly', 'Monthly', 'Total']
                  .map(
                    (p) => InkWell(
                      onTap: () => setState(() {
                        period = p;
                        selectedDay = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: p == period
                                  ? ledgerRed
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            color: p == period
                                ? ledgerRed
                                : Colors.grey.shade600,
                            fontWeight: p == period
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Row(
            children: [
              summary('Income', sum(rows, 'Income'), incomeBlue),
              summary('Expenses', sum(rows, 'Expense'), ledgerRed),
              summary(
                'Total',
                sum(rows, 'Income') - sum(rows, 'Expense'),
                const Color(0xFF333333),
              ),
            ],
          ),
        ),
        if (account != 'All' || category != 'All' || kind != 'All')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      account,
                      category,
                      kind,
                    ].where((s) => s != 'All').join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    account = category = kind = 'All';
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        if (widget.view == 1)
          ...statistics(rows)
        else if (widget.view == 2)
          ...accountList(rows)
        else
          ...switch (period) {
            'Calendar' => calendar(rows),
            'Weekly' => weekly(rows),
            'Monthly' => monthly(rows),
            _ => daily(rows),
          },
      ],
    );
  }

  Widget summary(String title, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            money(value, widget.currency),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  Widget noEntries() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 54),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCCCCCC)),
        SizedBox(height: 16),
        Text(
          'No transactions in this view',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'Add an entry or change your month and filters.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
  Widget transaction(Entry e) => InkWell(
    onTap: () => widget.onEntry(e),
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Column(
              children: [
                Icon(
                  widget.store.categoryFor(e.category, e.kind).iconData,
                  size: 22,
                  color: ledgerRed,
                ),
                const SizedBox(height: 4),
                Text(
                  e.category,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  e.account,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              money(e.cents, e.currency),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: e.kind == 'Income' ? incomeBlue : ledgerRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> daily(List<Entry> rows) {
    if (rows.isEmpty) return [noEntries()];
    final groups = <DateTime, List<Entry>>{};
    for (final e in rows) {
      groups
          .putIfAbsent(
            DateTime(e.date.year, e.date.month, e.date.day),
            () => [],
          )
          .add(e);
    }
    return groups.entries
        .expand(
          (g) => <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF4F4F4),
              child: Row(
                children: [
                  Text(
                    '${g.key.day}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE').format(g.key),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy.MM').format(g.key),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      money(sum(g.value, 'Income'), widget.currency),
                      style: const TextStyle(fontSize: 11, color: incomeBlue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      money(sum(g.value, 'Expense'), widget.currency),
                      style: const TextStyle(fontSize: 11, color: ledgerRed),
                    ),
                  ),
                ],
              ),
            ),
            ...g.value.map(transaction),
          ],
        )
        .toList();
  }

  List<Widget> calendar(List<Entry> rows) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday % 7;
    return [
      const SizedBox(height: 14),
      Row(
        children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ((days + offset) / 7).ceil() * 7,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: 72,
        ),
        itemBuilder: (context, index) {
          final day = index - offset + 1;
          if (day < 1 || day > days) return const SizedBox();
          final entries = rows.where((e) => e.date.day == day);
          return InkWell(
            onTap: () =>
                setState(() => selectedDay = selectedDay == day ? null : day),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: selectedDay == day
                    ? const Color(0xFFFFE9E7)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selectedDay == day ? ledgerRed : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (sum(entries, 'Income') > 0)
                    FittedBox(
                      child: Text(
                        NumberFormat(
                          '#,##0.00',
                        ).format(sum(entries, 'Income') / 100),
                        style: const TextStyle(fontSize: 9, color: incomeBlue),
                      ),
                    ),
                  if (sum(entries, 'Expense') > 0)
                    FittedBox(
                      child: Text(
                        NumberFormat(
                          '#,##0.00',
                        ).format(sum(entries, 'Expense') / 100),
                        style: const TextStyle(fontSize: 9, color: ledgerRed),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          selectedDay == null
              ? 'Tap a date to view its transactions'
              : DateFormat.yMMMMd().format(
                  DateTime(month.year, month.month, selectedDay!),
                ),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
      ...daily(
        selectedDay == null
            ? rows
            : rows.where((e) => e.date.day == selectedDay).toList(),
      ),
    ];
  }

  Widget periodRow(String label, List<Entry> rows) => Container(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 1),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(
          children: [
            summary('Income', sum(rows, 'Income'), incomeBlue),
            summary('Expenses', sum(rows, 'Expense'), ledgerRed),
            summary(
              'Balance',
              sum(rows, 'Income') - sum(rows, 'Expense'),
              Colors.black87,
            ),
          ],
        ),
      ],
    ),
  );
  List<Widget> weekly(List<Entry> rows) {
    final groups = <DateTime, List<Entry>>{};
    for (final e in rows) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      final start = day.subtract(Duration(days: day.weekday - 1));
      groups.putIfAbsent(start, () => []).add(e);
    }
    if (groups.isEmpty) return [noEntries()];
    return [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Monday–Sunday · entries within the selected month',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ),
      ...groups.entries.map(
        (g) => periodRow(
          '${DateFormat('d MMM').format(g.key)} – ${DateFormat('d MMM').format(g.key.add(const Duration(days: 6)))}',
          g.value,
        ),
      ),
    ];
  }

  List<Widget> monthly(List<Entry> rows) => [
    periodRow(DateFormat.yMMMM().format(month), rows),
    ...statistics(rows),
  ];
  List<Widget> statistics(List<Entry> rows) {
    final totals = <String, int>{};
    for (final e in rows.where((e) => e.kind == chartKind)) {
      totals.update(e.category, (v) => v + e.cents, ifAbsent: () => e.cents);
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = totals.values.fold(0, (a, b) => a + b);
    return [
      Padding(
        padding: const EdgeInsets.all(18),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Income', label: Text('Income')),
            ButtonSegment(value: 'Expense', label: Text('Expenses')),
          ],
          selected: {chartKind},
          onSelectionChanged: (v) => setState(() => chartKind = v.first),
        ),
      ),
      if (sorted.isEmpty)
        noEntries()
      else ...[
        Semantics(
          label:
              '$chartKind by category. Total ${money(total, widget.currency)}',
          child: SizedBox(
            height: 240,
            width: 240,
            child: CustomPaint(
              painter: SpendingPie(sorted.map((e) => e.value).toList()),
              child: Center(
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        chartKind,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          child: Text(
                            money(total, widget.currency),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...sorted.asMap().entries.map(
          (item) => ListTile(
            leading: Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: chartColors[item.key % chartColors.length],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(item.value.value / total * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
            title: Row(
              children: [
                Icon(
                  widget.store.categoryFor(item.value.key, chartKind).iconData,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.value.key,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            trailing: Text(
              money(item.value.value, widget.currency),
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(item.value.key),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rows
                          .where(
                            (e) =>
                                e.category == item.value.key &&
                                e.kind == chartKind,
                          )
                          .map(transaction)
                          .toList(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> accountList(List<Entry> rows) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AccountOrderScreen(store: widget.store),
          ),
        ),
        icon: const Icon(Icons.reorder),
        label: const Text('Reorder account categories'),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AddAccountDialog(store: widget.store),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add account category'),
      ),
    ),
    const Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        'Account activity for the selected month',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ),
    ...widget.store.accounts.map((a) {
      final filtered = rows.where((e) => e.account == a).toList();
      return Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  a == 'Cash'
                      ? Icons.payments_outlined
                      : a == 'Bank'
                      ? Icons.account_balance_outlined
                      : Icons.account_balance_wallet_outlined,
                  color: ledgerRed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    money(
                      widget.store.accountBalance(a, widget.currency),
                      widget.currency,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Current balance including balance corrections',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                summary('Period income', sum(filtered, 'Income'), incomeBlue),
                summary('Period expenses', sum(filtered, 'Expense'), ledgerRed),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: () => widget.onEditBalance(a),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit balance'),
                ),
                TextButton.icon(
                  onPressed: () => widget.onAddRecord(a),
                  icon: const Icon(Icons.add),
                  label: const Text('Add record'),
                ),
              ],
            ),
          ],
        ),
      );
    }),
  ];
  Future<void> filters() async {
    var a = account, c = category, k = kind;
    final categories = {
      'All',
      ...widget.store.categories.where((c) => !c.archived).map((c) => c.name),
      ...widget.store.entries.map((e) => e.category),
    }.toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Filter transactions'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: a,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: ['All', ...widget.store.accounts]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => update(() => a = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: c,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => update(() => c = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: k,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['All', 'Income', 'Expense']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => update(() => k = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  account = a;
                  category = c;
                  kind = k;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}
