import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/entry.dart';
import '../models/goal.dart';
import '../models/category.dart';
import '../constants/accounts.dart' as defaults;

class PocketStore extends ChangeNotifier {
  final SharedPreferences prefs;
  List<Entry> entries = [];
  List<Goal> goals = [];
  List<String> _accounts = [...defaults.accounts];
  List<String> get accounts => List.unmodifiable(_accounts);
  Map<String, int> balanceOffsets = {};
  List<LedgerCategory> categories = [...defaultCategories];
  double? rate;
  String? rateDate;
  DateTime? checkedAt;
  bool refreshing = false, offline = false;
  String? loadError;
  PocketStore(this.prefs) {
    try {
      final raw = prefs.getString('pocketday.v1');
      if (raw != null) {
        final j = jsonDecode(raw);
        final loadedEntries = (j['entries'] as List)
            .map((e) => Entry.fromJson(e))
            .toList();
        final loadedGoals = (j['goals'] as List)
            .map((e) => Goal.fromJson(e))
            .toList();
        final loadedOffsets = Map<String, int>.from(j['balanceOffsets'] ?? {});
        final loadedAccounts = List<String>.from(
          j['accounts'] ?? defaults.accounts,
        );
        final loadedCategories = j['categories'] == null
            ? [...defaultCategories]
            : (j['categories'] as List)
                  .map((c) => LedgerCategory.fromJson(c))
                  .toList();
        entries = loadedEntries;
        goals = loadedGoals;
        balanceOffsets = loadedOffsets;
        categories = loadedCategories;
        _accounts = loadedAccounts;
      }
    } catch (_) {
      loadError =
          'Saved data could not be read. Your original data has been preserved.';
    }
    try {
      final raw = prefs.getString('pocketday.rate');
      if (raw != null) {
        final j = jsonDecode(raw);
        rate = (j['rate'] as num).toDouble();
        rateDate = j['date'];
        checkedAt = DateTime.parse(j['checked']);
        offline = true;
      }
    } catch (_) {
      rate = null;
    }
  }
  Future<void> commit(
    List<Entry> nextEntries,
    List<Goal> nextGoals, {
    Map<String, int>? offsets,
    List<LedgerCategory>? nextCategories,
    List<String>? nextAccounts,
  }) async {
    if (loadError != null) throw StateError(loadError!);
    final ok = await prefs.setString(
      'pocketday.v1',
      jsonEncode({
        'entries': nextEntries.map((e) => e.toJson()).toList(),
        'goals': nextGoals.map((g) => g.toJson()).toList(),
        'balanceOffsets': offsets ?? balanceOffsets,
        'accounts': nextAccounts ?? _accounts,
        'categories': (nextCategories ?? categories)
            .map((c) => c.toJson())
            .toList(),
      }),
    );
    if (!ok) throw StateError('Could not save. Please try again.');
    entries = nextEntries;
    goals = nextGoals;
    if (offsets != null) balanceOffsets = offsets;
    if (nextCategories != null) categories = nextCategories;
    if (nextAccounts != null) _accounts = nextAccounts;
    notifyListeners();
  }

  List<LedgerCategory> categoriesFor(String kind) =>
      categories.where((c) => c.kind == kind && !c.archived).toList();

  String? accountNameError(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'Enter an account category name';
    if (clean.length > 40) return 'Use 40 characters or fewer';
    if (clean.toLowerCase() == 'all') return 'Choose a name other than All';
    if (_accounts.any((a) => a.toLowerCase() == clean.toLowerCase())) {
      return 'This account category already exists';
    }
    return null;
  }

  Future<void> addAccount(String name) {
    final error = accountNameError(name);
    if (error != null) throw ArgumentError(error);
    return commit(entries, goals, nextAccounts: [..._accounts, name.trim()]);
  }

  Future<void> reorderAccounts(List<String> order) {
    if (order.length != _accounts.length ||
        order.toSet().length != _accounts.length ||
        !order.toSet().containsAll(_accounts)) {
      throw ArgumentError('The order must include every account exactly once.');
    }
    return commit(entries, goals, nextAccounts: [...order]);
  }

