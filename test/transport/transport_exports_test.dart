import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/transport/transport_exports.dart';

void main() {
  group('Transport Exports', () {
    test('TransportMode enum is accessible', () {
      expect(TransportMode.values.length, 3);
      expect(TransportMode.telegramOnly, isNotNull);
      expect(TransportMode.restOnly, isNotNull);
      expect(TransportMode.hybrid, isNotNull);
    });

    test('TransportType enum is accessible', () {
      expect(TransportType.values.length, 4);
      expect(TransportType.telegram, isNotNull);
      expect(TransportType.rest, isNotNull);
      expect(TransportType.both, isNotNull);
      expect(TransportType.none, isNotNull);
    });

    test('RoutingStrategy enum is accessible', () {
      expect(RoutingStrategy.values.length, 5);
      expect(RoutingStrategy.telegramOnly, isNotNull);
      expect(RoutingStrategy.restOnly, isNotNull);
      expect(RoutingStrategy.telegramPriority, isNotNull);
      expect(RoutingStrategy.restPriority, isNotNull);
      expect(RoutingStrategy.parallel, isNotNull);
    });

    test('TransportOperation enum is accessible', () {
      expect(TransportOperation.values.length, greaterThan(20));
      expect(TransportOperation.uploadSales, isNotNull);
      expect(TransportOperation.downloadProducts, isNotNull);
      expect(TransportOperation.notifyShiftOpen, isNotNull);
    });

    test('QueuedOperationStatus enum is accessible', () {
      expect(QueuedOperationStatus.values.length, 6);
      expect(QueuedOperationStatus.pending, isNotNull);
      expect(QueuedOperationStatus.inProgress, isNotNull);
      expect(QueuedOperationStatus.completed, isNotNull);
    });

    test('TransportStatus enum is accessible', () {
      expect(TransportStatus.values, isNotEmpty);
      expect(TransportStatus.connected, isNotNull);
      expect(TransportStatus.disconnected, isNotNull);
    });
  });

  group('TransportConfig', () {
    test('creates telegram only config', () {
      final config = TransportConfig.telegramOnly(
        TelegramTransportConfig(apiId: 123, apiHash: 'test'),
      );

      expect(config.mode, TransportMode.telegramOnly);
      expect(config.hasTelegram, isTrue);
      expect(config.hasRest, isFalse);
    });

    test('creates rest only config', () {
      final config = TransportConfig.restOnly(
        RestTransportConfig(baseUrl: 'https://api.test.com'),
      );

      expect(config.mode, TransportMode.restOnly);
      expect(config.hasRest, isTrue);
      expect(config.hasTelegram, isFalse);
    });

    test('creates hybrid config', () {
      final config = TransportConfig.hybrid(
        telegram: TelegramTransportConfig(apiId: 123, apiHash: 'test'),
        rest: RestTransportConfig(baseUrl: 'https://api.test.com'),
      );

      expect(config.mode, TransportMode.hybrid);
      expect(config.hasTelegram, isTrue);
      expect(config.hasRest, isTrue);
    });
  });

  group('RoutingRule', () {
    test('creates with strategies', () {
      const rule = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
      );

      expect(rule.telegramOnlyStrategy, RoutingStrategy.telegramOnly);
      expect(rule.restOnlyStrategy, RoutingStrategy.restOnly);
      expect(rule.hybridStrategy, RoutingStrategy.telegramPriority);
    });

    test('getStrategy returns correct strategy for mode', () {
      const rule = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.parallel,
      );

      expect(
        rule.getStrategy(TransportMode.telegramOnly),
        RoutingStrategy.telegramOnly,
      );
      expect(
        rule.getStrategy(TransportMode.restOnly),
        RoutingStrategy.restOnly,
      );
      expect(rule.getStrategy(TransportMode.hybrid), RoutingStrategy.parallel);
    });

    test('copyWith works', () {
      const original = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
      );

      final copy = original.copyWith(maxRetries: 10);

      expect(copy.maxRetries, 10);
      expect(copy.hybridStrategy, original.hybridStrategy);
    });
  });

  group('TransportCoordinator', () {
    test('creates with config', () {
      final coordinator = TransportCoordinator(
        config: TransportConfig.restOnly(
          RestTransportConfig(baseUrl: 'https://api.test.com'),
        ),
        telegram: null,
        rest: null,
      );

      expect(coordinator.config.mode, TransportMode.restOnly);
    });
  });

  group('FallbackHandler', () {
    test('creates with callbacks', () async {
      final handler = FallbackHandler(logger: (msg) {}, onEvent: (event) {});

      expect(handler, isNotNull);
      await handler.dispose();
    });
  });

  group('ParallelExecutor', () {
    test('creates', () {
      final executor = ParallelExecutor();
      expect(executor, isNotNull);
    });
  });
}
