import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

enum StockOperationType { supply, movement, supplierReturn }

@immutable
class StockRegistryItem {
  const StockRegistryItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    this.supplierName,
    this.fromLocation,
    this.toLocation,
    this.comment,
    this.productCount,
    required this.state,
  });

  final int id;

  final StockOperationType type;

  final DateTime date;

  final Decimal amount;

  final String? supplierName;

  final String? fromLocation;

  final String? toLocation;

  final String? comment;

  final int? productCount;

  final int state;

  String get formattedId {
    final prefix = switch (type) {
      StockOperationType.supply => 'S',
      StockOperationType.movement => 'M',
      StockOperationType.supplierReturn => 'R',
    };
    return '$prefix-${id.toString().padLeft(6, '0')}';
  }
}

@immutable
class StockRegistryState {
  // ignore: prefer_const_constructors_in_immutables - List fields
  StockRegistryState({
    this.items = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.pageSize = 20,
    this.dateFrom,
    this.dateTo,
    this.typeFilter,
    this.searchQuery,
    this.sortColumn = 'date',
    this.sortAscending = false,
    this.isLoading = false,
    this.error,
  });

  final List<StockRegistryItem> items;

  final int totalCount;

  final int currentPage;

  final int pageSize;

  final DateTime? dateFrom;

  final DateTime? dateTo;

  final StockOperationType? typeFilter;

  final String? searchQuery;

  final String sortColumn;

  final bool sortAscending;

  final bool isLoading;

