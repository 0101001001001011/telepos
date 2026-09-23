import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:telepos/core/locale/till_language.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/service/service_type_entity.dart';
import 'package:telepos/domain/usecases/service/create_service_order_use_case.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/service/service_queue_controller.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/controllers/stock_registry/stock_registry_controller.dart';

@immutable
class ServiceTypeItem {
  const ServiceTypeItem({
    this.serviceTypeId,
    required this.productUcode,
    required this.name,
    required this.price,
    this.estimatedMinutes,
  });

  final int? serviceTypeId;
  final int productUcode;
  final String name;
  final Decimal price;
  final int? estimatedMinutes;
}

@immutable
class IntakeItem {
  const IntakeItem({required this.name, this.description, this.serialNumber});

  final String name;
  final String? description;
  final String? serialNumber;
}

@immutable
class ServiceIntakeState {
  const ServiceIntakeState({
    this.clientAgentId,
    this.clientName,
    this.clientPhone,
    this.clientNote,
    this.clientFromLookup = false,
    this.items = const [],
    this.intakePhotoPaths = const [],
    this.assigneeId,
    this.assigneeName,
    this.estimatedAmount,
    this.prepaymentAmount,
    this.selectedServices = const [],
    this.estimatedCompletionDate,
    this.deliveryAddress,
    this.needsPickup = false,
    this.needsDelivery = false,
    this.isSaving = false,
    this.error,
  });

  final int? clientAgentId;
  final String? clientName;
  final String? clientPhone;
  final String? clientNote;
  final bool clientFromLookup;
  final List<IntakeItem> items;
  final List<String> intakePhotoPaths;
  final int? assigneeId;
  final String? assigneeName;
  final Decimal? estimatedAmount;
  final Decimal? prepaymentAmount;
  final List<ServiceTypeItem> selectedServices;
  final DateTime? estimatedCompletionDate;
  final String? deliveryAddress;
  final bool needsPickup;
  final bool needsDelivery;
  final bool isSaving;
  final String? error;

  bool get isValid =>
      (clientName != null && clientName!.isNotEmpty) || clientAgentId != null;

  String? get deviceDescription {
    if (items.isEmpty) return null;
    return items.map((i) => i.name).join('; ');
  }

  String? get serialNumber {
    final sns = items
        .where((i) => i.serialNumber != null && i.serialNumber!.isNotEmpty)
        .map((i) => i.serialNumber!)
        .toList();
    return sns.isEmpty ? null : sns.join('; ');
  }

  String? get complaint {
    final descs = items
        .where((i) => i.description != null && i.description!.isNotEmpty)
        .map((i) => '${i.name}: ${i.description}')
        .toList();
    return descs.isEmpty ? null : descs.join('\n');
  }

  Decimal get servicesTotal {
    if (selectedServices.isEmpty) return Decimal.zero;
    return selectedServices.fold<Decimal>(
      Decimal.zero,
      (sum, s) => sum + s.price,
    );
  }

  int get totalEstimatedMinutes {
    return selectedServices.fold<int>(
      0,
      (sum, s) => sum + (s.estimatedMinutes ?? 0),
    );
  }

