import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/enums/service_order_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_mark_entity.dart';
import 'package:telepos/domain/entities/service/service_order_entity.dart';
import 'package:telepos/domain/entities/service/service_order_photo_entity.dart';
import 'package:telepos/domain/usecases/service/add_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/approve_service_mark_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_receipt_use_case.dart';
import 'package:telepos/domain/usecases/service/service_order_transition_use_case.dart';
import 'package:telepos/domain/usecases/service/update_service_order_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/history/history_controller.dart';
import 'package:telepos/presentation/controllers/service/service_queue_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';

@immutable
class ServiceCapabilities {
  const ServiceCapabilities({
    this.intakePhotos = false,
    this.repairPhotos = false,
    this.qualityCheck = false,
    this.intakeInventory = false,
  });

  final bool intakePhotos;
  final bool repairPhotos;
  final bool qualityCheck;
  final bool intakeInventory;

  ServiceCapabilities merge(ServiceCapabilities o) => ServiceCapabilities(
    intakePhotos: intakePhotos || o.intakePhotos,
    repairPhotos: repairPhotos || o.repairPhotos,
    qualityCheck: qualityCheck || o.qualityCheck,
    intakeInventory: intakeInventory || o.intakeInventory,
  );
}

@immutable
class ServiceDetailState {
  const ServiceDetailState({
    this.orderId,
    this.order,
    this.marks = const [],
    this.photos = const [],
    this.capabilities = const ServiceCapabilities(),
    this.isLoading = false,
    this.isEditing = false,
    this.error,
  });

  final int? orderId;
  final ServiceOrderEntity? order;
  final List<ServiceMarkEntity> marks;
  final List<ServiceOrderPhotoEntity> photos;
  final ServiceCapabilities capabilities;
  final bool isLoading;
  final bool isEditing;
  final String? error;

  List<ServiceOrderPhotoEntity> get repairMedia =>
      photos.where((p) => p.isRepairMedia).toList();

  bool get hasError => error != null;

  int get pendingApprovalCount =>
      marks.where((m) => m.isPendingApproval).length;

  Decimal get totalCost {
    return marks
        .where((m) => !m.isRejected)
        .fold<Decimal>(
          Decimal.zero,
          (sum, m) => sum + (m.cost ?? Decimal.zero),
        );
  }

  Decimal get remainingAmount {
    final prepaid = order?.prepaymentAmount ?? Decimal.zero;
    final total = totalCost;
    final remaining = total - prepaid;
    return remaining > Decimal.zero ? remaining : Decimal.zero;
  }

  String get qrLabel {
    if (order == null) return '';
    return 'TELEPOS:SO:${order!.id}:${order!.orderNumber}';
  }

