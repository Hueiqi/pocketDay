import 'package:flutter/material.dart';

const categoryIcons = <String, IconData>{
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_bus_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'bills': Icons.receipt_long_outlined,
  'health': Icons.favorite_outline,
  'salary': Icons.work_outline,
  'gift': Icons.card_giftcard,
  'home': Icons.home_outlined,
  'education': Icons.school_outlined,
  'travel': Icons.flight_outlined,
  'fun': Icons.sports_esports_outlined,
  'pets': Icons.pets_outlined,
  'savings': Icons.savings_outlined,
  'other': Icons.category_outlined,
};

class LedgerCategory {
  final String name, kind, icon;
  final bool archived;
  const LedgerCategory(
    this.name,
    this.kind,
    this.icon, {
    this.archived = false,
  });
  IconData get iconData => categoryIcons[icon] ?? Icons.category_outlined;
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'icon': icon,
    'archived': archived,
  };
  factory LedgerCategory.fromJson(Map<String, dynamic> json) => LedgerCategory(
    json['name'],
    json['kind'],
    json['icon'],
    archived: json['archived'] ?? false,
  );
}

const defaultCategories = [
  LedgerCategory('Food & drinks', 'Expense', 'food'),
  LedgerCategory('Transport', 'Expense', 'transport'),
  LedgerCategory('Shopping', 'Expense', 'shopping'),
  LedgerCategory('Bills', 'Expense', 'bills'),
  LedgerCategory('Health', 'Expense', 'health'),
  LedgerCategory('Other', 'Expense', 'other'),
  LedgerCategory('Salary', 'Income', 'salary'),
  LedgerCategory('Gift', 'Income', 'gift'),
  LedgerCategory('Other', 'Income', 'other'),
];
