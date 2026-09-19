import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/constants/enums/marking_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/ismpt/ismpt_offline_queueing_provider.dart';
import 'package:telepos/data/ismpt/marking_lifecycle_service.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/domain/ismpt/refusing_ismpt_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';

class MarkingCodesScreen extends StatefulWidget {
  const MarkingCodesScreen({super.key});

  @override
  State<MarkingCodesScreen> createState() => _MarkingCodesScreenState();
}

class _MarkingCodesScreenState extends State<MarkingCodesScreen> {
  bool _isLoading = true;
  bool _busy = false;
  String? _error;
  List<MarkingCode> _codes = const [];

  late final MarkingLifecycleService _lifecycle = MarkingLifecycleService(
    db: GetIt.I<AppDatabase>(),
    ismpt: _resolveIsMpt(),
  );

  IsMptService _resolveIsMpt() {
    if (GetIt.I.isRegistered<IsMptService>()) {
      return GetIt.I<IsMptService>();
    }
    return IsMptOfflineQueueingProvider(
      inner: const RefusingIsMptProvider(),
      store: InMemoryIsMptQueueStore(),
      isReachable: () async => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = GetIt.I<AppDatabase>();
      final codes = await db.managers.markingCodes.get();
      final sorted = [...codes]..sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() {
        _codes = sorted;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context)!;
    final ucodeCtrl = TextEditingController();
    final codesCtrl = TextEditingController();
    final supplyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsMarkingAcceptTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ucodeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.wmsProductUcode),
              ),
              TextField(
                controller: supplyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.wmsSupplyIdOptional,
                ),
              ),
              TextField(
                controller: codesCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.wmsMarkingCodesPerLine,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.wmsAccept),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final ucode = int.tryParse(ucodeCtrl.text.trim()) ?? 0;
    if (ucode <= 0) {
      _toast(l10n.errorProductNotFoundGeneric);
      return;
    }
    final supplyId = int.tryParse(supplyCtrl.text.trim()) ?? 0;
    final codes = codesCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (codes.isEmpty) {
      _toast(l10n.wmsNoCodesEntered);
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await _lifecycle.acceptOnReceipt(
        ucode: ucode,
        supplyId: supplyId,
        codes: codes,
      );
      _toast(
        res.remotePending
            ? l10n.wmsAcceptedLocally('${res.affected}')
            : l10n.wmsAccepted('${res.affected}'),
      );
    } catch (e) {
      _toast(l10n.wmsAcceptError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _verify(MarkingCode code) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final res = await _lifecycle.verify([code.code]);
      if (res.success && res.verifications.isNotEmpty) {
        final v = res.verifications.first;
        _toast(
          l10n.wmsMarkingStatusResult(v.status.name) +
              (v.isInCirculation ? ' ${l10n.wmsInCirculation}' : ''),
        );
      } else if (res.queued) {
        _toast(l10n.wmsIsMptNoConnection);
      } else {
        _toast(res.errorMessage ?? l10n.wmsVerifyUnavailable);
      }
    } catch (e) {
      _toast(l10n.wmsVerifyError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsMarkingCodesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: l10n.wmsMarkingAccept,
            onPressed: (_isLoading || _busy) ? null : _accept,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.wmsRefresh,
            onPressed: (_isLoading || _busy) ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.wmsIsMptSettings,
            onPressed: () => context.push(AppRoutes.ismptSettings),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(
                  TeleposIcons.error,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_codes.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.wmsNoMarkingCodes,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildCodeCard(_codes[index]),
    );
  }

  Widget _buildCodeCard(MarkingCode code) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(
            _aggregationIcon(code.aggregationLevel),
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          code.code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              l10n.wmsProductLabeled('${code.ucode}') +
                  '${code.gtin != null ? '  •  GTIN: ${code.gtin}' : ''}'
                      '${code.serial != null ? '  •  SN: ${code.serial}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(code.status),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.fact_check_outlined, size: 20),
              tooltip: l10n.wmsVerifyStatus,
              onPressed: _busy ? null : () => _verify(code),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int statusIndex) {
    final l10n = AppLocalizations.of(context)!;
    final status =
        (statusIndex >= 0 && statusIndex < MarkingStatus.values.length)
        ? MarkingStatus.values[statusIndex]
        : null;
    final (label, color) = switch (status) {
      MarkingStatus.received => (l10n.wmsMarkingStatusReceived, Colors.blue),
      MarkingStatus.inStock => (l10n.wmsMarkingStatusInStock, Colors.green),
      MarkingStatus.sold => (l10n.wmsMarkingStatusSold, Colors.grey),
      MarkingStatus.returned => (l10n.wmsMarkingStatusReturned, Colors.orange),
      MarkingStatus.retired => (l10n.wmsMarkingStatusRetired, Colors.red),
      MarkingStatus.blocked => (
        l10n.wmsMarkingStatusBlocked,
        Colors.deepOrange,
      ),
      null => ('—', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _aggregationIcon(int? level) {
    return switch (level) {
      1 => Icons.inventory_2_outlined,
      2 => Icons.pallet,
      _ => Icons.qr_code_2,
    };
  }
}