  ServiceDetailState copyWith({
    int? orderId,
    ServiceOrderEntity? order,
    bool clearOrder = false,
    List<ServiceMarkEntity>? marks,
    List<ServiceOrderPhotoEntity>? photos,
    ServiceCapabilities? capabilities,
    bool? isLoading,
    bool? isEditing,
    String? error,
    bool clearError = false,
  }) {
    return ServiceDetailState(
      orderId: orderId ?? this.orderId,
      order: clearOrder ? null : (order ?? this.order),
      marks: marks ?? this.marks,
      photos: photos ?? this.photos,
      capabilities: capabilities ?? this.capabilities,
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ServiceDetailNotifier extends Notifier<ServiceDetailState> {
  Talker get _logger => GetIt.I<Talker>();
  AppDatabase get _db => GetIt.I<AppDatabase>();
  ServiceOrderTransitionUseCase get _transitionUseCase =>
      GetIt.I<ServiceOrderTransitionUseCase>();
  AddServiceMarkUseCase get _addMarkUseCase => GetIt.I<AddServiceMarkUseCase>();
  ApproveServiceMarkUseCase get _approveMarkUseCase =>
      GetIt.I<ApproveServiceMarkUseCase>();
  UpdateServiceOrderUseCase get _updateUseCase =>
      GetIt.I<UpdateServiceOrderUseCase>();
  ServiceOrderReceiptUseCase get _receiptUseCase =>
      GetIt.I<ServiceOrderReceiptUseCase>();

  @override
  ServiceDetailState build() {
    return const ServiceDetailState();
  }

  void setOrderId(int orderId) {
    state = state.copyWith(orderId: orderId);
  }

  Future<void> loadOrder() async {
    final id = state.orderId;
    if (id == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final row = await _db.serviceOrderDao.findById(id);
      if (row == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'error.order_not_found',
        );
        return;
      }

      final order = _mapRowToEntity(row);
      final markRows = await _db.serviceMarkDao.getByOrder(id);
      final marks = markRows.map(_mapMarkToEntity).toList();
      final photoRows = await _db.serviceOrderPhotoDao.getByOrder(id);
      final photos = photoRows.map(_mapPhotoToEntity).toList();

      var caps = const ServiceCapabilities();
      final seen = <int>{};
      for (final m in markRows) {
        final ucode = m.productUcode;
        if (ucode == null || !seen.add(ucode)) continue;
        final type = await _db.serviceTypeDao.findByProductUcode(ucode);
        if (type == null) continue;
        caps = caps.merge(
          ServiceCapabilities(
            intakePhotos: type.requiresIntakePhotos,
            repairPhotos: type.requiresRepairPhotos,
            qualityCheck: type.requiresQualityCheck,
            intakeInventory: type.requiresIntakeInventory,
          ),
        );
      }

      state = state.copyWith(
        order: order,
        marks: marks,
        photos: photos,
        capabilities: caps,
        isLoading: false,
      );

      _logger.debug(
        'Loaded service order: ${order.orderNumber}, '
        '${marks.length} marks',
      );
    } catch (e) {
      _logger.error('Failed to load service order $id: $e');
      state = state.copyWith(isLoading: false, error: 'error.load_failed');
    }
  }

  Future<bool> progressStatus() async {
    final id = state.orderId;
    if (id == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _transitionUseCase.progress(id);
      state = state.copyWith(order: updated, isLoading: false);
      _logger.info('Order $id progressed to ${updated.status}');
      if (updated.status == ServiceOrderStatus.closed) {
        ref.invalidate(shiftControllerProvider);
        ref.invalidate(historyControllerProvider);
      }
      ref.invalidate(serviceQueueProvider);
      return true;
    } catch (e) {
      _logger.error('Failed to progress order $id: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'error.transition_failed',
      );
      return false;
    }
  }

  Future<bool> cancelOrder() async {
    final id = state.orderId;
    if (id == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _transitionUseCase.cancel(id);
      state = state.copyWith(order: updated, isLoading: false);
      _logger.info('Order $id cancelled');
      ref.invalidate(shiftControllerProvider);
      ref.invalidate(serviceQueueProvider);
      return true;
    } catch (e) {
      _logger.error('Failed to cancel order $id: $e');
      state = state.copyWith(isLoading: false, error: 'error.cancel_failed');
      return false;
    }
  }

  Future<bool> addMark({
    required String description,
    required int markType,
    Decimal? cost,
    String? note,
    int? productUcode,
    int? approvalStatus,
    Decimal? quantity,
  }) async {
    final id = state.orderId;
    if (id == null) return false;

    try {
      final userId = ref.read(currentUserIdProvider) ?? 0;

      final mark = await _addMarkUseCase.add(
        serviceOrderId: id,
        description: description,
        markType: markType,
        userId: userId,
        cost: cost,
        note: note,
        productUcode: productUcode,
        approvalStatus: approvalStatus,
        quantity: quantity,
      );

      state = state.copyWith(marks: [...state.marks, mark]);
      _logger.info('Mark added to order $id: ${mark.description}');
      return true;
    } catch (e) {
      _logger.error('Failed to add mark to order $id: $e');
      state = state.copyWith(error: 'error.save_failed');
      return false;
    }
  }

  Future<bool> deleteMark(int markId) async {
    try {
      await _db.serviceMarkDao.deleteByIdRestoringStock(markId);
      final updatedMarks = state.marks.where((m) => m.id != markId).toList();
      state = state.copyWith(marks: updatedMarks);
      _logger.info('Mark $markId deleted');
      return true;
    } catch (e) {
      _logger.error('Failed to delete mark $markId: $e');
      state = state.copyWith(error: 'error.delete_failed');
      return false;
    }
  }

  Future<bool> updateOrder(ServiceOrderEntity updatedOrder) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _updateUseCase.update(updatedOrder);
      state = state.copyWith(order: updatedOrder, isLoading: false);
      _logger.info('Order ${updatedOrder.id} updated');
      return true;
    } catch (e) {
      _logger.error('Failed to update order: $e');
      state = state.copyWith(isLoading: false, error: 'error.save_failed');
      return false;
    }
  }

  Future<bool> setPrepayment(Decimal amount) async {
    final order = state.order;
    if (order == null) return false;

    return updateOrder(order.copyWith(prepaymentAmount: amount));
  }

  Future<bool> setAssignee(int assigneeId) async {
    final order = state.order;
    if (order == null) return false;

    return updateOrder(order.copyWith(assigneeId: assigneeId));
  }

  Future<bool> setWarranty(int days) async {
    final order = state.order;
    if (order == null) return false;
    return updateOrder(order.copyWith(warrantyDays: days));
  }

  Future<bool> setQuality(int rating, {String? note}) async {
    final order = state.order;
    if (order == null) return false;
    return updateOrder(
      order.copyWith(qualityRating: rating, qualityNote: note),
    );
  }

  void setEditing(bool editing) {
    state = state.copyWith(isEditing: editing);
  }

  String generateQrLabel() => state.qrLabel;

  Future<ServiceOrderReceiptData?> generateIntakeReceipt() async {
    final id = state.orderId;
    if (id == null) return null;

    try {
      return await _receiptUseCase.generateIntakeReceipt(id);
    } catch (e) {
      _logger.error('Failed to generate intake receipt: $e');
      state = state.copyWith(error: 'error.receipt_failed');
      return null;
    }
  }

