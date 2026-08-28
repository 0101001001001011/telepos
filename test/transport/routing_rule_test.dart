import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/transport/transport_exports.dart';

void main() {
  group('RoutingStrategy', () {
    test('has all expected values', () {
      expect(RoutingStrategy.values.length, 5);
      expect(RoutingStrategy.telegramOnly, isNotNull);
      expect(RoutingStrategy.restOnly, isNotNull);
      expect(RoutingStrategy.telegramPriority, isNotNull);
      expect(RoutingStrategy.restPriority, isNotNull);
      expect(RoutingStrategy.parallel, isNotNull);
    });

    test('hasFallback returns correct values', () {
      expect(RoutingStrategy.telegramPriority.hasFallback, isTrue);
      expect(RoutingStrategy.restPriority.hasFallback, isTrue);
      expect(RoutingStrategy.telegramOnly.hasFallback, isFalse);
      expect(RoutingStrategy.restOnly.hasFallback, isFalse);
      expect(RoutingStrategy.parallel.hasFallback, isFalse);
    });

    test('primaryTransport returns correct values', () {
      expect(RoutingStrategy.telegramOnly.primaryTransport, 'telegram');
      expect(RoutingStrategy.telegramPriority.primaryTransport, 'telegram');
      expect(RoutingStrategy.restOnly.primaryTransport, 'rest');
      expect(RoutingStrategy.restPriority.primaryTransport, 'rest');
      expect(RoutingStrategy.parallel.primaryTransport, isNull);
    });

    test('fallbackTransport returns correct values', () {
      expect(RoutingStrategy.telegramPriority.fallbackTransport, 'rest');
      expect(RoutingStrategy.restPriority.fallbackTransport, 'telegram');
      expect(RoutingStrategy.telegramOnly.fallbackTransport, isNull);
      expect(RoutingStrategy.restOnly.fallbackTransport, isNull);
      expect(RoutingStrategy.parallel.fallbackTransport, isNull);
    });
  });

  group('RoutingRule', () {
    test('default constructor creates rule with all strategies', () {
      const rule = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
      );

      expect(rule.telegramOnlyStrategy, RoutingStrategy.telegramOnly);
      expect(rule.restOnlyStrategy, RoutingStrategy.restOnly);
      expect(rule.hybridStrategy, RoutingStrategy.telegramPriority);
    });

    test('getStrategy returns correct strategy for each mode', () {
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

    test('copyWith preserves unchanged values', () {
      const original = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
        maxRetries: 3,
        timeout: Duration(seconds: 30),
      );

      final modified = original.copyWith(maxRetries: 5);

      expect(modified.maxRetries, 5);
      expect(modified.hybridStrategy, original.hybridStrategy);
      expect(modified.timeout, original.timeout);
    });

    test('default values are sensible', () {
      const rule = RoutingRule(
        telegramOnlyStrategy: RoutingStrategy.telegramOnly,
        restOnlyStrategy: RoutingStrategy.restOnly,
        hybridStrategy: RoutingStrategy.telegramPriority,
      );

      expect(rule.maxRetries, greaterThan(0));
      expect(rule.timeout, isNotNull);
      expect(rule.canQueue, isTrue);
      expect(rule.queuePriority, greaterThan(0));
    });
  });

  group('TransportMode', () {
    test('has all expected values', () {
      expect(TransportMode.values.length, 3);
      expect(TransportMode.telegramOnly, isNotNull);
      expect(TransportMode.restOnly, isNotNull);
      expect(TransportMode.hybrid, isNotNull);
    });

    test('displayName returns human-readable names', () {
      expect(TransportMode.telegramOnly.displayName, 'Telegram');
      expect(TransportMode.restOnly.displayName, 'REST API');
      expect(TransportMode.hybrid.displayName, 'Hybrid');
    });

    test('icon returns emoji icons', () {
      expect(TransportMode.telegramOnly.icon, isNotEmpty);
      expect(TransportMode.restOnly.icon, isNotEmpty);
      expect(TransportMode.hybrid.icon, isNotEmpty);
    });
  });

  group('TransportOperation routing', () {
    test('upload operations exist', () {
      expect(TransportOperation.uploadSales, isNotNull);
      expect(TransportOperation.uploadRefunds, isNotNull);
      expect(TransportOperation.uploadShifts, isNotNull);
    });

    test('download operations exist', () {
      expect(TransportOperation.downloadProducts, isNotNull);
      expect(TransportOperation.downloadPrices, isNotNull);
      expect(TransportOperation.downloadConfig, isNotNull);
      expect(TransportOperation.downloadAgents, isNotNull);
    });

    test('backup operations exist', () {
      expect(TransportOperation.uploadBackup, isNotNull);
      expect(TransportOperation.downloadBackup, isNotNull);
      expect(TransportOperation.listBackups, isNotNull);
    });
  });
}
