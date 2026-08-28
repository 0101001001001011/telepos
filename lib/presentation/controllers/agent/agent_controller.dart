import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';

enum AgentType {
  supplier(0),

  customer(1);

  const AgentType(this.value);
  final int value;
}

@immutable
class AgentItem {
  const AgentItem({
    required this.localId,
    this.serverId,
    required this.name,
    this.phone,
    this.bin,
    required this.balance,
    this.lastOperationDate,
    required this.type,
    this.isDeleted = false,
  });

  final int localId;
  final int? serverId;
  final String name;
  final String? phone;
  final String? bin;
  final Decimal balance;
  final DateTime? lastOperationDate;
  final AgentType type;
  final bool isDeleted;

  String get formattedPhone {
    if (phone == null || phone!.isEmpty) return '';
    final digits = phone!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return phone!;

    final country = digits.length > 10
        ? '+${digits.substring(0, digits.length - 10)}'
        : '+7';
    final area = digits.substring(digits.length - 10, digits.length - 7);
    final first = digits.substring(digits.length - 7, digits.length - 4);
    final second = digits.substring(digits.length - 4, digits.length - 2);
    final third = digits.substring(digits.length - 2);

    return '$country ($area) $first-$second-$third';
  }

  bool get hasDebt => balance < Decimal.zero;
}

@immutable
class AgentSearchState {
  const AgentSearchState({
    this.items = const [],
    this.searchQuery = '',
    this.agentType = AgentType.customer,
    this.showOnlyWithDebt = false,
    this.isLoading = false,
    this.error,
  });

  final List<AgentItem> items;
  final String searchQuery;
  final AgentType agentType;
  final bool showOnlyWithDebt;
  final bool isLoading;
  final String? error;

  List<AgentItem> get filteredItems {
    if (!showOnlyWithDebt) return items;
    return items.where((a) => a.hasDebt).toList();
  }

  AgentSearchState copyWith({
    List<AgentItem>? items,
    String? searchQuery,
    AgentType? agentType,
    bool? showOnlyWithDebt,
    bool? isLoading,
    String? error,
  }) {
    return AgentSearchState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      agentType: agentType ?? this.agentType,
      showOnlyWithDebt: showOnlyWithDebt ?? this.showOnlyWithDebt,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AgentSearchNotifier extends Notifier<AgentSearchState> {
  @override
  AgentSearchState build() {
    return const AgentSearchState();
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, isLoading: true, error: null);

    try {
      List<Agent> agents;
      if (query.isEmpty) {
        agents = await _db.agentDao.findWithType(state.agentType.value);
      } else {
        agents = await _db.agentDao.findByNameOrPhonePart(
          '%$query%',
          state.agentType.value,
        );
      }

      final items = <AgentItem>[];
      for (final agent in agents) {
        Decimal balance = Decimal.zero;
        if (agent.mainAccountId != null) {
          final account = await _db.accountDao.findById(agent.mainAccountId!);
          balance = account?.value ?? Decimal.zero;
        }

        items.add(
          AgentItem(
            localId: agent.localId,
            serverId: agent.serverId,
            name: agent.name ?? '',
            phone: agent.phone?.toString(),
            bin: agent.bin,
            balance: balance,
            lastOperationDate: agent.editTime != null
                ? DateTime.fromMillisecondsSinceEpoch(agent.editTime! * 1000)
                : null,
            type: agent.type == 0 ? AgentType.supplier : AgentType.customer,
            isDeleted: agent.isDeleted,
          ),
        );
      }

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.search_failed:${safeErrorText(e)}',
      );
    }
  }

  void setAgentType(AgentType type) {
    state = state.copyWith(agentType: type, items: []);
    search(state.searchQuery);
  }

  void toggleShowOnlyWithDebt() {
    state = state.copyWith(showOnlyWithDebt: !state.showOnlyWithDebt);
  }

  void clear() {
    state = const AgentSearchState();
  }
}

@immutable
class AddCustomerState {
  const AddCustomerState({
    this.name = '',
    this.phone = '',
    this.bin = '',
    this.agentType = AgentType.customer,
    this.nameError,
    this.phoneError,
    this.binError,
    this.isLoading = false,
    this.isSaved = false,
    this.error,
    this.restoredAgent,
  });

  final String name;
  final String phone;
  final String bin;
  final AgentType agentType;
  final String? nameError;
  final String? phoneError;
  final String? binError;
  final bool isLoading;
  final bool isSaved;
  final String? error;
  final AgentItem? restoredAgent;

  bool get isValid =>
      name.isNotEmpty &&
      nameError == null &&
      phoneError == null &&
      binError == null;

