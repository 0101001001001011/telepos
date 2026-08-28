import 'dart:async';

import '../coordinator/coordinator_exports.dart';
import '../interface/transport_interface_exports.dart';
import '../queue/offline_queue.dart';
import 'migration_state.dart';

class MigrationValidator {
  final TransportInterface? _telegram;
  final TransportInterface? _rest;
  final OfflineQueue _queue;
  final void Function(String)? _logger;

  MigrationValidator({
    TransportInterface? telegram,
    TransportInterface? rest,
    required OfflineQueue queue,
    void Function(String)? logger,
  }) : _telegram = telegram,
       _rest = rest,
       _queue = queue,
       _logger = logger;

  Future<MigrationValidationResult> validate({
    required TransportMode fromMode,
    required TransportMode toMode,
  }) async {
    _log('Validating migration: $fromMode -> $toMode');

    final errors = <String>[];
    final warnings = <String>[];
    final details = <String, dynamic>{};

    if (fromMode == toMode) {
      errors.add('Source and target modes are the same');
      return MigrationValidationResult.failure(errors: errors);
    }

    final targetAvailable = await _checkTargetTransportAvailable(toMode);
    details['targetAvailable'] = targetAvailable;
    if (!targetAvailable) {
      errors.add('Target transport is not available');
    }

    final queueStats = await _queue.getStatistics();
    details['pendingOperations'] = queueStats.pending;
    details['failedOperations'] = queueStats.failed;

    if (queueStats.pending > 0) {
      warnings.add('${queueStats.pending} operations pending in queue');
    }
    if (queueStats.failed > 0) {
      warnings.add('${queueStats.failed} failed operations in queue');
    }

    final networkAvailable = await _checkNetworkAvailable();
    details['networkAvailable'] = networkAvailable;
    if (!networkAvailable) {
      warnings.add('Network is not available. Migration may fail.');
    }

    if (toMode == TransportMode.telegramOnly ||
        toMode == TransportMode.hybrid) {
      final telegramReady = await _checkTelegramReady();
      details['telegramReady'] = telegramReady;
      if (!telegramReady) {
        errors.add('Telegram is not authorized or ready');
      }
    }

    if (toMode == TransportMode.restOnly || toMode == TransportMode.hybrid) {
      final restReady = await _checkRestReady();
      details['restReady'] = restReady;
      if (!restReady) {
        errors.add('REST API is not configured or available');
      }
    }

    final estimatedDuration = _estimateMigrationDuration(queueStats.pending);
    details['estimatedDurationSeconds'] = estimatedDuration.inSeconds;

    _log('Validation complete: ${errors.isEmpty ? "OK" : "FAILED"}');

    if (errors.isNotEmpty) {
      return MigrationValidationResult.failure(
        errors: errors,
        warnings: warnings,
        details: details,
      );
    }

    return MigrationValidationResult.success(
      warnings: warnings,
      details: details,
    );
  }

  Future<bool> _checkTargetTransportAvailable(TransportMode mode) async {
    switch (mode) {
      case TransportMode.telegramOnly:
        return await _isTransportAvailable(_telegram);
      case TransportMode.restOnly:
        return await _isTransportAvailable(_rest);
      case TransportMode.hybrid:
        final telegramAvailable = await _isTransportAvailable(_telegram);
        final restAvailable = await _isTransportAvailable(_rest);
        return telegramAvailable || restAvailable;
    }
  }

  Future<bool> _isTransportAvailable(TransportInterface? transport) async {
    if (transport == null) return false;
    return await transport.isAvailable();
  }

  Future<bool> _checkNetworkAvailable() async {
    if (await _isTransportAvailable(_rest)) {
      return true;
    }
    if (await _isTransportAvailable(_telegram)) {
      return true;
    }
    return false;
  }

  Future<bool> _checkTelegramReady() async {
    final telegram = _telegram;
    if (telegram == null) return false;

    try {
      return await telegram.isAvailable();
    } catch (e) {
      _log('Telegram check failed: $e');
      return false;
    }
  }

  Future<bool> _checkRestReady() async {
    final rest = _rest;
    if (rest == null) return false;

    try {
      return await rest.isAvailable();
    } catch (e) {
      _log('REST check failed: $e');
      return false;
    }
  }

  Duration _estimateMigrationDuration(int pendingOperations) {
    final baseSeconds = 5;
    final operationsMillis = pendingOperations * 100;
    final switchSeconds = 2;

    return Duration(
      milliseconds:
          baseSeconds * 1000 + operationsMillis + switchSeconds * 1000,
    );
  }

  void _log(String message) {
    _logger?.call('[MigrationValidator] $message');
  }
}

class RollbackValidator {
  final TransportInterface? _telegram;
  final TransportInterface? _rest;
  final void Function(String)? _logger;

  RollbackValidator({
    TransportInterface? telegram,
    TransportInterface? rest,
    void Function(String)? logger,
  }) : _telegram = telegram,
       _rest = rest,
       _logger = logger;

  Future<bool> canRollback({required TransportMode originalMode}) async {
    _log('Checking rollback possibility to $originalMode');

    switch (originalMode) {
      case TransportMode.telegramOnly:
        return await _isTransportAvailable(_telegram);
      case TransportMode.restOnly:
        return await _isTransportAvailable(_rest);
      case TransportMode.hybrid:
        final telegramOk = await _isTransportAvailable(_telegram);
        final restOk = await _isTransportAvailable(_rest);
        return telegramOk || restOk;
    }
  }

  Future<bool> _isTransportAvailable(TransportInterface? transport) async {
    if (transport == null) return false;
    return await transport.isAvailable();
  }

  void _log(String message) {
    _logger?.call('[RollbackValidator] $message');
  }
}
