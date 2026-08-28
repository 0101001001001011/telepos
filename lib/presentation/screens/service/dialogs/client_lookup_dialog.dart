import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class ClientLookupResult {
  const ClientLookupResult({
    this.agentId,
    required this.name,
    this.phone,
    this.address,
  });

  final int? agentId;
  final String name;
  final String? phone;
  final String? address;
}

class ClientLookupDialog extends StatefulWidget {
  const ClientLookupDialog({super.key});

  static Future<ClientLookupResult?> show(BuildContext context) {
    return showDialog<ClientLookupResult>(
      context: context,
      builder: (_) => const ClientLookupDialog(),
    );
  }

  @override
  State<ClientLookupDialog> createState() => _ClientLookupDialogState();
}

class _ClientLookupDialogState extends State<ClientLookupDialog> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  List<Agent> _results = [];
  bool _isSearching = false;
  bool _showNewForm = false;
  Timer? _debounce;

  AppDatabase get _db => GetIt.I<AppDatabase>();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isSearching = true);
    try {
      final results = await _db.agentDao.findByType(1, limit: 200);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      await _loadAll();
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _db.agentDao.findByNameOrPhonePart('%$query%', 1);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectAgent(Agent agent) {
    Navigator.of(context).pop(
      ClientLookupResult(
        agentId: agent.localId,
        name: agent.name ?? '',
        phone: agent.phone?.toString(),
      ),
    );
  }

  Future<void> _createNew() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final agentId = await _db
          .into(_db.agents)
          .insert(
            AgentsCompanion(
              type: const Value(1),
              name: Value(name),
              phone: Value(
                phone.isNotEmpty
                    ? int.tryParse(phone.replaceAll(RegExp(r'[^\d]'), ''))
                    : null,
              ),
              actualAddress: Value(address.isNotEmpty ? address : null),
              editTime: Value(now),
              state: const Value(0),
            ),
          );

      if (mounted) {
        Navigator.of(context).pop(
          ClientLookupResult(
            agentId: agentId,
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            address: address.isNotEmpty ? address : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(
          ClientLookupResult(
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            address: address.isNotEmpty ? address : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.serviceClientLookup),
      content: SizedBox(
        width: 400,
        height: 420,
        child: _showNewForm
            ? _buildNewForm(l10n, theme)
            : _buildSearch(l10n, theme),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_showNewForm) {
              setState(() => _showNewForm = false);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            _showNewForm ? l10n.serviceClientLookup : l10n.serviceIntakeCancel,
          ),
        ),
        if (_showNewForm)
          FilledButton(
            onPressed: _nameController.text.trim().isNotEmpty
                ? _createNew
                : null,
            child: Text(l10n.serviceIntakeSave),
          )
        else
          OutlinedButton.icon(
            onPressed: () => setState(() => _showNewForm = true),
            icon: const Icon(TeleposIcons.add, size: 18),
            label: Text(l10n.serviceClientNew),
          ),
      ],
    );
  }

  Widget _buildSearch(AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: l10n.serviceQueueSearch,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? l10n.serviceQueueSearch
                        : l10n.serviceNoOrders,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final agent = _results[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (agent.name?.isNotEmpty == true
                                  ? agent.name![0]
                                  : '?')
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(agent.name ?? 'N/A'),
                      subtitle: agent.phone != null
                          ? Text(agent.phone.toString())
                          : null,
                      onTap: () => _selectAgent(agent),
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNewForm(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.serviceClientNew,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '${l10n.serviceClientName} *',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.serviceClientPhone,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: l10n.serviceClientAddress,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
