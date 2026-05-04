import 'package:flutter/material.dart';
import '../models/guardian.dart';
import '../services/guardian_service.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  List<Guardian> _guardians = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await GuardianService.getGuardians();
    setState(() => _guardians = g);
  }

  Future<void> _addGuardian() async {
    final result = await showDialog<Guardian>(
      context: context,
      builder: (_) => const _AddGuardianDialog(),
    );
    if (result != null) {
      await GuardianService.addGuardian(result);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Guardians'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addGuardian),
        ],
      ),
      body: _guardians.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No guardians added yet'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Guardian'),
                    onPressed: _addGuardian,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _guardians.length,
              itemBuilder: (_, i) => _GuardianCard(guardian: _guardians[i]),
            ),
    );
  }
}

class _GuardianCard extends StatelessWidget {
  final Guardian guardian;
  const _GuardianCard({required this.guardian});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red[100],
          child: Text(guardian.name[0].toUpperCase(),
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
        ),
        title: Text(guardian.name),
        subtitle: Text(guardian.phone),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (guardian.isPrimary)
              Chip(label: const Text('Primary'),
                  backgroundColor: Colors.red[50],
                  labelStyle: TextStyle(color: Colors.red[700], fontSize: 11)),
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AddGuardianDialog extends StatefulWidget {
  const _AddGuardianDialog();

  @override
  State<_AddGuardianDialog> createState() => _AddGuardianDialogState();
}

class _AddGuardianDialogState extends State<_AddGuardianDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _isPrimary = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Guardian'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Phone (+91XXXXXXXXXX)',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _isPrimary,
            onChanged: (v) => setState(() => _isPrimary = v ?? false),
            title: const Text('Primary Guardian'),
            subtitle: const Text('Auto-called in emergencies'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_name.text.isEmpty || _phone.text.isEmpty) return;
            Navigator.pop(
              context,
              Guardian(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                isPrimary: _isPrimary,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
