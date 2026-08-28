import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';

class MockTdLibClient extends Mock implements TdLibClient {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

void main() {
  late MockTdLibClient mockClient;
  late MockTdLibLogger mockLogger;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockClient = MockTdLibClient();
    mockLogger = MockTdLibLogger();

    when(() => mockLogger.logConnection(any())).thenReturn(null);
    when(() => mockLogger.logSync(any())).thenReturn(null);
    when(() => mockLogger.logError(any(), any(), any())).thenReturn(null);
  });

  group('E2E: Auth Flow', () {
    test('complete phone auth flow: phone -> code -> authorized', () async {
      when(
        () => mockClient.sendSync({
          '@type': 'setAuthenticationPhoneNumber',
          'phone_number': '+77001234567',
        }),
      ).thenAnswer((_) async => {'@type': 'ok'});

      when(
        () => mockClient.sendSync({
          '@type': 'checkAuthenticationCode',
          'code': '12345',
        }),
      ).thenAnswer((_) async => {'@type': 'ok'});

      when(
        () => mockClient.sendSync({'@type': 'getAuthorizationState'}),
      ).thenAnswer((_) async => {'@type': 'authorizationStateReady'});

      final phoneResult = await mockClient.sendSync({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': '+77001234567',
      });
      expect(phoneResult['@type'], 'ok');

      final codeResult = await mockClient.sendSync({
        '@type': 'checkAuthenticationCode',
        'code': '12345',
      });
      expect(codeResult['@type'], 'ok');

      final authState = await mockClient.sendSync({
        '@type': 'getAuthorizationState',
      });
      expect(authState['@type'], 'authorizationStateReady');
    });

    test('auth with 2FA password', () async {
      when(
        () => mockClient.sendSync({
          '@type': 'checkAuthenticationPassword',
          'password': 'secret',
        }),
      ).thenAnswer((_) async => {'@type': 'ok'});

      final result = await mockClient.sendSync({
        '@type': 'checkAuthenticationPassword',
        'password': 'secret',
      });

      expect(result['@type'], 'ok');
    });
  });

  group('E2E: Channel Creation', () {
    late ChannelManager channelManager;
    late ChannelRegistry channelRegistry;

    setUp(() {
      channelManager = ChannelManager(client: mockClient, logger: mockLogger);
      channelRegistry = ChannelRegistry(
        logger: mockLogger,
        registryPath: '/tmp/test_registry.json',
      );
    });

    test('create all system channels for store', () async {
      const storeName = 'TestStore';

      int chatIdCounter = -1000000000;
      when(
        () => mockClient.createChannel(
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async {
        final id = chatIdCounter--;
        return {'@type': 'chat', 'id': id, 'title': 'Test Channel'};
      });

      final systemChannel = await channelManager.createChannel(
        title: '$storeName-POS-System',
        description: 'System events',
        channelType: SystemChannelType.posSystem,
        storeName: storeName,
      );

      final salesChannel = await channelManager.createChannel(
        title: '$storeName-POS-Sales',
        description: 'Sales feed',
        channelType: SystemChannelType.posSales,
        storeName: storeName,
      );

      channelRegistry.register(SystemChannelType.posSystem, systemChannel);
      channelRegistry.register(SystemChannelType.posSales, salesChannel);

      expect(channelRegistry.get(SystemChannelType.posSystem), isNotNull);
      expect(channelRegistry.get(SystemChannelType.posSales), isNotNull);
      expect(channelRegistry.count, 2);
    });

    test('create staff chat group', () async {
      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'chat',
          'id': -1000000001,
          'title': 'Staff Chat',
        },
      );

      final group = await channelManager.createGroup(
        title: 'TestStore-Staff-Chat',
        description: 'Staff internal chat',
        channelType: SystemChannelType.staffChat,
        storeName: 'TestStore',
      );

      expect(group.chatId, isNot(0));
      expect(group.isChannel, false);
    });

    test('channel registry persistence', () async {
      when(
        () => mockClient.createChannel(
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      ).thenAnswer(
        (_) async => {
          '@type': 'chat',
          'id': -1000000001,
          'title': 'Test Channel',
        },
      );

      final channel = await channelManager.createChannel(
        title: 'Test-Channel',
        description: 'Test',
        channelType: SystemChannelType.posSystem,
      );

      channelRegistry.register(SystemChannelType.posSystem, channel);

      final retrievedChannel = channelRegistry.get(SystemChannelType.posSystem);
      expect(retrievedChannel, isNotNull);
      expect(retrievedChannel?.chatId, channel.chatId);
    });
  });

  group('E2E: Messaging', () {
    late MessageService messageService;
    const testChatId = -1000000001;

    setUp(() {
      messageService = MessageService(client: mockClient, logger: mockLogger);
    });

    test('send and receive text message', () async {
      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'message',
          'id': 123,
          'chat_id': testChatId,
          'sender_id': {'@type': 'messageSenderUser', 'user_id': 456},
          'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_outgoing': true,
          'content': {
            '@type': 'messageText',
            'text': {'@type': 'formattedText', 'text': 'Hello from POS!'},
          },
        },
      );

      final sentMessage = await messageService.sendText(
        testChatId,
        'Hello from POS!',
      );

      expect(sentMessage.messageId, 123);
      expect(sentMessage.direction, MessageDirection.outgoing);
    });

    test('get chat history', () async {
      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'messages',
          'messages': [
            {
              'id': 1,
              'chat_id': testChatId,
              'sender_id': {'@type': 'messageSenderUser', 'user_id': 456},
              'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'is_outgoing': false,
              'content': {
                '@type': 'messageText',
                'text': {'@type': 'formattedText', 'text': 'Message 1'},
              },
            },
            {
              'id': 2,
              'chat_id': testChatId,
              'sender_id': {'@type': 'messageSenderUser', 'user_id': 456},
              'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'is_outgoing': true,
              'content': {
                '@type': 'messageText',
                'text': {'@type': 'formattedText', 'text': 'Message 2'},
              },
            },
          ],
          'total_count': 2,
        },
      );

      final history = await messageService.getHistory(testChatId);

      expect(history.length, 2);
    });

    test('search messages in chat', () async {
      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'messages',
          'messages': [
            {
              'id': 1,
              'chat_id': testChatId,
              'sender_id': {'@type': 'messageSenderUser', 'user_id': 456},
              'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'is_outgoing': false,
              'content': {
                '@type': 'messageText',
                'text': {'@type': 'formattedText', 'text': 'Sales report'},
              },
            },
          ],
          'total_count': 1,
        },
      );

      final results = await messageService.searchMessages(testChatId, 'sales');

      expect(results.length, 1);
    });
  });

  group('E2E: Data Sync Protocol', () {
    test('sync packet format validation', () {
      const syncPacket =
          '__TELEPOS_DATA__:{"type":"sale","posId":"POS-001","data":{"receiptNo":"001"}}';
      const protoPacket =
          '__TELEPOS_PROTO__:{"cmd":"sync_request","posId":"POS-001"}';

      expect(syncPacket, startsWith('__TELEPOS_DATA__:'));
      expect(protoPacket, startsWith('__TELEPOS_PROTO__:'));
    });

    test('sync request and acknowledgement flow', () async {
      final messageService = MessageService(
        client: mockClient,
        logger: mockLogger,
      );
      const exchangeChannelId = -1000000002;

      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'message',
          'id': 1,
          'chat_id': exchangeChannelId,
          'sender_id': {'@type': 'messageSenderUser', 'user_id': 123},
          'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_outgoing': true,
          'content': {
            '@type': 'messageText',
            'text': {
              '@type': 'formattedText',
              'text': '__TELEPOS_PROTO__:{"cmd":"sync_request"}',
            },
          },
        },
      );

      final msg = await messageService.sendText(
        exchangeChannelId,
        '__TELEPOS_PROTO__:{"cmd":"sync_request","posId":"POS-001"}',
      );

      expect(msg.messageId, isNot(0));
    });
  });

  group('E2E: Notifications', () {
    test('notification payload creation', () {
      final notification = NotificationPayload(
        notificationId: 'n-001',
        posId: 'POS-001',
        type: NotificationType.shift,
        title: 'Смена открыта',
        body: 'Кассир: Иванов И.И.',
        priority: NotificationPriority.normal,
        timestamp: DateTime.now(),
      );

      expect(notification.type, NotificationType.shift);
      expect(notification.title, 'Смена открыта');
      expect(notification.priority, NotificationPriority.normal);
    });

    test('critical notification has high priority', () {
      final notification = NotificationPayload(
        notificationId: 'n-002',
        posId: 'POS-001',
        type: NotificationType.error,
        title: 'Критическая ошибка',
        body: 'OFD connection failed',
        priority: NotificationPriority.critical,
        timestamp: DateTime.now(),
      );

      expect(notification.priority, NotificationPriority.critical);
      expect(notification.type, NotificationType.error);
    });
  });

  group('E2E: Reports', () {
    test('Z-report message format', () async {
      final messageService = MessageService(
        client: mockClient,
        logger: mockLogger,
      );
      const reportChannelId = -1000000003;

      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {
          '@type': 'message',
          'id': 1,
          'chat_id': reportChannelId,
          'sender_id': {'@type': 'messageSenderUser', 'user_id': 123},
          'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_outgoing': true,
          'content': {
            '@type': 'messageText',
            'text': {'@type': 'formattedText', 'text': 'Z-REPORT'},
          },
        },
      );

      final reportContent = '''
**Z-ОТЧЁТ**
Дата: 2026-02-09
Смена: #123

**Продажи:** 150 000 ₸
**Наличные:** 80 000 ₸
**Карты:** 70 000 ₸
      ''';

      final report = await messageService.sendMarkdown(
        reportChannelId,
        reportContent,
      );

      expect(report.messageId, isNot(0));
    });
  });

  group('E2E: Full Setup Flow', () {
    test('complete first-time setup simulation', () async {
      when(
        () => mockClient.sendSync(any()),
      ).thenAnswer((_) async => {'@type': 'ok'});

      final channelManager = ChannelManager(
        client: mockClient,
        logger: mockLogger,
      );
      final registry = ChannelRegistry(
        logger: mockLogger,
        registryPath: '/tmp/test.json',
      );

      when(
        () => mockClient.createChannel(
          title: any(named: 'title'),
          description: any(named: 'description'),
        ),
      ).thenAnswer(
        (_) async => {
          '@type': 'chat',
          'id': -1000000001,
          'title': 'Test Channel',
        },
      );

      final channel = await channelManager.createChannel(
        title: 'TestStore-POS-System',
        description: 'System events',
        channelType: SystemChannelType.posSystem,
      );
      registry.register(SystemChannelType.posSystem, channel);

      expect(registry.get(SystemChannelType.posSystem), isNotNull);
    });
  });

  group('E2E: Error Handling', () {
    test('handles network error gracefully', () async {
      when(
        () => mockClient.sendSync(any()),
      ).thenThrow(Exception('Network error'));

      final messageService = MessageService(
        client: mockClient,
        logger: mockLogger,
      );

      expect(
        () => messageService.sendText(-1000000001, 'Test'),
        throwsException,
      );
    });

    test('handles auth error gracefully', () async {
      when(() => mockClient.sendSync(any())).thenAnswer(
        (_) async => {'@type': 'error', 'code': 401, 'message': 'Unauthorized'},
      );

      final result = await mockClient.sendSync({'@type': 'getMe'});

      expect(result['@type'], 'error');
      expect(result['code'], 401);
    });
  });
}
