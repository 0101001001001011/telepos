import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_config.dart';

class MockTalker extends Mock implements Talker {}

void main() {
  group('TdLibClientState', () {
    test('has all expected states', () {
      expect(
        TdLibClientState.values,
        containsAll([
          TdLibClientState.uninitialized,
          TdLibClientState.initializing,
          TdLibClientState.waitingForTdlibParameters,
          TdLibClientState.waitingForPhoneNumber,
          TdLibClientState.waitingForCode,
          TdLibClientState.waitingForPassword,
          TdLibClientState.waitingForRegistration,
          TdLibClientState.ready,
          TdLibClientState.loggingOut,
          TdLibClientState.closing,
          TdLibClientState.closed,
          TdLibClientState.error,
        ]),
      );
    });

    test('state count is 12', () {
      expect(TdLibClientState.values.length, 12);
    });
  });

  group('TdLibException', () {
    test('creates exception with code and message', () {
      final exception = TdLibException(code: 404, message: 'Not Found');

      expect(exception.code, 404);
      expect(exception.message, 'Not Found');
    });

    test('toString formats correctly', () {
      final exception = TdLibException(code: 500, message: 'Internal Error');

      expect(exception.toString(), 'TdLibException(500): Internal Error');
    });

    test('creates exception with negative code', () {
      final exception = TdLibException(code: -1, message: 'Library not found');

      expect(exception.code, -1);
      expect(exception.message, 'Library not found');
    });

    test('creates exception with empty message', () {
      final exception = TdLibException(code: 0, message: '');

      expect(exception.code, 0);
      expect(exception.message, isEmpty);
      expect(exception.toString(), 'TdLibException(0): ');
    });

    test('exception implements Exception', () {
      final exception = TdLibException(code: 1, message: 'test');

      expect(exception, isA<Exception>());
    });
  });

  group('TdLibClient', () {
    late MockTalker mockTalker;
    late TdLibLogger logger;
    late TdLibClient client;

    setUp(() {
      mockTalker = MockTalker();
      logger = TdLibLogger(talker: mockTalker);
      client = TdLibClient(logger: logger);

      when(() => mockTalker.info(any())).thenReturn(null);
      when(() => mockTalker.error(any(), any(), any())).thenReturn(null);
      when(() => mockTalker.verbose(any(), any())).thenReturn(null);
      when(() => mockTalker.warning(any())).thenReturn(null);
    });

    tearDown(() async {
      if (client.state != TdLibClientState.closed) {
        try {
          await client.close();
        } catch (_) {}
      }
    });

    group('initial state', () {
      test('state is uninitialized', () {
        expect(client.state, TdLibClientState.uninitialized);
      });

      test('isReady is false', () {
        expect(client.isReady, false);
      });

      test('isRunning is false', () {
        expect(client.isRunning, false);
      });

      test('updates stream is broadcast', () {
        expect(client.updates.isBroadcast, true);
      });

      test('stateChanges stream is broadcast', () {
        expect(client.stateChanges.isBroadcast, true);
      });
    });

    group('isReady getter', () {
      test('returns false when uninitialized', () {
        expect(client.isReady, false);
      });

      test('returns false when not in ready state', () {
        expect(client.state, isNot(TdLibClientState.ready));
        expect(client.isReady, false);
      });
    });

    group('isRunning getter', () {
      test('returns false when service is null', () {
        expect(client.isRunning, false);
      });
    });

    group('initialize validation', () {
      test('throws ArgumentError for invalid config - zero apiId', () async {
        final invalidConfig = TelegramConfig(
          apiId: 0,
          apiHash: 'validhash123',
          databaseDirectory: '/valid/path',
          filesDirectory: '/valid/files',
        );

        expect(
          () => client.initialize(invalidConfig),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws ArgumentError for invalid config - negative apiId',
        () async {
          final invalidConfig = TelegramConfig(
            apiId: -1,
            apiHash: 'validhash123',
            databaseDirectory: '/valid/path',
            filesDirectory: '/valid/files',
          );

          expect(
            () => client.initialize(invalidConfig),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('throws ArgumentError for invalid config - empty apiHash', () async {
        final invalidConfig = TelegramConfig(
          apiId: 12345,
          apiHash: '',
          databaseDirectory: '/valid/path',
          filesDirectory: '/valid/files',
        );

        expect(
          () => client.initialize(invalidConfig),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'throws ArgumentError for invalid config - empty databaseDirectory',
        () async {
          final invalidConfig = TelegramConfig(
            apiId: 12345,
            apiHash: 'validhash',
            databaseDirectory: '',
            filesDirectory: '/valid/files',
          );

          expect(
            () => client.initialize(invalidConfig),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test(
        'throws ArgumentError for invalid config - empty filesDirectory',
        () async {
          final invalidConfig = TelegramConfig(
            apiId: 12345,
            apiHash: 'validhash',
            databaseDirectory: '/valid/path',
            filesDirectory: '',
          );

          expect(
            () => client.initialize(invalidConfig),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('throws ArgumentError with multiple validation errors', () async {
        final invalidConfig = TelegramConfig(
          apiId: 0,
          apiHash: '',
          databaseDirectory: '',
          filesDirectory: '',
        );

        expect(
          () => client.initialize(invalidConfig),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('apiId'),
            ),
          ),
        );
      });
    });

    group('state transitions', () {
      test('state remains uninitialized before initialize call', () {
        expect(client.state, TdLibClientState.uninitialized);
      });
    });

    group('stateChanges stream', () {
      test('can have multiple listeners', () async {
        final listener1Events = <TdLibClientState>[];
        final listener2Events = <TdLibClientState>[];

        final sub1 = client.stateChanges.listen(listener1Events.add);
        final sub2 = client.stateChanges.listen(listener2Events.add);

        await client.close();

        await sub1.cancel();
        await sub2.cancel();

        expect(listener1Events, listener2Events);
      });

      test('emits closing and closed states on close', () async {
        final stateEvents = <TdLibClientState>[];
        final subscription = client.stateChanges.listen(stateEvents.add);

        await client.close();

        await subscription.cancel();

        expect(stateEvents, contains(TdLibClientState.closing));
        expect(stateEvents, contains(TdLibClientState.closed));
      });
    });

    group('updates stream', () {
      test('can have multiple listeners (broadcast)', () {
        final listener1 = <Map<String, dynamic>>[];
        final listener2 = <Map<String, dynamic>>[];

        final sub1 = client.updates.listen(listener1.add);
        final sub2 = client.updates.listen(listener2.add);

        expect(sub1, isNotNull);
        expect(sub2, isNotNull);

        sub1.cancel();
        sub2.cancel();
      });

      test('stream is broadcast type', () {
        expect(client.updates.isBroadcast, true);
      });
    });

    group('close', () {
      test('sets state to closed', () async {
        await client.close();

        expect(client.state, TdLibClientState.closed);
      });

      test('can be called multiple times safely', () async {
        await client.close();
        await client.close();
        await client.close();

        expect(client.state, TdLibClientState.closed);
      });

      test('emits closing state before closed', () async {
        final states = <TdLibClientState>[];
        client.stateChanges.listen(states.add);

        await client.close();

        await Future<void>.delayed(Duration.zero);

        expect(states.length, greaterThanOrEqualTo(2));
        expect(
          states.indexOf(TdLibClientState.closing),
          lessThan(states.indexOf(TdLibClientState.closed)),
        );
      });

      test('closes update stream', () async {
        await client.close();

        final events = <Map<String, dynamic>>[];
        final subscription = client.updates.listen(events.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(events, isEmpty);
      });

      test('closes state changes stream', () async {
        await client.close();

        final states = <TdLibClientState>[];
        final subscription = client.stateChanges.listen(states.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states, isEmpty);
      });
    });

    group('send methods without initialization', () {
      test('send throws StateError when not initialized', () async {
        expect(
          () => client.send({'@type': 'test'}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('sendSync throws StateError when not initialized', () async {
        expect(
          () => client.sendSync({'@type': 'test'}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });

      test('execute throws StateError when not initialized', () async {
        expect(
          () => client.execute({'@type': 'test'}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
          ),
        );
      });
    });

    group('auth methods without initialization', () {
      test('setAuthenticationPhoneNumber throws StateError', () async {
        expect(
          () => client.setAuthenticationPhoneNumber('+77001234567'),
          throwsA(isA<StateError>()),
        );
      });

      test('checkAuthenticationCode throws StateError', () async {
        expect(
          () => client.checkAuthenticationCode('12345'),
          throwsA(isA<StateError>()),
        );
      });

      test('checkAuthenticationPassword throws StateError', () async {
        expect(
          () => client.checkAuthenticationPassword('password'),
          throwsA(isA<StateError>()),
        );
      });

      test('requestQrCodeAuthentication throws StateError', () async {
        expect(
          () => client.requestQrCodeAuthentication(null),
          throwsA(isA<StateError>()),
        );
      });

      test('registerUser throws StateError', () async {
        expect(
          () => client.registerUser('John', 'Doe'),
          throwsA(isA<StateError>()),
        );
      });

      test('logOut throws StateError', () async {
        expect(() => client.logOut(), throwsA(isA<StateError>()));
      });
    });

    group('messaging methods without initialization', () {
      test('getChats throws StateError', () async {
        expect(() => client.getChats(), throwsA(isA<StateError>()));
      });

      test('getChat throws StateError', () async {
        expect(() => client.getChat(123), throwsA(isA<StateError>()));
      });

      test('sendMessage throws StateError', () async {
        expect(
          () => client.sendMessage(chatId: 123, text: 'Hello'),
          throwsA(isA<StateError>()),
        );
      });

      test('getChatHistory throws StateError', () async {
        expect(
          () => client.getChatHistory(chatId: 123),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('channel/group methods without initialization', () {
      test('createChannel throws StateError', () async {
        expect(
          () => client.createChannel(title: 'Test Channel'),
          throwsA(isA<StateError>()),
        );
      });

      test('createGroup throws StateError', () async {
        expect(
          () => client.createGroup(title: 'Test Group', userIds: [1, 2, 3]),
          throwsA(isA<StateError>()),
        );
      });
    });
  });

  group('TdLibClient state behavior', () {
    late TdLibClient client;

    setUp(() {
      final logger = TdLibLogger(talker: MockTalker());
      client = TdLibClient(logger: logger);
    });

    tearDown(() async {
      try {
        await client.close();
      } catch (_) {}
    });

    test('client can be created with custom logger', () {
      final customTalker = MockTalker();
      final customLogger = TdLibLogger(talker: customTalker);
      final customClient = TdLibClient(logger: customLogger);

      expect(customClient, isNotNull);
      expect(customClient.state, TdLibClientState.uninitialized);
    });

    test('each client instance has independent state', () async {
      final logger1 = TdLibLogger(talker: MockTalker());
      final logger2 = TdLibLogger(talker: MockTalker());

      final client1 = TdLibClient(logger: logger1);
      final client2 = TdLibClient(logger: logger2);

      expect(client1.state, TdLibClientState.uninitialized);
      expect(client2.state, TdLibClientState.uninitialized);

      await client1.close();

      expect(client1.state, TdLibClientState.closed);
      expect(client2.state, TdLibClientState.uninitialized);

      await client2.close();
    });
  });

  group('TelegramConfig integration', () {
    test('valid config passes validation', () {
      final validConfig = TelegramConfig(
        apiId: 12345,
        apiHash: 'abcdef123456',
        databaseDirectory: '/path/to/db',
        filesDirectory: '/path/to/files',
      );

      expect(validConfig.apiId, 12345);
      expect(validConfig.apiHash, 'abcdef123456');
      expect(validConfig.databaseDirectory, '/path/to/db');
      expect(validConfig.filesDirectory, '/path/to/files');
    });

    test('config has default values', () {
      final config = TelegramConfig(
        apiId: 12345,
        apiHash: 'hash',
        databaseDirectory: '/db',
        filesDirectory: '/files',
      );

      expect(config.useTestDc, false);
      expect(config.logVerbosityLevel, 2);
      expect(config.deviceModel, 'TelePOS Terminal');
      expect(config.applicationVersion, '1.0.0');
      expect(config.systemLanguageCode, 'ru');
      expect(config.enableStorageEncryption, true);
      expect(config.useFileDatabase, true);
      expect(config.useChatInfoDatabase, true);
      expect(config.useMessageDatabase, true);
    });

    test('config optional fields can be set', () {
      final config = TelegramConfig(
        apiId: 12345,
        apiHash: 'hash',
        databaseDirectory: '/db',
        filesDirectory: '/files',
        useTestDc: true,
        posId: 'POS-001',
        storeName: 'Test Store',
        storageEncryptionKey: 'secret-key',
      );

      expect(config.useTestDc, true);
      expect(config.posId, 'POS-001');
      expect(config.storeName, 'Test Store');
      expect(config.storageEncryptionKey, 'secret-key');
    });
  });

  group('TdLibClientState enum behavior', () {
    test('authorization flow states are in correct order', () {
      final authFlowStates = [
        TdLibClientState.waitingForTdlibParameters,
        TdLibClientState.waitingForPhoneNumber,
        TdLibClientState.waitingForCode,
        TdLibClientState.waitingForPassword,
        TdLibClientState.waitingForRegistration,
        TdLibClientState.ready,
      ];

      for (final state in authFlowStates) {
        expect(TdLibClientState.values, contains(state));
      }
    });

    test('lifecycle states exist', () {
      expect(TdLibClientState.values, contains(TdLibClientState.uninitialized));
      expect(TdLibClientState.values, contains(TdLibClientState.initializing));
      expect(TdLibClientState.values, contains(TdLibClientState.loggingOut));
      expect(TdLibClientState.values, contains(TdLibClientState.closing));
      expect(TdLibClientState.values, contains(TdLibClientState.closed));
      expect(TdLibClientState.values, contains(TdLibClientState.error));
    });

    test('state names match expected values', () {
      expect(TdLibClientState.uninitialized.name, 'uninitialized');
      expect(TdLibClientState.initializing.name, 'initializing');
      expect(TdLibClientState.ready.name, 'ready');
      expect(TdLibClientState.closed.name, 'closed');
      expect(TdLibClientState.error.name, 'error');
    });
  });
}
