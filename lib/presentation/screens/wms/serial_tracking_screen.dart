import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/entities/wms/serial_entity.dart';
import 'package:telepos/domain/entities/wms/serial_movement_entity.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/wms/serial_controller.dart';

class SerialTrackingScreen extends ConsumerStatefulWidget {
  const SerialTrackingScreen({super.key});

  @override
  ConsumerState<SerialTrackingScreen> createState() =>
      _SerialTrackingScreenState();
}

class _SerialTrackingScreenState extends ConsumerState<SerialTrackingScreen> {
  final _searchController = TextEditingController();
  SerialEntity? _selectedSerial;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _doSearch(String value) {
    if (value.isNotEmpty) {
      setState(() {
        _hasSearched = true;
        _selectedSerial = null;
      });
      ref
          .read(serialControllerProvider.notifier)
          .searchBySerialNumber(value.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final serialState = ref.watch(serialControllerProvider);
    final layout = Breakpoints.of(context);

    if (serialState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorLocalizer.localize(context, serialState.error!)),
          ),
        );
      });
    }

    if (layout.isDesktop) {
      return _buildDesktopLayout(serialState);
    }
    return _buildMobileLayout(serialState);
  }

  Widget _buildMobileLayout(SerialState serialState) {
    final l10n = AppLocalizations.of(context)!;
    final serials = serialState.serials;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wmsSerialTrackingTitle),
        actions: [
          if (serialState.isLoading)
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanSerial,
            tooltip: l10n.wmsScan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _registerNewSerial,
        child: const Icon(TeleposIcons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.wmsSearchBySerialHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(TeleposIcons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _hasSearched = false;
                            _selectedSerial = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: _doSearch,
            ),
          ),
          Expanded(
            child: serials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasSearched
                              ? l10n.wmsNothingFound
                              : l10n.wmsEnterSerialToSearch,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: serials.length,
                    itemBuilder: (context, index) =>
                        _buildSerialCard(serials[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(SerialState serialState) {
    final l10n = AppLocalizations.of(context)!;
    final serials = serialState.serials;
    final movements = serialState.movements;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, size: 28),
              const SizedBox(width: 12),
              Text(
                l10n.wmsSerialTrackingTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (serialState.isLoading)
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.wmsSearchBySerialHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: _doSearch,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _registerNewSerial,
                icon: const Icon(TeleposIcons.add),
                label: Text(l10n.wmsRegister),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: serials.isEmpty
                        ? Center(
                            child: Text(
                              _hasSearched
                                  ? l10n.wmsNothingFound
                                  : l10n.wmsEnterSerialToSearch,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : _buildSerialTable(serials),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Card(
                    child: _selectedSerial == null
                        ? Center(
                            child: Text(
                              l10n.wmsSelectSerial,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : _buildSerialDetail(_selectedSerial!, movements),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialCard(SerialEntity serial) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getSerialStatusColor(serial.status);
    final statusText = _getSerialStatusText(serial.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.qr_code, color: statusColor, size: 20),
        ),
        title: Text(serial.serialNumber ?? l10n.wmsNoNumber),
        subtitle: Text(l10n.wmsProductLabeled('${serial.ucode ?? '-'}')),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 11)),
          backgroundColor: statusColor.withValues(alpha: 0.15),
          side: BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onTap: () {
          setState(() => _selectedSerial = serial);
          if (serial.id != null) {
            ref
                .read(serialControllerProvider.notifier)
                .loadMovements(serial.id!);
          }
          if (Breakpoints.of(context).isMobile) {
            _showSerialDetailDialog(serial);
          }
        },
      ),
    );
  }

  Widget _buildSerialTable(List<SerialEntity> serials) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.wmsSerialNumber)),
          DataColumn(label: Text(l10n.wmsProduct)),
          DataColumn(label: Text(l10n.wmsStatus)),
          DataColumn(label: Text(l10n.wmsLocation)),
        ],
        rows: serials.map((serial) {
          final statusColor = _getSerialStatusColor(serial.status);
          final statusText = _getSerialStatusText(serial.status);
          final selected = _selectedSerial?.id == serial.id;

          return DataRow(
            selected: selected,
            onSelectChanged: (_) {
              setState(() => _selectedSerial = serial);
              if (serial.id != null) {
                ref
                    .read(serialControllerProvider.notifier)
                    .loadMovements(serial.id!);
              }
            },
            cells: [
              DataCell(Text(serial.serialNumber ?? '-')),
              DataCell(Text('${serial.ucode ?? '-'}')),
              DataCell(
                Chip(
                  label: Text(statusText, style: const TextStyle(fontSize: 11)),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                ),
              ),
              DataCell(
                Text(
                  serial.cellId != null
                      ? l10n.wmsCellHash('${serial.cellId}')
                      : '-',
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSerialDetail(
    SerialEntity serial,
    List<SerialMovementEntity> movements,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.wmsDetails,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _detailRow(l10n.wmsSerialNumber, serial.serialNumber ?? '-'),
          _detailRow(l10n.wmsProductUcode, '${serial.ucode ?? '-'}'),
          _detailRow(l10n.wmsStatus, _getSerialStatusText(serial.status)),
          _detailRow(
            l10n.wmsCell,
            serial.cellId != null ? '#${serial.cellId}' : '-',
          ),
          _detailRow(
            l10n.wmsBatch,
            serial.batchId != null ? '#${serial.batchId}' : '-',
          ),
          _detailRow(l10n.wmsMarking, serial.markingCode ?? '-'),
          if (serial.warrantyEnd != null)
            _detailRow(
              l10n.wmsWarrantyUntil,
              _formatTimestamp(serial.warrantyEnd!),
            ),
          _detailRow(l10n.wmsNotes, serial.notes ?? '-'),
          const SizedBox(height: 24),
          Text(
            l10n.wmsMovementHistory,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (movements.isEmpty)
            Center(
              child: Text(
                l10n.wmsNoData,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...movements.map(
              (m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getMovementIcon(m.movementType),
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${m.movementType ?? '-'} '
                        '${m.timestamp != null ? _formatTimestamp(m.timestamp!) : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getMovementIcon(String? type) {
    return switch (type) {
      'received' => Icons.call_received,
      'placed' => Icons.inventory,
      'picked' => Icons.outbox,
      'sold' => Icons.shopping_cart,
      'returned' => Icons.undo,
      'written_off' => Icons.delete,
      'transferred' => Icons.swap_horiz,
      _ => Icons.circle,
    };
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showSerialDetailDialog(SerialEntity serial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) {
          final movements = ref.read(serialControllerProvider).movements;
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: _buildSerialDetail(serial, movements),
          );
        },
      ),
    );
  }

  Color _getSerialStatusColor(int? status) {
    return switch (status) {
      0 => AppColors.success,
      1 => Colors.blue,
      2 => Colors.orange,
      3 => Colors.grey,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  String _getSerialStatusText(int? status) {
    final l10n = AppLocalizations.of(context)!;
    return switch (status) {
      0 => l10n.wmsSerialStatusInStock,
      1 => l10n.wmsSerialStatusSold,
      2 => l10n.wmsSerialStatusReturned,
      3 => l10n.wmsSerialStatusWrittenOff,
      _ => l10n.wmsSerialStatusUnknown,
    };
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  void _scanSerial() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.wmsScannerUseHardware)));
  }

  void _registerNewSerial() {
    final l10n = AppLocalizations.of(context)!;
    final ucodeCtrl = TextEditingController();
    final serialCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wmsRegisterSerialTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ucodeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.wmsProductUcodeField),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serialCtrl,
              decoration: InputDecoration(labelText: l10n.wmsSerialNumber),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final ucode = int.tryParse(ucodeCtrl.text.trim());
              final sn = serialCtrl.text.trim();
              if (ucode == null || sn.isEmpty) return;
              Navigator.of(ctx).pop();
              final result = await ref
                  .read(serialControllerProvider.notifier)
                  .registerSerial(ucode: ucode, serialNumber: sn);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? l10n.wmsSerialRegistered
                          : result.errorMessage ?? l10n.wmsError,
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.wmsRegister),
          ),
        ],
      ),
    );
  }
}
