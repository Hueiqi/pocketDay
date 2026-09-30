import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../models/goal.dart';
import '../store/pocket_store.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';
import 'ledger_screen.dart';
import 'category_settings.dart';

class Home extends StatefulWidget {
  final PocketStore store;
  final bool autoRefresh;
  const Home({super.key, required this.store, required this.autoRefresh});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int page = 0;
  String currency = 'MYR';
  bool reverse = false;
  final conversion = TextEditingController(text: '100');
  Timer? timer;
  PocketStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(changed);
    if (widget.autoRefresh) {
      store.refreshRate();
      timer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => store.refreshRate(),
      );
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.autoRefresh) {
      store.refreshRate();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    store.removeListener(changed);
    conversion.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> save(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save your changes. Please try again.'),
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Transactions',
      'Statistics',
      'Accounts',
      'Savings',
      'Exchange',
    ];
    const icons = [
      Icons.receipt_long_outlined,
      Icons.pie_chart_outline,
      Icons.account_balance_wallet_outlined,
      Icons.savings_outlined,
      Icons.currency_exchange,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (store.loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      store.loadError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (page < 3)
                  MoneyLedger(
                    store: store,
                    view: page,
                    currency: currency,
                    onCurrency: (v) => setState(() => currency = v),
                    onEntry: entryDetails,
                    onAddRecord: (account) =>
                        entryForm(initialAccount: account),
                    onEditBalance: balanceForm,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: page == 3 ? savings() : exchange(),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Category settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: openCategories,
          ),
        ],
        backgroundColor: ledgerRed,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.savings, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'PocketDay',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(labels[page], style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: page,
                  onDestinationSelected: (i) => setState(() => page = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: List.generate(
                    labels.length,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFFFE4E2),
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: i == 0
                      ? 'Trans.'
                      : i == 1
                      ? 'Stats'
                      : labels[i],
                ),
              ),
            ),
      floatingActionButton: page < 3
          ? FloatingActionButton(
              onPressed: entryForm,
              tooltip: 'Add transaction',
              backgroundColor: ledgerRed,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget heading(String eyebrow, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: muted,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            height: 1.15,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(subtitle, style: const TextStyle(color: muted, height: 1.5)),
      ],
    ),
  );
  Widget card(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE7EBE1)),
    ),
    child: child,
  );
  Widget empty(IconData icon, String title, String detail) => card(
    Column(
      children: [
        Icon(icon, size: 38, color: green),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.5),
        ),
      ],
    ),
  );
  List<Widget> savings() => [
    heading(
      'LITTLE BY LITTLE',
      'Dream it. Save for it.',
      'Make room for the things that matter to you.',
    ),
    FilledButton.icon(
      onPressed: goalForm,
      icon: const Icon(Icons.add),
      label: const Text('New savings pot'),
    ),
    const SizedBox(height: 24),
    if (store.goals.isEmpty)
      empty(
        Icons.savings_outlined,
        'Big dreams start small',
        'Create a pot for an emergency fund, a holiday, or your next big thing.',
      ),
    ...store.goals.map(
      (g) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.savings_outlined, color: green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Text(
                    '${(g.saved / g.target * 100).floor()}%',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                money(g.saved, g.currency),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'of ${money(g.target, g.currency)}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (g.saved / g.target).clamp(0, 1),
                  minHeight: 9,
                  backgroundColor: cream,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => contributionForm(g, quick: true),
                    child: Text('+ ${symbol(g.currency)} 2'),
                  ),
                  OutlinedButton(
                    onPressed: () => contributionForm(g),
                    child: const Text('Add savings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Savings pots track money you set aside yourself. They do not move money or change your transaction balance.',
      style: TextStyle(color: muted, fontSize: 12, height: 1.5),
    ),
  ];
  Widget rateTile() => card(
    Row(
      children: [
        const Icon(Icons.currency_exchange, color: green, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.rate == null
                    ? 'MYR ↔ SGD'
                    : 'S\$ 1 = RM ${store.rate!.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                store.rate == null
                    ? (store.refreshing
                          ? 'Fetching latest rate…'
                          : 'Rate unavailable. Tap refresh to retry.')
                    : '${store.offline ? 'Offline · cached' : 'Reference rate'} · ${store.rateDate}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: store.refreshing ? null : () => store.refreshRate(),
          tooltip: 'Refresh exchange rate',
          icon: store.refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, color: green),
        ),
      ],
    ),
  );
  List<Widget> exchange() {
    final amount = double.tryParse(conversion.text);
    final result =
        amount != null && amount.isFinite && amount >= 0 && store.rate != null
        ? amount * (reverse ? 1 / store.rate! : store.rate!)
        : null;
    return [
      heading(
        'TWO CURRENCIES. ONE POCKET.',
        'Across the border.',
        'A handy conversion for your everyday decisions.',
      ),
      rateTile(),
      const SizedBox(height: 22),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOU CONVERT · ${reverse ? 'MALAYSIAN RINGGIT' : 'SINGAPORE DOLLAR'}',
              style: const TextStyle(
                color: muted,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: conversion,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '${reverse ? 'RM' : 'S\$'}  ',
                errorText: amount == null || !amount.isFinite || amount < 0
                    ? 'Enter a valid positive amount'
                    : null,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => reverse = !reverse),
                  tooltip: 'Swap currencies',
                  icon: const Icon(Icons.swap_vert),
                ),
              ),
            ),
            const Text(
              'ESTIMATED AMOUNT',
              style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Text(
              result == null
                  ? '—'
                  : '${reverse ? 'S\$' : 'RM'} ${NumberFormat('#,##0.00').format(result)}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reverse ? 'Singapore dollar · SGD' : 'Malaysian ringgit · MYR',
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Rates from Frankfurter are daily reference rates, not second-by-second quotes. Refreshed on opening, every 15 minutes, or when you tap refresh. Bank and money-changer rates may differ.${store.checkedAt == null ? '' : '\nLast checked: ${DateFormat('d MMM yyyy, h:mm a').format(store.checkedAt!.toLocal())}'}',
        style: const TextStyle(color: muted, height: 1.7, fontSize: 12),
      ),
    ];
  }

  Future<void> entryDetails(Entry e) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.title),
        content: Text(
          '${e.kind} · ${e.category}\n${money(e.cents, e.currency)}\n${DateFormat.yMMMd().format(e.date)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text(
                    'This will remove the entry and update your balance.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await save(() => store.remove(e.id));
            },
            child: const Text('Delete', style: TextStyle(color: coral)),
          ),
        ],
      ),
    );
  }

  Future<void> balanceForm(String account) async {
    final curr = currency;
    final amount = TextEditingController(
      text: (store.accountBalance(account, curr) / 100).toStringAsFixed(2),
    );
    final key = GlobalKey<FormState>();
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text('Edit $account balance'),
            content: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amount,
                      enabled: !busy,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Current balance ($curr)',
                      ),
                      validator: (v) => parseBalanceCents(v ?? '') == null
                          ? 'Enter a balance with up to 2 decimal places'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Set the balance you have now. Your existing records stay saved, '
                      'and new income or expenses will update this balance. '
                      'This correction does not count as income or spending.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!key.currentState!.validate()) return;
                        update(() => busy = true);
                        final ok = await save(
                          () => store.setAccountBalance(
                            account,
                            curr,
                            parseBalanceCents(amount.text)!,
                          ),
                        );
                        if (!ctx.mounted) return;
                        update(() => busy = false);
                        if (ok) Navigator.pop(ctx);
                      },
                child: Text(busy ? 'Saving...' : 'Save balance'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
  }

  Future<void> openCategories() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CategorySettings(store: store)),
    );
  }

  Future<void> entryForm({String initialAccount = 'Cash'}) async {
    final title = TextEditingController(), amount = TextEditingController();
    final key = GlobalKey<FormState>();
    var kind = 'Expense',
        curr = currency,
        category = store.categoriesFor('Expense').firstOrNull?.name ?? '',
        account = initialAccount,
        date = DateTime.now(),
        busy = false,
        addAnother = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Add transaction'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Expense', label: Text('Expense')),
                        ButtonSegment(value: 'Income', label: Text('Income')),
                      ],
                      selected: {kind},
                      onSelectionChanged: (s) => update(() {
                        kind = s.first;
                        category =
                            store.categoriesFor(kind).firstOrNull?.name ?? '';
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: title,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'What was it for?',
                      ),
                      validator: (s) => s == null || s.trim().isEmpty
                          ? 'Please enter a description'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      validator: (s) => parseCents(s ?? '') == null
                          ? 'Enter an amount with up to 2 decimal places'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: curr,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: const [
                        DropdownMenuItem(
                          value: 'MYR',
                          child: Text('RM · Malaysian ringgit'),
                        ),
                        DropdownMenuItem(
                          value: 'SGD',
                          child: Text('S\$ · Singapore dollar'),
                        ),
                      ],
                      onChanged: (v) => update(() => curr = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('$kind:$category'),
                      initialValue: category.isEmpty ? null : category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: store
                          .categoriesFor(kind)
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.name,
                              child: Row(
                                children: [
                                  Icon(c.iconData, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Add a category in Category settings'
                          : null,
                      onChanged: (v) => update(() => category = v!),
                    ),

                    TextButton.icon(
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Manage categories'),
                      onPressed: busy
                          ? null
                          : () async {
                              await openCategories();
                              if (!ctx.mounted) return;
                              update(() {
                                if (!store
                                    .categoriesFor(kind)
                                    .any((c) => c.name == category)) {
                                  category =
                                      store
                                          .categoriesFor(kind)
                                          .firstOrNull
                                          ?.name ??
                                      '';
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: account,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: store.accounts
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: (v) => update(() => account = v!),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final chosen = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (chosen != null) update(() => date = chosen);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(DateFormat.yMMMd().format(date)),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save and add another'),
                      value: addAnother,
                      onChanged: busy
                          ? null
                          : (v) => update(() => addAnother = v!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      update(() => busy = true);
                      final ok = await save(
                        () => store.add(
                          Entry(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            title: title.text.trim(),
                            currency: curr,
                            kind: kind,
                            category: category,
                            cents: parseCents(amount.text)!,
                            date: date,
                            account: account,
                          ),
                        ),
                      );
                      if (ctx.mounted) {
                        if (ok && addAnother) {
                          title.clear();
                          amount.clear();
                          key.currentState!.reset();
                          update(() => busy = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Record saved. Add your next record.',
                              ),
                            ),
                          );
                        } else if (ok) {
                          Navigator.pop(ctx);
                        } else {
                          update(() => busy = false);
                        }
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save transaction'),
            ),
          ],
        ),
      ),
    );
    // Controllers remain valid until the dialog's exit animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    amount.dispose();
  }

  Future<void> goalForm() async {
    final title = TextEditingController(), target = TextEditingController();
    final key = GlobalKey<FormState>();
    var curr = currency, busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Give your dream a name'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Pot name',
                        hintText: 'My emergency fund',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target amount',
                      ),
                      validator: (v) => parseCents(v ?? '') == null
                          ? 'Enter a valid target'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: curr,
                      items: const [
                        DropdownMenuItem(value: 'MYR', child: Text('RM · MYR')),
                        DropdownMenuItem(
                          value: 'SGD',
                          child: Text('S\$ · SGD'),
                        ),
                      ],
                      onChanged: (v) => update(() => curr = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      update(() => busy = true);
                      final ok = await save(
                        () => store.addGoal(
                          Goal(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            title: title.text.trim(),
                            currency: curr,
                            target: parseCents(target.text)!,
                          ),
                        ),
                      );
                      if (ctx.mounted) {
                        if (ok) {
                          Navigator.pop(ctx);
                        } else {
                          update(() => busy = false);
                        }
                      }
                    },
              child: const Text('Create pot'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    target.dispose();
  }

  Future<void> contributionForm(Goal goal, {bool quick = false}) async {
    final amount = TextEditingController(text: quick ? '2' : '');
    final key = GlobalKey<FormState>();
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Add to ${goal.title}'),
          content: Form(
            key: key,
            child: TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (${symbol(goal.currency)})',
              ),
              validator: (v) =>
                  parseCents(v ?? '') == null ? 'Enter a valid amount' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      update(() => busy = true);
                      final ok = await save(
                        () => store.contribute(goal, parseCents(amount.text)!),
                      );
                      if (ctx.mounted) {
                        if (ok) {
                          Navigator.pop(ctx);
                        } else {
                          update(() => busy = false);
                        }
                      }
                    },
              child: const Text('Save contribution'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
  }
}
