class Entry {
  final String id, title, currency, kind, category, account;
  final int cents;
  final DateTime date;
  Entry({
    required this.id,
    required this.title,
    required this.currency,
    required this.kind,
    required this.category,
    required this.cents,
    required this.date,
    this.account = 'Cash',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'currency': currency,
    'kind': kind,
    'category': category,
    'cents': cents,
    'date': date.toIso8601String(),
    'account': account,
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    title: j['title'],
    currency: j['currency'],
    kind: j['kind'],
    category: j['category'],
    cents: j['cents'],
    date: DateTime.parse(j['date']),
    account: j['account'] ?? 'Cash',
  );
}
