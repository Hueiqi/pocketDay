import '../models/entry.dart';

/// The interval is inclusive at the start and exclusive at the end.
List<Entry> selectEntries(
  Iterable<Entry> entries, {
  required String currency,
  required DateTime start,
  required DateTime end,
  String account = 'All',
  String category = 'All',
  String kind = 'All',
  String query = '',
  bool allTime = false,
}) {
  return entries
      .where(
        (e) =>
            e.currency == currency &&
            (allTime || (!e.date.isBefore(start) && e.date.isBefore(end))) &&
            (account == 'All' || e.account == account) &&
            (category == 'All' || e.category == category) &&
            (kind == 'All' || e.kind == kind) &&
            '${e.title} ${e.category} ${e.account}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