  final String? error;

  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 999999);

  bool get canGoPrevious => currentPage > 1;

  bool get canGoNext => currentPage < totalPages;

  int get startIndex => totalCount == 0 ? 0 : (currentPage - 1) * pageSize + 1;

  int get endIndex => (startIndex + items.length - 1).clamp(0, totalCount);

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      typeFilter != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  StockRegistryState copyWith({
    List<StockRegistryItem>? items,
    int? totalCount,
    int? currentPage,
    int? pageSize,
    DateTime? dateFrom,
    DateTime? dateTo,
    StockOperationType? typeFilter,
    String? searchQuery,
    String? sortColumn,
    bool? sortAscending,
    bool? isLoading,
    String? error,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearTypeFilter = false,
    bool clearSearchQuery = false,
    bool clearError = false,
  }) {
    return StockRegistryState(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StockRegistryNotifier extends Notifier<StockRegistryState> {
  @override
  StockRegistryState build() {
    Future.microtask(() => _loadPage(1));
    return StockRegistryState(isLoading: true);
  }

  AppDatabase get _db => GetIt.I<AppDatabase>();

  Future<void> loadData() async {
    await _loadPage(state.currentPage);
  }

  Future<void> setPage(int page) async {
    if (page < 1 || page > state.totalPages) return;
    await _loadPage(page);
  }

  Future<void> refresh() async {
    await _loadPage(state.currentPage);
  }

  Future<void> goToFirst() async {
    await setPage(1);
  }

  Future<void> goToPrevious() async {
    if (state.canGoPrevious) {
      await setPage(state.currentPage - 1);
    }
  }

  Future<void> goToNext() async {
    if (state.canGoNext) {
      await setPage(state.currentPage + 1);
    }
  }

  Future<void> goToLast() async {
    await setPage(state.totalPages);
  }

  void setFilter(StockOperationType? type) {
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(
      searchQuery: query,
      clearSearchQuery: query == null || query.isEmpty,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void sortBy(String column, bool ascending) {
    state = state.copyWith(
      sortColumn: column,
      sortAscending: ascending,
      currentPage: 1,
    );
    _loadPage(1);
  }

  void clearFilters() {
    state = state.copyWith(
      clearDateFrom: true,
      clearDateTo: true,
      clearTypeFilter: true,
      clearSearchQuery: true,
      currentPage: 1,
    );
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final dateFromTs = state.dateFrom != null
          ? state.dateFrom!.millisecondsSinceEpoch ~/ 1000
          : null;
      final dateToTs = state.dateTo != null
          ? (state.dateTo!.millisecondsSinceEpoch ~/ 1000) + 86400
          : null;

      final countVars = <Variable>[];
      final fromClause = _buildUnionFrom(
        dateFromTs: dateFromTs,
        dateToTs: dateToTs,
        vars: countVars,
      );

      final countRows = await _db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM ($fromClause) reg',
            variables: countVars,
            readsFrom: {},
          )
          .get();
      final totalCount = countRows.isNotEmpty
          ? (countRows.first.read<int?>('cnt') ?? 0)
          : 0;

      final dataVars = <Variable>[];
      final dataFrom = _buildUnionFrom(
        dateFromTs: dateFromTs,
        dateToTs: dateToTs,
        vars: dataVars,
      );
      final orderBy = _buildOrderBy();
      final offset = (page - 1) * state.pageSize;
      dataVars.add(Variable.withInt(state.pageSize));
      dataVars.add(Variable.withInt(offset));

      final rows = await _db
          .customSelect(
            'SELECT * FROM ($dataFrom) reg $orderBy LIMIT ? OFFSET ?',
            variables: dataVars,
            readsFrom: {},
          )
          .get();

      final pageItems = rows.map(_mapRow).toList();

      state = state.copyWith(
        items: pageItems,
        totalCount: totalCount,
        currentPage: page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      );
    }
  }

  String _buildUnionFrom({
    required int? dateFromTs,
    required int? dateToTs,
    required List<Variable> vars,
  }) {
    final searchQuery =
        (state.searchQuery != null && state.searchQuery!.isNotEmpty)
        ? state.searchQuery!.toLowerCase()
        : null;

    final parts = <String>[];

    if (state.typeFilter == null ||
        state.typeFilter == StockOperationType.supply) {
      parts.add(
        _buildSupplySelect(
          dateFromTs: dateFromTs,
          dateToTs: dateToTs,
          search: searchQuery,
          vars: vars,
        ),
      );
    }
    if (state.typeFilter == null ||
        state.typeFilter == StockOperationType.movement) {
      parts.add(
        _buildMovementSelect(
          dateFromTs: dateFromTs,
          dateToTs: dateToTs,
          search: searchQuery,
          vars: vars,
        ),
      );
    }
    if (state.typeFilter == null ||
        state.typeFilter == StockOperationType.supplierReturn) {
      parts.add(
        _buildSupplierReturnSelect(
          dateFromTs: dateFromTs,
          dateToTs: dateToTs,
          search: searchQuery,
          vars: vars,
        ),
      );
    }

    if (parts.isEmpty) {
      return 'SELECT 0 AS op_type, 0 AS id, 0 AS edit_time, '
          '0.0 AS amount, NULL AS supplier_name, NULL AS from_location, '
          'NULL AS to_location, NULL AS comment, 0 AS state, '
          '0 AS product_count WHERE 0';
    }

    return parts.join(' UNION ALL ');
  }

  String _buildSupplySelect({
    required int? dateFromTs,
    required int? dateToTs,
    required String? search,
    required List<Variable> vars,
  }) {
    final where = <String>[];
    if (dateFromTs != null) {
      where.add('s.edit_time >= ?');
      vars.add(Variable.withInt(dateFromTs));
    }
    if (dateToTs != null) {
      where.add('s.edit_time <= ?');
      vars.add(Variable.withInt(dateToTs));
    }
    if (search != null) {
      where.add(
        '('
        "lower(IFNULL(a.name, '')) LIKE ? OR "
        "lower(IFNULL(s.comment, '')) LIKE ? OR "
        "lower('S-' || printf('%06d', s.id)) LIKE ?"
        ')',
      );
      final like = '%$search%';
      vars
        ..add(Variable.withString(like))
        ..add(Variable.withString(like))
        ..add(Variable.withString(like));
    }
    final whereClause = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';

    return 'SELECT 0 AS op_type, s.id AS id, '
        'IFNULL(s.edit_time, 0) AS edit_time, IFNULL(s.amount, 0.0) AS amount, '
        'a.name AS supplier_name, NULL AS from_location, NULL AS to_location, '
        's.comment AS comment, IFNULL(s.state, 0) AS state, '
        '(SELECT COUNT(*) FROM supply_products sp WHERE sp.supply_id = s.id) AS product_count '
        'FROM supplies s '
        'LEFT JOIN agents a ON a.local_id = s.supplier_id '
        '$whereClause';
  }

  String _buildMovementSelect({
    required int? dateFromTs,
    required int? dateToTs,
    required String? search,
    required List<Variable> vars,
  }) {
    final where = <String>[];
    if (dateFromTs != null) {
      where.add('m.edit_time >= ?');
      vars.add(Variable.withInt(dateFromTs));
    }
    if (dateToTs != null) {
      where.add('m.edit_time <= ?');
      vars.add(Variable.withInt(dateToTs));
    }
    if (search != null) {
      where.add(
        '('
        "lower(IFNULL(m.from_location, '')) LIKE ? OR "
        "lower(IFNULL(m.to_location, '')) LIKE ? OR "
        "lower(IFNULL(m.comment, '')) LIKE ? OR "
        "lower('M-' || printf('%06d', m.id)) LIKE ?"
        ')',
      );
      final like = '%$search%';
      vars
        ..add(Variable.withString(like))
        ..add(Variable.withString(like))
        ..add(Variable.withString(like))
        ..add(Variable.withString(like));
    }
    final whereClause = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';

    return 'SELECT 1 AS op_type, m.id AS id, '
        'IFNULL(m.edit_time, 0) AS edit_time, IFNULL(m.amount, 0.0) AS amount, '
        'NULL AS supplier_name, m.from_location AS from_location, '
        'm.to_location AS to_location, m.comment AS comment, '
        'IFNULL(m.state, 0) AS state, '
        '(SELECT COUNT(*) FROM movement_products mp WHERE mp.movement_id = m.id) AS product_count '
        'FROM movements m '
        '$whereClause';
  }

  String _buildSupplierReturnSelect({
    required int? dateFromTs,
    required int? dateToTs,
    required String? search,
    required List<Variable> vars,
  }) {
    final where = <String>[];
    if (dateFromTs != null) {
      where.add('sr.edit_time >= ?');
      vars.add(Variable.withInt(dateFromTs));
    }
    if (dateToTs != null) {
      where.add('sr.edit_time <= ?');
      vars.add(Variable.withInt(dateToTs));
    }
    if (search != null) {
      where.add(
        '('
        "lower(IFNULL(a.name, '')) LIKE ? OR "
        "lower(IFNULL(sr.comment, '')) LIKE ? OR "
        "lower('R-' || printf('%06d', sr.id)) LIKE ?"
        ')',
      );
      final like = '%$search%';
      vars
        ..add(Variable.withString(like))
        ..add(Variable.withString(like))
        ..add(Variable.withString(like));
    }
    final whereClause = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';

    return 'SELECT 2 AS op_type, sr.id AS id, '
        'IFNULL(sr.edit_time, 0) AS edit_time, '
        'IFNULL(sr.amount, 0.0) AS amount, '
        'a.name AS supplier_name, NULL AS from_location, '
        'NULL AS to_location, sr.comment AS comment, '
        'IFNULL(sr.state, 0) AS state, '
        '(SELECT COUNT(*) FROM supplier_return_products srp WHERE srp.supplier_return_id = sr.id) AS product_count '
        'FROM supplier_returns sr '
        'LEFT JOIN agents a ON a.local_id = sr.supplier_id '
        '$whereClause';
  }

  String _buildOrderBy() {
    final dir = state.sortAscending ? 'ASC' : 'DESC';
    final column = switch (state.sortColumn) {
      'amount' => 'amount',
      'type' => 'op_type',
      'id' => 'id',
      'date' => 'edit_time',
      _ => 'edit_time',
    };
    return 'ORDER BY $column $dir';
  }

  StockRegistryItem _mapRow(QueryRow row) {
    final editTime = row.read<int?>('edit_time') ?? 0;
    final amountDouble = row.read<double?>('amount') ?? 0.0;
    final amount = const DecimalConverter().fromSql(amountDouble);
    final type = switch (row.read<int?>('op_type') ?? 0) {
      1 => StockOperationType.movement,
      2 => StockOperationType.supplierReturn,
      _ => StockOperationType.supply,
    };

    return StockRegistryItem(
      id: row.read<int>('id'),
      type: type,
      date: DateTime.fromMillisecondsSinceEpoch(editTime * 1000),
      amount: amount,
      supplierName: row.read<String?>('supplier_name'),
      fromLocation: row.read<String?>('from_location'),
      toLocation: row.read<String?>('to_location'),
      comment: row.read<String?>('comment'),
      productCount: row.read<int?>('product_count'),
      state: row.read<int?>('state') ?? 0,
    );
  }
}

final stockRegistryControllerProvider =
    NotifierProvider<StockRegistryNotifier, StockRegistryState>(
      StockRegistryNotifier.new,
    );

final stockRegistryHasActiveFiltersProvider = Provider<bool>((ref) {
  final state = ref.watch(stockRegistryControllerProvider);
  return state.hasActiveFilters;
});
