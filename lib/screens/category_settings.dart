import 'package:flutter/material.dart';
import '../models/category.dart';
import '../store/pocket_store.dart';

class CategorySettings extends StatefulWidget {
  final PocketStore store;
  const CategorySettings({super.key, required this.store});
  @override
  State<CategorySettings> createState() => _CategorySettingsState();
}

class _CategorySettingsState extends State<CategorySettings> {
  String kind = 'Expense';
  bool deleting = false;

  Future<void> addCategory() async {
    final name = TextEditingController();
    final key = GlobalKey<FormState>();
    var icon = 'other';
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text('Add ${kind.toLowerCase()} category'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter a category name';
                          }
                          if (widget.store
                              .categoriesFor(kind)
                              .any(
                                (c) =>
                                    c.name.toLowerCase() ==
                                    v.trim().toLowerCase(),
                              )) {
                            return 'This category already exists';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Choose an icon'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categoryIcons.entries
                            .map(
                              (item) => IconButton.filledTonal(
                                tooltip: item.key,
                                isSelected: icon == item.key,
                                style: IconButton.styleFrom(
                                  backgroundColor: icon == item.key
                                      ? Theme.of(
                                          ctx,
                                        ).colorScheme.primaryContainer
                                      : null,
                                  side: icon == item.key
                                      ? BorderSide(
                                          color: Theme.of(
                                            ctx,
                                          ).colorScheme.primary,
                                        )
                                      : BorderSide.none,
                                ),
                                onPressed: busy
                                    ? null
                                    : () => update(() => icon = item.key),
                                icon: Icon(item.value),
                              ),
                            )
                            .toList(),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
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
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await widget.store.addCategory(name.text, kind, icon);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) {
                            update(() {
                              busy = false;
                              error = 'Unable to save. Please try again.';
                            });
                          }
                        }
                      },
                child: Text(busy ? 'Saving...' : 'Save category'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
  }

  Future<void> deleteCategory(LedgerCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'This category will no longer appear when adding records. Existing records, their icons, and balances will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await widget.store.deleteCategory(category);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete category. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Category settings')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Expense', label: Text('Expenses')),
              ButtonSegment(value: 'Income', label: Text('Income')),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setState(() => kind = v.first),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
          const SizedBox(height: 16),
          if (widget.store.categoriesFor(kind).isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No categories yet. Add one to start recording.'),
            ),
          ...widget.store
              .categoriesFor(kind)
              .map(
                (c) => ListTile(
                  leading: Icon(
                    c.iconData,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(c.name),
                  trailing: IconButton(
                    tooltip: 'Delete ${c.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: deleting ? null : () => deleteCategory(c),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
