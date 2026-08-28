library;

abstract class ChangeAnalyzer<T> {
  String get name;

  String get entityType;

  Future<int> getPendingCount();

  Future<List<T>> getPendingChanges({int limit = 100});

  Future<void> markSynced(List<dynamic> ids);

  Future<void> markFailed(dynamic id, String error);
}

class ProductChangeAnalyzer implements ChangeAnalyzer<Map<String, dynamic>> {
  @override
  String get name => 'ProductChangeAnalyzer';

  @override
  String get entityType => 'Product';

  @override
  Future<int> getPendingCount() async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingChanges({
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<void> markSynced(List<dynamic> ids) async {}

  @override
  Future<void> markFailed(dynamic id, String error) async {}
}

class AgentChangeAnalyzer implements ChangeAnalyzer<Map<String, dynamic>> {
  @override
  String get name => 'AgentChangeAnalyzer';

  @override
  String get entityType => 'Agent';

  @override
  Future<int> getPendingCount() async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingChanges({
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<void> markSynced(List<dynamic> ids) async {}

  @override
  Future<void> markFailed(dynamic id, String error) async {}
}

class SaleChangeAnalyzer implements ChangeAnalyzer<Map<String, dynamic>> {
  @override
  String get name => 'SaleChangeAnalyzer';

  @override
  String get entityType => 'Sale';

  @override
  Future<int> getPendingCount() async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingChanges({
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<void> markSynced(List<dynamic> ids) async {}

  @override
  Future<void> markFailed(dynamic id, String error) async {}
}

class PriceChangeAnalyzer implements ChangeAnalyzer<Map<String, dynamic>> {
  @override
  String get name => 'PriceChangeAnalyzer';

  @override
  String get entityType => 'Price';

  @override
  Future<int> getPendingCount() async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingChanges({
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<void> markSynced(List<dynamic> ids) async {}

  @override
  Future<void> markFailed(dynamic id, String error) async {}
}

class ConfigChangeAnalyzer implements ChangeAnalyzer<Map<String, dynamic>> {
  @override
  String get name => 'ConfigChangeAnalyzer';

  @override
  String get entityType => 'Config';

  @override
  Future<int> getPendingCount() async {
    return 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingChanges({
    int limit = 100,
  }) async {
    return [];
  }

  @override
  Future<void> markSynced(List<dynamic> ids) async {}

  @override
  Future<void> markFailed(dynamic id, String error) async {}
}

class ChangeAnalyzerRegistry {
  ChangeAnalyzerRegistry._();

  static final Map<String, ChangeAnalyzer<Map<String, dynamic>>> analyzers = {
    'Product': ProductChangeAnalyzer(),
    'Agent': AgentChangeAnalyzer(),
    'Sale': SaleChangeAnalyzer(),
    'Price': PriceChangeAnalyzer(),
    'Config': ConfigChangeAnalyzer(),
  };

  static ChangeAnalyzer<Map<String, dynamic>>? get(String entityType) {
    return analyzers[entityType];
  }

  static Future<int> getTotalPendingCount() async {
    var total = 0;
    for (final analyzer in analyzers.values) {
      total += await analyzer.getPendingCount();
    }
    return total;
  }

  static Future<Map<String, int>> getPendingSummary() async {
    final summary = <String, int>{};
    for (final entry in analyzers.entries) {
      summary[entry.key] = await entry.value.getPendingCount();
    }
    return summary;
  }
}