  AddCustomerState copyWith({
    String? name,
    String? phone,
    String? bin,
    AgentType? agentType,
    String? nameError,
    String? phoneError,
    String? binError,
    bool? isLoading,
    bool? isSaved,
    String? error,
    AgentItem? restoredAgent,
    bool clearNameError = false,
    bool clearPhoneError = false,
    bool clearBinError = false,
    bool clearError = false,
    bool clearRestored = false,
  }) {
    return AddCustomerState(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bin: bin ?? this.bin,
      agentType: agentType ?? this.agentType,
      nameError: clearNameError ? null : (nameError ?? this.nameError),
      phoneError: clearPhoneError ? null : (phoneError ?? this.phoneError),
      binError: clearBinError ? null : (binError ?? this.binError),
      isLoading: isLoading ?? this.isLoading,
      isSaved: isSaved ?? this.isSaved,
      error: clearError ? null : (error ?? this.error),
      restoredAgent: clearRestored
          ? null
          : (restoredAgent ?? this.restoredAgent),
    );
  }
}

class AddCustomerNotifier extends Notifier<AddCustomerState> {
  @override
  AddCustomerState build() {
    return const AddCustomerState();
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();

  void setAgentType(AgentType type) {
    state = state.copyWith(agentType: type);
  }

  void setName(String value) {
    String? error;
    if (value.isEmpty) {
      error = 'error.name_required';
    } else if (value.length < 2) {
      error = 'error.name_too_short';
    }
    state = state.copyWith(
      name: value,
      nameError: error,
      clearNameError: error == null,
    );
  }

  void setPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    String? error;
    if (digits.isNotEmpty && digits.length < 10) {
      error = 'error.phone_invalid';
    }
    state = state.copyWith(
      phone: digits,
      phoneError: error,
      clearPhoneError: error == null,
    );
  }

  void setBin(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    String? error;
    if (digits.isNotEmpty && digits.length != 12) {
      error = 'error.bin_invalid';
    }
    state = state.copyWith(
      bin: digits,
      binError: error,
      clearBinError: error == null,
    );
  }

  Future<AgentItem?> save() async {
    if (state.name.isEmpty) {
      state = state.copyWith(nameError: 'error.name_required');
      return null;
    }

    if (!state.isValid) return null;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (state.phone.isNotEmpty) {
        final phoneInt = int.tryParse(state.phone);
        if (phoneInt != null) {
          final existing = await _db.agentDao.findByPhone(phoneInt);
          if (existing != null) {
            if (existing.isDeleted) {
              state = state.copyWith(
                isLoading: false,
                restoredAgent: AgentItem(
                  localId: existing.localId,
                  serverId: existing.serverId,
                  name: existing.name ?? '',
                  phone: existing.phone?.toString(),
                  bin: existing.bin,
                  balance: Decimal.zero,
                  type: existing.type == 0
                      ? AgentType.supplier
                      : AgentType.customer,
                  isDeleted: true,
                ),
              );
              return null;
            } else {
              state = state.copyWith(
                isLoading: false,
                phoneError: 'error.phone_exists',
              );
              return null;
            }
          }
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final newLocalId = await _db
          .into(_db.agents)
          .insert(
            AgentsCompanion.insert(
              name: Value(state.name),
              phone: Value(
                state.phone.isNotEmpty ? int.tryParse(state.phone) : null,
              ),
              bin: Value(state.bin.isNotEmpty ? state.bin : null),
              type: Value(state.agentType.value),
              isDeleted: const Value(false),
              state: const Value(0),
              editTime: Value(now),
            ),
          );

      final newAgent = AgentItem(
        localId: newLocalId,
        name: state.name,
        phone: state.phone.isNotEmpty ? state.phone : null,
        bin: state.bin.isNotEmpty ? state.bin : null,
        balance: Decimal.zero,
        type: state.agentType,
      );

      ref.invalidate(agentSearchProvider);

      state = state.copyWith(isLoading: false, isSaved: true);
      return newAgent;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return null;
    }
  }

  Future<AgentItem?> restoreDeleted() async {
    final agent = state.restoredAgent;
    if (agent == null) return null;

    state = state.copyWith(isLoading: true, clearRestored: true);

    try {
      await _db.agentDao.restoreAgent(agent.localId);

      final restoredAgent = AgentItem(
        localId: agent.localId,
        serverId: agent.serverId,
        name: agent.name,
        phone: agent.phone,
        bin: agent.bin,
        balance: agent.balance,
        type: agent.type,
        isDeleted: false,
      );

      ref.invalidate(agentSearchProvider);

      state = state.copyWith(isLoading: false, isSaved: true);
      return restoredAgent;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.save_failed:${safeErrorText(e)}',
      );
      return null;
    }
  }

  void reset() {
    state = const AddCustomerState();
  }
}

final agentSearchProvider =
    NotifierProvider<AgentSearchNotifier, AgentSearchState>(
      AgentSearchNotifier.new,
    );

final addCustomerProvider =
    NotifierProvider<AddCustomerNotifier, AddCustomerState>(
      AddCustomerNotifier.new,
    );
