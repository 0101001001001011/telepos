import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class TechnicianResult {
  const TechnicianResult({required this.id, required this.name});
  final int id;
  final String name;
}

class AssignTechnicianDialog extends StatefulWidget {
  const AssignTechnicianDialog({super.key});

  static Future<TechnicianResult?> show(BuildContext context) {
    return showDialog<TechnicianResult>(
      context: context,
      builder: (_) => const AssignTechnicianDialog(),
    );
  }

  @override
  State<AssignTechnicianDialog> createState() => _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState extends State<AssignTechnicianDialog> {
  List<User>? _users;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final db = GetIt.I<AppDatabase>();
      final users = await db.userDao.findAll();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.serviceAssignTechnician),
      content: SizedBox(
        width: 320,
        height: 300,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users == null || _users!.isEmpty
            ? Center(child: Text(l10n.serviceNoOrders))
            : ListView.builder(
                itemCount: _users!.length,
                itemBuilder: (context, index) {
                  final user = _users![index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (user.name?.isNotEmpty == true ? user.name![0] : '?')
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(user.name ?? 'User #${user.id}'),
                    onTap: () {
                      Navigator.of(context).pop(
                        TechnicianResult(
                          id: user.id,
                          name: user.name ?? 'User #${user.id}',
                        ),
                      );
                    },
                    dense: true,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.serviceIntakeCancel),
        ),
      ],
    );
  }
}
