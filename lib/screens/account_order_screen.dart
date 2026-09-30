import 'package:flutter/material.dart';
import '../store/pocket_store.dart';

class AccountOrderScreen extends StatefulWidget {
  final PocketStore store;
  const AccountOrderScreen({super.key, required this.store});

  @override
  State<AccountOrderScreen> createState() => _AccountOrderScreenState();
}

class _AccountOrderScreenState extends State<AccountOrderScreen> {
  late final List<String> accounts = [...widget.store.accounts];
  bool saving = false;
  String? error;

  void move(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      accounts.insert(newIndex, accounts.removeAt(oldIndex));
    });
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.reorderAccounts(accounts);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Unable to save the order. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Account ')),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: accounts.length,
              onReorder: saving ? (_, _) {} : move,
              itemBuilder: (context, index) => ListTile(
                key: ValueKey(accounts[index]),
                title: Text(accounts[index]),
                trailing: ReorderableDragStartListener(
                  index: index,
                  enabled: !saving,
                  child: Tooltip(
                    message: 'Drag to reorder ${accounts[index]}',
                    child: Semantics(
                      label: 'Reorder ${accounts[index]}',
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.check),
                label: Text(saving ? 'Saving...' : 'Save order'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
