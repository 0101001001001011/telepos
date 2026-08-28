import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/presentation/controllers/wms/wms_config_controller.dart';
import 'package:telepos/domain/entities/wms/batch_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/wms/batch_controller.dart';

class BatchTrackingScreen extends ConsumerStatefulWidget {
  const BatchTrackingScreen({super.key});

  @override
  ConsumerState<BatchTrackingScreen> createState() =>
      _BatchTrackingScreenState();
}

class _BatchTrackingScreenState extends ConsumerState<BatchTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(batchControllerProvider.notifier);
      notifier.loadExpiringBatches(
        ref.read(wmsConfigControllerProvider).config?.expiryWarningDays ?? 30,
      );
      notifier.loadExpiredBatches();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchState = ref.watch(batchControllerProvider);
    final layout = Breakpoints.of(context);

    if (batchState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, batchState.error!)),
          ),
        );
      });
    }

    final allBatches = batchState.batches;
    final expiringBatches = batchState.expiringBatches;
    final expiredBatches = batchState.expiredBatches;
    final quarantinedBatches = allBatches
        .where((b) => b.isQuarantined == true)
        .toList();

    if (layout.isDesktop) {
      return _buildDesktopLayout(
        batchState,
        allBatches,
        expiringBatches,
        expiredBatches,
        quarantinedBatches,
      );
    }
    return _buildMobileLayout(
      batchState,
      allBatches,
      expiringBatches,
      expiredBatches,
      quarantinedBatches,
    );
  }

  Widget _buildMobileLayout(
    BatchState batchState,
    List<BatchEntity> allBatches,
    List<BatchEntity> expiringBatches,
    List<BatchEntity> expiredBatches,
    List<BatchEntity> quarantinedBatches,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsBatches),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.wmsBatchTabAll),
            Tab(text: l10n.wmsBatchTabExpiring),
            Tab(text: l10n.wmsBatchTabExpired),
            Tab(text: l10n.wmsBatchTabQuarantine),
          ],
        ),
        actions: [
          if (batchState.isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBatchList(allBatches, l10n.wmsNoBatches),
          _buildBatchList(expiringBatches, l10n.wmsNoExpiringBatches),
          _buildBatchList(expiredBatches, l10n.wmsNoExpiredBatches),
          _buildBatchList(quarantinedBatches, l10n.wmsNoQuarantinedBatches),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BatchState batchState,
    List<BatchEntity> allBatches,
    List<BatchEntity> expiringBatches,
    List<BatchEntity> expiredBatches,
    List<BatchEntity> quarantinedBatches,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 28),
              const SizedBox(width: 12),
              Text(
                l10n.wmsBatchTrackingTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (batchState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.wmsSearchByUcodeHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (value) {
                    final ucode = int.tryParse(value.trim());
                    if (ucode != null) {
                      ref
                          .read(batchControllerProvider.notifier)
                          .loadBatchesByProduct(ucode);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 500,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.wmsBatchTabAll),
                    Tab(text: l10n.wmsBatchTabExpiring),
                    Tab(text: l10n.wmsBatchTabExpired),
                    Tab(text: l10n.wmsBatchTabQuarantine),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBatchTable(allBatches, l10n.wmsNoBatches),
                      _buildBatchTable(
                        expiringBatches,
                        l10n.wmsNoExpiringBatches,
                      ),
                      _buildBatchTable(
                        expiredBatches,
                        l10n.wmsNoExpiredBatches,
                      ),
                      _buildBatchTable(
                        quarantinedBatches,
                        l10n.wmsNoQuarantinedBatches,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchList(List<BatchEntity> batches, String emptyMessage) {
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];
        return _buildBatchCard(batch);
      },
    );
  }

  Widget _buildBatchCard(BatchEntity batch) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getBatchStatusColor(batch);
    final statusText = _getBatchStatusText(batch);
    final expiryText = batch.expiryDate != null
        ? _formatTimestamp(batch.expiryDate!)
        : '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.inventory_2, color: statusColor, size: 20),
        ),
        title: Text(batch.batchNumber ?? l10n.wmsNoNumber),
        subtitle: Text(
          l10n.wmsBatchCardSummary(
            '${batch.ucode ?? '-'}',
            expiryText,
            '${batch.currentQuantity ?? '0'}',
          ),
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 11)),
          backgroundColor: statusColor.withValues(alpha: 0.15),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onTap: () => _showBatchActions(batch),
      ),
    );
  }

  Widget _buildBatchTable(List<BatchEntity> batches, String emptyMessage) {
    final l10n = AppLocalizations.of(context)!;
    if (batches.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.wmsBatchNumber)),
          DataColumn(label: Text(l10n.wmsProduct)),
          DataColumn(label: Text(l10n.wmsExpiryDate)),
          DataColumn(label: Text(l10n.wmsQuantityShort), numeric: true),
          DataColumn(label: Text(l10n.wmsStatus)),
          DataColumn(label: Text(l10n.wmsActions)),
        ],
        rows: batches.map((batch) {
          final statusColor = _getBatchStatusColor(batch);
          final statusText = _getBatchStatusText(batch);

          return DataRow(
            cells: [
              DataCell(Text(batch.batchNumber ?? '-')),
              DataCell(Text('${batch.ucode ?? '-'}')),
              DataCell(
                Text(
                  batch.expiryDate != null
                      ? _formatTimestamp(batch.expiryDate!)
                      : '-',
                ),
              ),
              DataCell(Text('${batch.currentQuantity ?? '0'}')),
              DataCell(
                Chip(
                  label: Text(statusText, style: const TextStyle(fontSize: 11)),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                ),
              ),
              DataCell(
                PopupMenuButton<String>(
                  onSelected: (action) => _onBatchAction(action, batch),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'quarantine',
                      child: Text(l10n.wmsQuarantine),
                    ),
                    PopupMenuItem(
                      value: 'approve',
                      child: Text(l10n.wmsApprove),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getBatchStatusColor(BatchEntity batch) {
    if (batch.isQuarantined == true) return Colors.grey;
    if (batch.isExpired) return Theme.of(context).colorScheme.error;
    if (batch.isExpiringSoon) return Colors.orange;
    return AppColors.success;
  }

  String _getBatchStatusText(BatchEntity batch) {
    final l10n = AppLocalizations.of(context)!;
    if (batch.isQuarantined == true) return l10n.wmsStatusQuarantine;
    if (batch.isExpired) return l10n.wmsStatusExpired;
    if (batch.isExpiringSoon) return l10n.wmsStatusExpiring;
    return l10n.wmsStatusOk;
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  void _showBatchActions(BatchEntity batch) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.wmsMoveToQuarantine),
              onTap: () {
                Navigator.of(ctx).pop();
                _onBatchAction('quarantine', batch);
              },
            ),
            ListTile(
              leading: const Icon(TeleposIcons.checkCircle),
              title: Text(l10n.wmsApprove),
              onTap: () {
                Navigator.of(ctx).pop();
                _onBatchAction('approve', batch);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onBatchAction(String action, BatchEntity batch) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(batchControllerProvider.notifier);
    switch (action) {
      case 'quarantine':
        if (batch.id != null) {
          final result = await notifier.quarantineBatch(batch.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? l10n.wmsBatchQuarantined('${batch.batchNumber}')
                      : result.errorMessage ?? l10n.wmsError,
                ),
              ),
            );
            notifier.loadExpiringBatches(
              ref.read(wmsConfigControllerProvider).config?.expiryWarningDays ??
                  30,
            );
            notifier.loadExpiredBatches();
          }
        }
      case 'approve':
        if (batch.id != null) {
          final result = await notifier.approveBatch(batch.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.success
                      ? l10n.wmsBatchApproved('${batch.batchNumber}')
                      : result.errorMessage ?? l10n.wmsError,
                ),
              ),
            );
            notifier.loadExpiringBatches(
              ref.read(wmsConfigControllerProvider).config?.expiryWarningDays ??
                  30,
            );
            notifier.loadExpiredBatches();
          }
        }
    }
  }

  void _openSearch() {
    final l10n = AppLocalizations.of(context)!;
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsSearchBatchesByProduct),
        content: TextField(
          controller: searchCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.wmsProductUcodeField,
            hintText: l10n.wmsEnterProductCode,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () {
              final ucode = int.tryParse(searchCtrl.text.trim());
              Navigator.of(ctx).pop();
              if (ucode != null) {
                ref
                    .read(batchControllerProvider.notifier)
                    .loadBatchesByProduct(ucode);
              }
            },
            child: Text(l10n.wmsFind),
          ),
        ],
      ),
    );
  }
}
