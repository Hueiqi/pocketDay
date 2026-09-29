class Goal {
  final String id, title, currency;
  final int target, saved;
  Goal({
    required this.id,
    required this.title,
    required this.currency,
    required this.target,
    this.saved = 0,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'currency': currency,
    'target': target,
    'saved': saved,
  };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'],
    title: j['title'],
    currency: j['currency'],
    target: j['target'],
    saved: j['saved'],
  );
}
