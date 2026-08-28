import 'package:telepos/telegram/core/tdlib_logger.dart';

enum ConflictStrategy { lastWriteWins, serverWins, clientWins, merge, manual }

class DataConflict {
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localVersion;
  final Map<String, dynamic> remoteVersion;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final String localSource;
  final String remoteSource;

  DataConflict({
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.localSource,
    required this.remoteSource,
  });
}

class ConflictResolution {
  final Map<String, dynamic> resolvedData;
  final ConflictStrategy usedStrategy;
  final String? winnerSource;

  ConflictResolution({
    required this.resolvedData,
    required this.usedStrategy,
    this.winnerSource,
  });
}

class ConflictResolver {
  final TdLibLogger _logger;
  final ConflictStrategy _defaultStrategy;

  final Map<String, ConflictStrategy> _entityStrategies = {};

  final List<DataConflict> _unresolvedConflicts = [];

  ConflictResolver({
    required TdLibLogger logger,
    ConflictStrategy defaultStrategy = ConflictStrategy.lastWriteWins,
  }) : _logger = logger,
       _defaultStrategy = defaultStrategy;

  List<DataConflict> get unresolvedConflicts =>
      List.unmodifiable(_unresolvedConflicts);

  void setStrategy(String entityType, ConflictStrategy strategy) {
    _entityStrategies[entityType] = strategy;
  }

  ConflictResolution resolve(DataConflict conflict) {
    final strategy = _entityStrategies[conflict.entityType] ?? _defaultStrategy;

    _logger.logSync(
      'Resolving conflict: ${conflict.entityType}#${conflict.entityId} '
      'strategy=$strategy',
    );

    switch (strategy) {
      case ConflictStrategy.lastWriteWins:
        return _resolveLastWriteWins(conflict);

      case ConflictStrategy.serverWins:
        return ConflictResolution(
          resolvedData: conflict.remoteVersion,
          usedStrategy: strategy,
          winnerSource: conflict.remoteSource,
        );

      case ConflictStrategy.clientWins:
        return ConflictResolution(
          resolvedData: conflict.localVersion,
          usedStrategy: strategy,
          winnerSource: conflict.localSource,
        );

      case ConflictStrategy.merge:
        return _resolveMerge(conflict);

      case ConflictStrategy.manual:
        _unresolvedConflicts.add(conflict);
        _logger.logSync(
          'Conflict queued for manual resolution: '
          '${conflict.entityType}#${conflict.entityId}',
        );
        return _resolveLastWriteWins(conflict);
    }
  }

  void resolveManually(
    DataConflict conflict,
    Map<String, dynamic> resolvedData,
  ) {
    _unresolvedConflicts.remove(conflict);
    _logger.logSync(
      'Conflict manually resolved: '
      '${conflict.entityType}#${conflict.entityId}',
    );
  }

  ConflictResolution _resolveLastWriteWins(DataConflict conflict) {
    if (conflict.localTimestamp.isAfter(conflict.remoteTimestamp)) {
      return ConflictResolution(
        resolvedData: conflict.localVersion,
        usedStrategy: ConflictStrategy.lastWriteWins,
        winnerSource: conflict.localSource,
      );
    } else {
      return ConflictResolution(
        resolvedData: conflict.remoteVersion,
        usedStrategy: ConflictStrategy.lastWriteWins,
        winnerSource: conflict.remoteSource,
      );
    }
  }

  ConflictResolution _resolveMerge(DataConflict conflict) {
    final merged = <String, dynamic>{};
    merged.addAll(conflict.localVersion);

    for (final entry in conflict.remoteVersion.entries) {
      if (!conflict.localVersion.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
      } else if (conflict.localVersion[entry.key] != entry.value) {
        if (conflict.remoteTimestamp.isAfter(conflict.localTimestamp)) {
          merged[entry.key] = entry.value;
        }
      }
    }

    return ConflictResolution(
      resolvedData: merged,
      usedStrategy: ConflictStrategy.merge,
    );
  }
}