  Future<ServiceOrderReceiptData?> generateCompletionReceipt() async {
    final id = state.orderId;
    if (id == null) return null;

    try {
      return await _receiptUseCase.generateCompletionReceipt(id);
    } catch (e) {
      _logger.error('Failed to generate completion receipt: $e');
      state = state.copyWith(error: 'error.receipt_failed');
      return null;
    }
  }

  Future<bool> approveMark(int markId) async {
    try {
      final approverId = ref.read(currentUserIdProvider) ?? 0;
      final mark = await _approveMarkUseCase.approve(
        markId: markId,
        approverUserId: approverId,
      );
      final updated = state.marks
          .map((m) => m.id == markId ? mark : m)
          .toList();
      state = state.copyWith(marks: updated);
      return true;
    } catch (e) {
      _logger.error('Failed to approve mark $markId: $e');
      return false;
    }
  }

  Future<bool> rejectMark(int markId) async {
    try {
      final approverId = ref.read(currentUserIdProvider) ?? 0;
      final mark = await _approveMarkUseCase.reject(
        markId: markId,
        approverUserId: approverId,
      );
      final updated = state.marks
          .map((m) => m.id == markId ? mark : m)
          .toList();
      state = state.copyWith(marks: updated);
      return true;
    } catch (e) {
      _logger.error('Failed to reject mark $markId: $e');
      return false;
    }
  }

  Future<bool> addPhoto(
    String filePath,
    int photoType, {
    int mediaType = 0,
  }) async {
    final id = state.orderId;
    if (id == null) return false;

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final photoId = await _db.serviceOrderPhotoDao.insert(
        ServiceOrderPhotosCompanion(
          serviceOrderId: Value(id),
          filePath: Value(filePath),
          photoType: Value(photoType),
          mediaType: Value(mediaType),
          createdAt: Value(now),
        ),
      );

      final photo = ServiceOrderPhotoEntity(
        id: photoId,
        serviceOrderId: id,
        filePath: filePath,
        photoType: photoType,
        mediaType: mediaType,
        createdAt: now,
      );
      state = state.copyWith(photos: [...state.photos, photo]);
      return true;
    } catch (e) {
      _logger.error('Failed to add photo: $e');
      return false;
    }
  }

  Future<bool> captureRepairMedia({required bool video}) async {
    try {
      final picker = ImagePicker();
      final XFile? file = video
          ? await picker.pickVideo(source: ImageSource.camera)
          : await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
            );
      if (file == null) return false;
      return addPhoto(file.path, 2, mediaType: video ? 1 : 0);
    } catch (e) {
      _logger.error('captureRepairMedia failed: $e');
      return false;
    }
  }

  Future<bool> deletePhoto(int photoId) async {
    try {
      await _db.serviceOrderPhotoDao.deleteById(photoId);
      final updated = state.photos.where((p) => p.id != photoId).toList();
      state = state.copyWith(photos: updated);
      return true;
    } catch (e) {
      _logger.error('Failed to delete photo: $e');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  ServiceOrderEntity _mapRowToEntity(ServiceOrder row) {
    return ServiceOrderEntity(
      id: row.id,
      orderNumber: row.orderNumber,
      receiptNo: row.receiptNo,
      posId: row.posId,
      status: ServiceOrderStatus.values[row.status],
      userId: row.userId,
      assigneeId: row.assigneeId,
      clientAgentId: row.clientAgentId,
      clientName: row.clientName,
      clientPhone: row.clientPhone,
      clientNote: row.clientNote,
      deviceDescription: row.deviceDescription,
      serialNumber: row.serialNumber,
      complaint: row.complaint,
      intakeTime: row.intakeTime,
      estimatedCompletionTime: row.estimatedCompletionTime,
      estimatedAmount: row.estimatedAmount,
      prepaymentAmount: row.prepaymentAmount,
      finalAmount: row.finalAmount,
      warrantyDays: row.warrantyDays,
      qualityRating: row.qualityRating,
      qualityNote: row.qualityNote,
      intakeInventory: row.intakeInventory,
    );
  }

  ServiceMarkEntity _mapMarkToEntity(ServiceMark row) {
    return ServiceMarkEntity(
      id: row.id,
      serviceOrderId: row.serviceOrderId,
      description: row.description,
      markType: row.markType,
      userId: row.userId,
      cost: row.cost,
      createdAt: row.createdAt,
      note: row.note,
      productUcode: row.productUcode,
      approvalStatus: row.approvalStatus,
      quantity: row.quantity,
    );
  }

  ServiceOrderPhotoEntity _mapPhotoToEntity(ServiceOrderPhoto row) {
    return ServiceOrderPhotoEntity(
      id: row.id,
      serviceOrderId: row.serviceOrderId,
      filePath: row.filePath,
      photoType: row.photoType,
      mediaType: row.mediaType,
      createdAt: row.createdAt,
    );
  }
}

final serviceDetailProvider =
    NotifierProvider<ServiceDetailNotifier, ServiceDetailState>(
      ServiceDetailNotifier.new,
    );
