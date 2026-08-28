library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/bots/bot_command_router.dart';
import 'package:telepos/telegram/bots/bot_manager.dart';
import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_session_manager.dart';
import 'package:telepos/telegram/core/telegram_credentials.dart';
import 'package:telepos/telegram/core/telegram_initializer.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/encryption/e2e_encryption_service.dart';
import 'package:telepos/telegram/internal_chat/chat_room_manager.dart';
import 'package:telepos/telegram/messaging/message_queue.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';

import 'support/harness.dart';

/// The Telegram stack is registered behind `LocalProperties.telegramEnabled`,
/// and `_registerTelegramModule` swallows registration failures with nothing
/// but a log line. That combination means the whole transport can quietly stop
/// existing without a single test going red — which is what this file guards.
/// flutter_secure_storage is a platform plugin with no implementation in the
/// test VM, so back it with an in-memory map for the duration of the run.
void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            if (key != null) store[key] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'containsKey':
            return store.containsKey(key);
          case 'readAll':
            return Map<String, String>.from(store);
          case 'deleteAll':
            store.clear();
            return null;
          default:
            return null;
        }
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Telegram module wiring — flag on', () {
    final h = E2eHarness();

    setUpAll(() {
      _mockSecureStorage();
      return h.setUp(prefs: {'telegram_enabled': true});
    });
    tearDownAll(() => h.tearDown());

    test('every Telegram service registers and actually constructs', () {
      // Resolving matters more than isRegistered: these are lazy singletons, so
      // a broken constructor only surfaces on first access.
      expect(GetIt.I<TdLibClient>(), isNotNull);
      expect(GetIt.I<TdLibSessionManager>(), isNotNull);
      expect(GetIt.I<TelegramCredentials>(), isNotNull);
      expect(GetIt.I<TelegramInitializer>(), isNotNull);

      expect(GetIt.I<TelegramAuthService>(), isNotNull);
      expect(GetIt.I<E2EEncryptionService>(), isNotNull);

      expect(GetIt.I<ChannelManager>(), isNotNull);
      expect(GetIt.I<ChannelRegistry>(), isNotNull);

      expect(GetIt.I<BotManager>(), isNotNull);
      expect(GetIt.I<BotCommandRouter>(), isNotNull);

      expect(GetIt.I<MessageQueue>(), isNotNull);
      expect(GetIt.I<TelegramSyncEngine>(), isNotNull);
      expect(GetIt.I<NotificationService>(), isNotNull);
      expect(GetIt.I<ChatRoomManager>(), isNotNull);
    });

    test('ships without built-in API credentials', () async {
      // TelePOS must never carry an api_id/api_hash pair of its own: the repo
      // is public. Absent --dart-define and absent operator input, the
      // credential store has nothing to hand out.
      expect(TelegramAppCredentials.apiId, isNull);
      expect(TelegramAppCredentials.apiHash, isNull);
      expect(TelegramAppCredentials.isConfigured, isFalse);

      await expectLater(
        GetIt.I<TelegramCredentials>().createConfig(),
        throwsA(isA<StateError>()),
      );
    });

    test('operator-supplied credentials are accepted and cleared', () async {
      final store = GetIt.I<TelegramCredentials>();
      addTearDown(store.clearApiCredentials);

      await store.saveApiCredentials(apiId: 12345, apiHash: 'deadbeef');
      expect(await store.hasCredentials(), isTrue);

      final result = await store.loadCredentials();
      expect(result.isValid, isTrue);
      expect(result.apiId, 12345);
      expect(result.apiHash, 'deadbeef');

      await store.clearApiCredentials();
      expect(await store.hasCredentials(), isFalse);
    });
  });

  group('Telegram module wiring — flag off', () {
    final h = E2eHarness();

    setUpAll(() => h.setUp(prefs: {'telegram_enabled': false}));
    tearDownAll(() => h.tearDown());

    test('nothing from the Telegram stack is registered', () {
      expect(GetIt.I.isRegistered<TdLibClient>(), isFalse);
      expect(GetIt.I.isRegistered<TelegramAuthService>(), isFalse);
      expect(GetIt.I.isRegistered<TelegramSyncEngine>(), isFalse);
    });
  });
}