  LedgerCategory categoryFor(String name, String kind) => categories.firstWhere(
    (c) => c.name == name && c.kind == kind,
    orElse: () => LedgerCategory(name, kind, 'other'),
  );

  Future<void> addCategory(String name, String kind, String icon) {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.length > 40 ||
        !categoryIcons.containsKey(icon) ||
        !['Income', 'Expense'].contains(kind)) {
      throw ArgumentError('Enter a valid category name and icon.');
    }
    final existing = categories
        .where(
          (c) => c.kind == kind && c.name.toLowerCase() == clean.toLowerCase(),
        )
        .firstOrNull;
    if (existing != null && !existing.archived) {
      throw StateError('This category already exists.');
    }
    return commit(
      entries,
      goals,
      nextCategories: [
        ...categories.where((c) => c != existing),
        LedgerCategory(existing?.name ?? clean, kind, icon),
      ],
    );
  }

  Future<void> deleteCategory(LedgerCategory category) => commit(
    entries,
    goals,
    nextCategories: categories
        .map(
          (c) => c.name == category.name && c.kind == category.kind
              ? LedgerCategory(c.name, c.kind, c.icon, archived: true)
              : c,
        )
        .toList(),
  );

  int accountBalance(String account, String currency) =>
      (balanceOffsets['$currency:$account'] ?? 0) +
      entries
          .where((e) => e.account == account && e.currency == currency)
          .fold<int>(
            0,
            (sum, e) => sum + (e.kind == 'Income' ? e.cents : -e.cents),
          );

  Future<void> setAccountBalance(String account, String currency, int cents) {
    final key = '$currency:$account';
    return commit(
      entries,
      goals,
      offsets: {
        ...balanceOffsets,
        key:
            (balanceOffsets[key] ?? 0) +
            cents -
            accountBalance(account, currency),
      },
    );
  }

  Future<void> add(Entry e) => commit([e, ...entries], goals);
  Future<void> remove(String id) =>
      commit(entries.where((e) => e.id != id).toList(), goals);
  Future<void> addGoal(Goal g) => commit(entries, [...goals, g]);
  // Savings pots record money set aside, not an additional expense.
  Future<void> contribute(Goal goal, int cents) => commit(
    entries,
    goals
        .map(
          (g) => g.id == goal.id
              ? Goal(
                  id: g.id,
                  title: g.title,
                  currency: g.currency,
                  target: g.target,
                  saved: g.saved + cents,
                )
              : g,
        )
        .toList(),
  );
  int total(String currency, String kind, {bool month = false}) {
    final now = DateTime.now();
    return entries
        .where(
          (e) =>
              e.currency == currency &&
              e.kind == kind &&
              (!month ||
                  (e.date.year == now.year && e.date.month == now.month)),
        )
        .fold(0, (sum, e) => sum + e.cents);
  }

  Future<void> refreshRate({http.Client? client}) async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    final c = client ?? http.Client();
    try {
      final response = await c
          .get(Uri.parse('https://api.frankfurter.dev/v2/rate/SGD/MYR'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw StateError('Rate unavailable');
      final data = jsonDecode(response.body);
      final value = (data['rate'] as num).toDouble();
      if (!value.isFinite ||
          value <= 0 ||
          data['base'] != 'SGD' ||
          data['quote'] != 'MYR' ||
          DateTime.tryParse(data['date'] ?? '') == null) {
        throw StateError('Invalid rate');
      }
      final checked = DateTime.now();
      await prefs.setString(
        'pocketday.rate',
        jsonEncode({
          'rate': value,
          'date': data['date'],
          'checked': checked.toIso8601String(),
        }),
      );
      rate = value;
      rateDate = data['date'];
      checkedAt = checked;
      offline = false;
    } catch (_) {
      offline = true;
    } finally {
      if (client == null) c.close();
      refreshing = false;
      notifyListeners();
    }
  }
}