  ServiceIntakeState copyWith({
    int? clientAgentId,
    bool clearClientAgentId = false,
    String? clientName,
    bool clearClientName = false,
    String? clientPhone,
    bool clearClientPhone = false,
    String? clientNote,
    bool? clientFromLookup,
    List<IntakeItem>? items,
    List<String>? intakePhotoPaths,
    int? assigneeId,
    bool clearAssigneeId = false,
    String? assigneeName,
    bool clearAssigneeName = false,
    Decimal? estimatedAmount,
    bool clearEstimatedAmount = false,
    Decimal? prepaymentAmount,
    bool clearPrepaymentAmount = false,
    List<ServiceTypeItem>? selectedServices,
    DateTime? estimatedCompletionDate,
    bool clearEstimatedCompletionDate = false,
    String? deliveryAddress,
    bool clearDeliveryAddress = false,
    bool? needsPickup,
    bool? needsDelivery,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return ServiceIntakeState(
      clientAgentId: clearClientAgentId
          ? null
          : (clientAgentId ?? this.clientAgentId),
      clientName: clearClientName ? null : (clientName ?? this.clientName),
      clientPhone: clearClientPhone ? null : (clientPhone ?? this.clientPhone),
      clientNote: clientNote ?? this.clientNote,
      clientFromLookup: clientFromLookup ?? this.clientFromLookup,
      items: items ?? this.items,
      intakePhotoPaths: intakePhotoPaths ?? this.intakePhotoPaths,
      assigneeId: clearAssigneeId ? null : (assigneeId ?? this.assigneeId),
      assigneeName: clearAssigneeName
          ? null
          : (assigneeName ?? this.assigneeName),
      estimatedAmount: clearEstimatedAmount
          ? null
          : (estimatedAmount ?? this.estimatedAmount),
      prepaymentAmount: clearPrepaymentAmount
          ? null
          : (prepaymentAmount ?? this.prepaymentAmount),
      selectedServices: selectedServices ?? this.selectedServices,
      estimatedCompletionDate: clearEstimatedCompletionDate
          ? null
          : (estimatedCompletionDate ?? this.estimatedCompletionDate),
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
      needsPickup: needsPickup ?? this.needsPickup,
      needsDelivery: needsDelivery ?? this.needsDelivery,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ServiceIntakeNotifier extends Notifier<ServiceIntakeState> {
  /// Словарь на языке кассы.
  ///
  /// Контроллеру `BuildContext` недоступен, а строки отсюда уезжают в
  /// заказ-наряд — то есть в историю, где перевести их будет негде. Язык
  /// берётся у того же держателя, которым живёт печать: `locale_provider`
  /// присваивает ему язык интерфейса при сборке и при каждой смене.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(TillLanguage.current.languageCode));

  Talker get _logger => GetIt.I<Talker>();
  CreateServiceOrderUseCase get _createUseCase =>
      GetIt.I<CreateServiceOrderUseCase>();

  @override
  ServiceIntakeState build() {
    return const ServiceIntakeState();
  }

  void updateClient({
    int? agentId,
    String? name,
    String? phone,
    String? note,
    bool fromLookup = false,
  }) {
    final isReset = agentId == null && name == null && phone == null;
    state = state.copyWith(
      clientAgentId: agentId,
      clearClientAgentId: isReset || (agentId == null && name != null),
      clientName: name,
      clearClientName: isReset,
      clientPhone: phone,
      clearClientPhone: isReset,
      clientNote: note,
      clientFromLookup: isReset ? false : fromLookup,
    );
  }

  void addIntakePhoto(String path) {
    state = state.copyWith(intakePhotoPaths: [...state.intakePhotoPaths, path]);
  }

  void removeIntakePhoto(int index) {
    if (index < 0 || index >= state.intakePhotoPaths.length) return;
    final updated = [...state.intakePhotoPaths]..removeAt(index);
    state = state.copyWith(intakePhotoPaths: updated);
  }

  void addItem(IntakeItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items]..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void updateItem(int index, IntakeItem item) {
    if (index < 0 || index >= state.items.length) return;
    final updated = [...state.items];
    updated[index] = item;
    state = state.copyWith(items: updated);
  }

  void setAssignee(int? assigneeId, {String? name}) {
    state = state.copyWith(
      assigneeId: assigneeId,
      clearAssigneeId: assigneeId == null,
      assigneeName: name,
      clearAssigneeName: assigneeId == null,
    );
  }

  void setEstimatedAmount(Decimal? amount) {
    state = state.copyWith(
      estimatedAmount: amount,
      clearEstimatedAmount: amount == null,
    );
  }

  void setPrepayment(Decimal? amount) {
    state = state.copyWith(
      prepaymentAmount: amount,
      clearPrepaymentAmount: amount == null,
    );
  }

  void setEstimatedDate(DateTime? date) {
    state = state.copyWith(
      estimatedCompletionDate: date,
      clearEstimatedCompletionDate: date == null,
    );
  }

  void setDeliveryAddress(String? address) {
    state = state.copyWith(
      deliveryAddress: address,
      clearDeliveryAddress: address == null || address.isEmpty,
    );
  }

  void setNeedsPickup(bool value) {
    state = state.copyWith(needsPickup: value);
  }

  void setNeedsDelivery(bool value) {
    state = state.copyWith(needsDelivery: value);
  }

  void addService(ServiceTypeItem service) {
    final updated = [...state.selectedServices, service];
    state = state.copyWith(selectedServices: updated);
  }

  void removeService(int index) {
    if (index < 0 || index >= state.selectedServices.length) return;
    final updated = [...state.selectedServices]..removeAt(index);
    state = state.copyWith(selectedServices: updated);
  }

  void addServicesFromTypes(
    List<ServiceTypeEntity> types,
    Map<int, String> names,
    Map<int, Decimal> prices,
  ) {
    final items = types.map((t) {
      return ServiceTypeItem(
        serviceTypeId: t.id,
        productUcode: t.productUcode,
        name: names[t.productUcode] ?? 'N/A',
        price: prices[t.productUcode] ?? Decimal.zero,
        estimatedMinutes: t.estimatedDurationMinutes,
      );
    }).toList();
    state = state.copyWith(
      selectedServices: [...state.selectedServices, ...items],
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _addSelectedServicesAsMarks(int orderId, int userId) async {
    try {
      final db = GetIt.I<AppDatabase>();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final service in state.selectedServices) {
        await db.serviceMarkDao.insert(
          ServiceMarksCompanion(
            serviceOrderId: Value(orderId),
            description: Value(service.name),
            markType: const Value(4),
            userId: Value(userId),
            cost: Value(service.price),
            createdAt: Value(now),
            productUcode: Value(service.productUcode),
          ),
        );
      }

      _logger.debug(
        'Added ${state.selectedServices.length} service marks for order $orderId',
      );
    } catch (e) {
      _logger.error('Failed to add service marks: $e');
    }
  }

  Future<void> _autoAddConsumables(int orderId, int userId) async {
    try {
      final db = GetIt.I<AppDatabase>();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      for (final service in state.selectedServices) {
        final consumables = await db.serviceConsumableDao.findByService(
          service.productUcode,
        );

        for (final c in consumables) {
          final info = await db.productInfoDao.findByUcode(c.consumableUcode);
          final price = await db.productPriceDao.findByUcode(c.consumableUcode);
          final unitPrice = price?.sellingPrice ?? Decimal.zero;
          final totalCost = unitPrice * c.quantity;

          await db.serviceMarkDao.insert(
            ServiceMarksCompanion(
              serviceOrderId: Value(orderId),
              // Слова — из словаря: строка уезжает в заказ-наряд, то есть
              // в историю, и переводить её потом будет негде. Запасное
              // «Расходник» было русским литералом на любой кассе.
              description: Value(
                '${info?.name ?? _l10n.serviceConsumableFallback}'
                ' x${c.quantity}',
              ),
              markType: const Value(5),
              userId: Value(userId),
              cost: Value(totalCost),
              createdAt: Value(now),
              note: Value(_l10n.serviceAutoAddedByNorm),
              productUcode: Value(c.consumableUcode),
            ),
          );

          await db.productInfoDao.adjustQuantity(
            c.consumableUcode,
            -c.quantity,
          );
        }
      }

      _logger.debug('Auto-added consumables for order $orderId');
    } catch (e) {
      _logger.error('Failed to auto-add consumables: $e');
    }
  }

  Future<void> _saveIntakePhotos(int orderId) async {
    if (state.intakePhotoPaths.isEmpty) return;
    try {
      final db = GetIt.I<AppDatabase>();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final path in state.intakePhotoPaths) {
        await db.serviceOrderPhotoDao.insert(
          ServiceOrderPhotosCompanion(
            serviceOrderId: Value(orderId),
            filePath: Value(path),
            photoType: const Value(0),
            createdAt: Value(now),
          ),
        );
      }
      _logger.debug(
        'Saved ${state.intakePhotoPaths.length} intake photos for order $orderId',
      );
    } catch (e) {
      _logger.error('Failed to save intake photos: $e');
    }
  }

  void reset() {
    state = const ServiceIntakeState();
  }

  Future<int?> save() async {
    if (!state.isValid) {
      state = state.copyWith(error: 'error.fill_client_data');
      return null;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? 0;

      final estimatedTime = state.estimatedCompletionDate != null
          ? state.estimatedCompletionDate!.millisecondsSinceEpoch ~/ 1000
          : null;

      final totalAmount = state.estimatedAmount ?? state.servicesTotal;

      final order = await _createUseCase.create(
        userId: userId,
        clientAgentId: state.clientAgentId,
        clientName: state.clientName,
        clientPhone: state.clientPhone,
        clientNote: state.clientNote,
        deviceDescription: state.deviceDescription,
        serialNumber: state.serialNumber,
        complaint: state.complaint,
        estimatedCompletionTime: estimatedTime,
        estimatedAmount: totalAmount > Decimal.zero ? totalAmount : null,
        prepaymentAmount: state.prepaymentAmount,
      );

      _logger.info('Service order saved: id=${order.id}');

      await _addSelectedServicesAsMarks(order.id, userId);

      await _autoAddConsumables(order.id, userId);

      await _saveIntakePhotos(order.id);

      state = state.copyWith(isSaving: false);

      ref.invalidate(serviceQueueProvider);
      ref.invalidate(shiftControllerProvider);
      ref.invalidate(stockRegistryControllerProvider);

      return order.id;
    } catch (e) {
      _logger.error('Failed to save service order: $e');
      state = state.copyWith(error: e.toString(), isSaving: false);
      return null;
    }
  }
}

final serviceIntakeProvider =
    NotifierProvider<ServiceIntakeNotifier, ServiceIntakeState>(
      ServiceIntakeNotifier.new,
    );
