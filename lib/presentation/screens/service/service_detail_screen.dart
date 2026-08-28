import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/local_file.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/service/service_detail_controller.dart';
import 'package:telepos/presentation/screens/service/dialogs/add_service_note_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/assign_technician_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/confirm_status_dialog.dart';
import 'package:telepos/presentation/screens/service/dialogs/print_label_dialog.dart';
import 'package:telepos/presentation/screens/service/widgets/service_action_bar.dart';
import 'package:telepos/presentation/screens/service/widgets/service_cost_summary.dart';
import 'package:telepos/presentation/screens/service/widgets/service_info_panel.dart';
import 'package:telepos/presentation/screens/service/widgets/service_status_badge.dart';
import 'package:telepos/presentation/screens/service/widgets/service_timeline.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(serviceDetailProvider.notifier);
      notifier.setOrderId(widget.orderId);
      notifier.loadOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(serviceDetailProvider);
    final notifier = ref.read(serviceDetailProvider.notifier);
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: state.order != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('#${state.order!.orderNumber}'),
                  const SizedBox(width: 8),
                  ServiceStatusBadge(status: state.order!.status),
                ],
              )
            : Text(l10n.serviceDetailTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.serviceQueue),
        ),
        actions: [
          if (state.order != null && state.order!.isActive)
            IconButton(
              icon: const Icon(Icons.engineering_outlined),
              onPressed: () => _reassignTechnician(notifier),
              tooltip: l10n.serviceReassignTechnician,
            ),
          if (state.order != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQrLabel(notifier, state),
              tooltip: l10n.servicePrintLabel,
            ),
        ],
      ),
      body: state.isLoading && state.order == null
          ? const Center(child: CircularProgressIndicator())
          : state.hasError && state.order == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    TeleposIcons.error,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(state.error ?? ''),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: notifier.loadOrder,
                    child: Text(l10n.serviceQueueTitle),
                  ),
                ],
              ),
            )
          : state.order == null
          ? const Center(child: CircularProgressIndicator())
          : isWide
          ? _buildWideLayout(l10n, state, notifier)
          : _buildNarrowLayout(l10n, state, notifier),
    );
  }

  Widget _buildWideLayout(
    AppLocalizations l10n,
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                ServiceInfoPanel(order: state.order!),
                const SizedBox(height: 16),
                ServiceTimeline(
                  marks: state.marks,
                  onAdd: state.order!.isActive
                      ? () => _addMark(notifier)
                      : null,
                  onDelete: state.order!.isActive
                      ? (id) => _deleteMark(notifier, id)
                      : null,
                  onApproveMark: (id) => notifier.approveMark(id),
                  onRejectMark: (id) => notifier.rejectMark(id),
                  canEdit: state.order!.isActive,
                ),
                const SizedBox(height: 16),
                _buildWarrantyQualityCard(state, notifier),
                if (state.capabilities.repairPhotos) ...[
                  const SizedBox(height: 16),
                  _buildRepairMediaCard(state, notifier),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 340,
            child: Column(
              children: [
                ServiceCostSummary(
                  totalCost: state.totalCost,
                  prepaid: state.order!.prepaymentAmount ?? Decimal.zero,
                  remaining: state.remainingAmount,
                ),
                const SizedBox(height: 16),
                ServiceActionBar(
                  status: state.order!.status,
                  isLoading: state.isLoading,
                  onProgress: () => _progressOrder(state, notifier),
                  onCancel: () => _cancelOrder(state, notifier),
                  onPrintLabel: () => _showQrLabel(notifier, state),
                  onPrintReceipt: () => _printReceipt(notifier, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(
    AppLocalizations l10n,
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ServiceInfoPanel(order: state.order!),
          const SizedBox(height: 16),
          ServiceTimeline(
            marks: state.marks,
            onAdd: state.order!.isActive ? () => _addMark(notifier) : null,
            onDelete: state.order!.isActive
                ? (id) => _deleteMark(notifier, id)
                : null,
            canEdit: state.order!.isActive,
          ),
          const SizedBox(height: 16),
          ServiceCostSummary(
            totalCost: state.totalCost,
            prepaid: state.order!.prepaymentAmount ?? Decimal.zero,
            remaining: state.remainingAmount,
          ),
          const SizedBox(height: 16),
          ServiceActionBar(
            status: state.order!.status,
            isLoading: state.isLoading,
            onProgress: () => _progressOrder(state, notifier),
            onCancel: () => _cancelOrder(state, notifier),
            onPrintLabel: () => _showQrLabel(notifier, state),
            onPrintReceipt: () => _printReceipt(notifier, state),
          ),
          const SizedBox(height: 16),
          _buildWarrantyQualityCard(state, notifier),
          if (state.capabilities.repairPhotos) ...[
            const SizedBox(height: 16),
            _buildRepairMediaCard(state, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildWarrantyQualityCard(
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) {
    final order = state.order!;
    final rating = order.qualityRating ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Гарантия и качество',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.warrantyDays != null
                  ? 'Гарантия: ${order.warrantyDays} дн.'
                  : 'Гарантия не установлена',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [30, 90, 180, 365].map((d) {
                final selected = order.warrantyDays == d;
                return ChoiceChip(
                  label: Text('$d дн.'),
                  selected: selected,
                  onSelected: state.order!.isActive
                      ? (_) => notifier.setWarranty(d)
                      : null,
                );
              }).toList(),
            ),
            if (state.capabilities.qualityCheck) ...[
              const Divider(height: 24),
              const Text(
                'Оценка качества',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) {
                  final value = i + 1;
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                    ),
                    onPressed: () => notifier.setQuality(value),
                  );
                }),
              ),
              if (order.qualityRating != null)
                Text(
                  'Оценка: ${order.qualityRating}/5',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRepairMediaCard(
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) {
    final media = state.repairMedia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_camera_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Фото/видео ремонта',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (state.order!.isActive) ...[
                  TextButton.icon(
                    onPressed: () => notifier.captureRepairMedia(video: false),
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: const Text('Фото'),
                  ),
                  TextButton.icon(
                    onPressed: () => notifier.captureRepairMedia(video: true),
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Видео'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (media.isEmpty)
              Text(
                'Нет медиа ремонта',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: media.map((m) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: context.semantic.canvas,
                      child: m.isVideo
                          ? const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 32,
                                color: AppColors.primary,
                              ),
                            )
                          : localImage(
                              m.filePath,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.image_outlined,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassignTechnician(ServiceDetailNotifier notifier) async {
    final result = await AssignTechnicianDialog.show(context);
    if (result == null) return;
    final ok = await notifier.setAssignee(result.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.serviceTechnicianAssigned(result.name) : l10n.errorTryAgain,
        ),
        backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _addMark(ServiceDetailNotifier notifier) async {
    final result = await AddServiceNoteDialog.show(context);
    if (result != null) {
      await notifier.addMark(
        description: result.description,
        markType: result.markType,
        cost: result.cost,
        note: result.note,
        productUcode: result.productUcode,
        approvalStatus: result.approvalStatus,
        quantity: result.quantity,
      );
    }
  }

  Future<void> _deleteMark(ServiceDetailNotifier notifier, int markId) async {
    await notifier.deleteMark(markId);
  }

  Future<void> _progressOrder(
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) async {
    final order = state.order;
    if (order == null || order.nextStatus == null) return;

    final result = await ConfirmStatusDialog.show(
      context,
      currentStatus: order.status,
      nextStatus: order.nextStatus!,
    );

    if (result != null && result.confirmed) {
      await notifier.progressStatus();
    }
  }

  Future<void> _cancelOrder(
    ServiceDetailState state,
    ServiceDetailNotifier notifier,
  ) async {
    final order = state.order;
    if (order == null) return;

    final result = await ConfirmStatusDialog.show(
      context,
      currentStatus: order.status,
      nextStatus: ServiceOrderStatus.cancelled,
      isCancel: true,
    );

    if (result != null && result.confirmed) {
      await notifier.cancelOrder();
    }
  }

  void _showQrLabel(ServiceDetailNotifier notifier, ServiceDetailState state) {
    if (state.order == null) return;
    PrintLabelDialog.show(
      context,
      orderNumber: state.order!.orderNumber,
      qrData: notifier.generateQrLabel(),
    );
  }

  Future<void> _printReceipt(
    ServiceDetailNotifier notifier,
    ServiceDetailState state,
  ) async {
    if (state.order == null) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final db = GetIt.I<AppDatabase>();
      final thisPos = await db.thisPosDao.get();
      final storeName = thisPos?.companyName ?? '';
      final posName = thisPos?.cashBoxName ?? 'POS';

      final user = await db.userDao.findById(state.order!.userId);
      final cashierName = user?.name ?? '';

      final printService = GetIt.I<ReceiptPrintService>();

      bool printed;
      if (state.order!.isCompleted || state.order!.isClosed) {
        final receiptData = await notifier.generateCompletionReceipt();
        if (receiptData == null) return;

        // Задание принято — квитанция будет; отказ очереди — неудача.
        printed = !(await printService.printServiceCompletion(
          ServiceReceiptData(
            orderNumber: receiptData.orderNumber,
            clientName: receiptData.clientName,
            clientPhone: state.order!.clientPhone,
            deviceDescription: receiptData.deviceDescription,
            serialNumber: state.order!.serialNumber,
            complaint: receiptData.complaint,
            intakeDate: DateTime.fromMillisecondsSinceEpoch(
              receiptData.intakeTime * 1000,
            ),
            estimatedDate: receiptData.estimatedCompletionTime != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    receiptData.estimatedCompletionTime! * 1000,
                  )
                : null,
            estimatedAmount: receiptData.estimatedAmount,
            marks: receiptData.marks
                .map(
                  (m) => ServiceReceiptMark(
                    description: m.description,
                    cost: m.cost,
                  ),
                )
                .toList(),
            totalCost: state.totalCost,
            prepaidAmount: state.order!.prepaymentAmount,
            remainingAmount: state.remainingAmount,
            storeName: storeName,
            posName: posName,
            cashierName: cashierName,
          ),
        )).isRejected;
      } else {
        final receiptData = await notifier.generateIntakeReceipt();
        if (receiptData == null) return;

        printed = !(await printService.printServiceIntake(
          ServiceReceiptData(
            orderNumber: receiptData.orderNumber,
            clientName: receiptData.clientName,
            clientPhone: state.order!.clientPhone,
            deviceDescription: receiptData.deviceDescription,
            serialNumber: state.order!.serialNumber,
            complaint: receiptData.complaint,
            intakeDate: DateTime.fromMillisecondsSinceEpoch(
              receiptData.intakeTime * 1000,
            ),
            estimatedDate: receiptData.estimatedCompletionTime != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    receiptData.estimatedCompletionTime! * 1000,
                  )
                : null,
            estimatedAmount: receiptData.estimatedAmount,
            prepaidAmount: state.order!.prepaymentAmount,
            storeName: storeName,
            posName: posName,
            cashierName: cashierName,
          ),
        )).isRejected;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printed ? l10n.servicePrintReceipt : l10n.errorPrinter,
            ),
            backgroundColor: printed
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrinter),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
