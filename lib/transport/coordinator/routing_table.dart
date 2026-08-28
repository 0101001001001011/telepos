import '../interface/transport_operation.dart';
import 'routing_rule.dart';
import 'routing_strategy.dart';

class RoutingTable {
  final Map<TransportOperation, RoutingRule> _rules;

  RoutingTable._(this._rules);

  factory RoutingTable.defaults() {
    return RoutingTable._(_buildDefaultRules());
  }

  factory RoutingTable.custom(Map<TransportOperation, RoutingRule> rules) {
    final defaults = _buildDefaultRules();
    return RoutingTable._({...defaults, ...rules});
  }

  RoutingRule getRule(TransportOperation operation) {
    return _rules[operation] ?? _defaultRule;
  }

  RoutingStrategy getStrategy(
    TransportOperation operation,
    TransportMode mode,
  ) {
    return getRule(operation).getStrategy(mode);
  }

  static const _defaultRule = RoutingRule(
    telegramOnlyStrategy: RoutingStrategy.telegramOnly,
    restOnlyStrategy: RoutingStrategy.restOnly,
    hybridStrategy: RoutingStrategy.restPriority,
  );

  static Map<TransportOperation, RoutingRule> _buildDefaultRules() {
    return {
      TransportOperation.uploadSales: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        maxRetries: 5,
        queuePriority: 10,
        canQueue: true,
      ),
      TransportOperation.uploadRefunds: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        maxRetries: 5,
        queuePriority: 10,
        canQueue: true,
      ),
      TransportOperation.uploadShifts: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        maxRetries: 5,
        queuePriority: 20,
        canQueue: true,
      ),
      TransportOperation.uploadCashOperations: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        queuePriority: 30,
        canQueue: true,
      ),

      TransportOperation.downloadProducts: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        timeout: Duration(minutes: 2),
      ),
      TransportOperation.downloadPrices: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
      ),
      TransportOperation.downloadCategories: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
      ),
      TransportOperation.downloadAgents: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
      ),
      TransportOperation.downloadConfig: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
      ),
      TransportOperation.downloadUsers: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
      ),

      TransportOperation.uploadBackup: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        timeout: Duration(minutes: 5),
        maxRetries: 3,
        queuePriority: 40,
        canQueue: true,
      ),
      TransportOperation.listBackups: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
      ),
      TransportOperation.downloadBackup: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
        timeout: Duration(minutes: 10),
      ),
      TransportOperation.deleteBackup: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
      ),

      TransportOperation.notifyShiftOpen: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.notifyShiftClose: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.notifyLargeSale: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.notifyRefund: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.notifyError: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.notifyFiscalError: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),

      TransportOperation.sendZReport: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.parallel,
        queuePriority: 30,
        canQueue: true,
      ),
      TransportOperation.sendDailyReport: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.parallel,
        queuePriority: 35,
        canQueue: true,
      ),
      TransportOperation.sendWeeklyReport: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.parallel,
        queuePriority: 35,
        canQueue: true,
      ),

      TransportOperation.authPhone: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.telegramOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.authQr: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.telegramOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: false,
      ),
      TransportOperation.authCredentials: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.restOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restOnly,
        canQueue: false,
      ),
      TransportOperation.authRefreshToken: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.restOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restOnly,
        canQueue: false,
      ),

      TransportOperation.subscribePriceUpdates: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        canQueue: false,
      ),
      TransportOperation.subscribeStockUpdates: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.restPriority,
        canQueue: false,
      ),
      TransportOperation.receiveRemoteCommands: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.parallel,
        canQueue: false,
      ),

      TransportOperation.p2pDirectSync: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.telegramOnly,
        hybridStrategy: RoutingStrategy.telegramOnly,
        canQueue: true,
        queuePriority: 50,
      ),
      TransportOperation.p2pStockTransfer: const RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.telegramPriority,
        hybridStrategy: RoutingStrategy.telegramPriority,
        canQueue: true,
      ),
    };
  }

  RoutingTable applyOverrides(RoutingOverrides overrides) {
    final newRules = Map<TransportOperation, RoutingRule>.from(_rules);

    for (final op in overrides.forceTelegram) {
      final existing = newRules[op] ?? _defaultRule;
      newRules[op] = existing.copyWith(
        hybridStrategy: RoutingStrategy.telegramOnly,
      );
    }

    for (final op in overrides.forceRest) {
      final existing = newRules[op] ?? _defaultRule;
      newRules[op] = existing.copyWith(
        hybridStrategy: RoutingStrategy.restOnly,
      );
    }

    for (final op in overrides.forceBoth) {
      final existing = newRules[op] ?? _defaultRule;
      newRules[op] = existing.copyWith(
        hybridStrategy: RoutingStrategy.parallel,
      );
    }

    return RoutingTable._(newRules);
  }
}

class RoutingOverrides {
  final Set<TransportOperation> forceTelegram;

  final Set<TransportOperation> forceRest;

  final Set<TransportOperation> forceBoth;

  final Set<TransportOperation> noFallback;

  const RoutingOverrides({
    this.forceTelegram = const {},
    this.forceRest = const {},
    this.forceBoth = const {},
    this.noFallback = const {},
  });

  static const empty = RoutingOverrides();

  bool get isEmpty =>
      forceTelegram.isEmpty &&
      forceRest.isEmpty &&
      forceBoth.isEmpty &&
      noFallback.isEmpty;
}
