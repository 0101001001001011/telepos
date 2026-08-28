import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/internal_chat/staff_chat_service.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class MockMessageService extends Mock implements MessageService {}

class MockRealtimeUpdates extends Mock implements RealtimeUpdates {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

void main() {
  late StaffChatService staffChatService;
  late MockMessageService mockMessageService;
  late MockRealtimeUpdates mockRealtimeUpdates;
  late MockTdLibLogger mockLogger;

  setUp(() {
    mockMessageService = MockMessageService();
    mockRealtimeUpdates = MockRealtimeUpdates();
    mockLogger = MockTdLibLogger();

    staffChatService = StaffChatService(
      messageService: mockMessageService,
      realtimeUpdates: mockRealtimeUpdates,
      logger: mockLogger,
    );
  });

  TelegramMessage createTestMessage({
    int messageId = 12345,
    int chatId = 100,
    int senderId = 200,
    MessageDirection direction = MessageDirection.outgoing,
    MessageContentType contentType = MessageContentType.text,
    String text = 'Test message',
    DateTime? date,
    int? replyToMessageId,
  }) {
    return TelegramMessage(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      direction: direction,
      contentType: contentType,
      text: text,
      date: date ?? DateTime.now(),
      replyToMessageId: replyToMessageId,
    );
  }

  group('StaffChatService', () {
    group('configuration', () {
      test('isConfigured returns false initially', () {
        expect(staffChatService.isConfigured, isFalse);
      });

      test('isConfigured returns true after configure() is called', () {
        staffChatService.configure(123456);

        expect(staffChatService.isConfigured, isTrue);
      });

      test('configure() sets the staff chat ID', () {
        const chatId = 123456;

        staffChatService.configure(chatId);

        expect(staffChatService.isConfigured, isTrue);
      });

      test('configure() logs the connection event', () {
        const chatId = 123456;

        staffChatService.configure(chatId);

        verify(
          () => mockLogger.logConnection('Staff chat configured: $chatId'),
        ).called(1);
      });

      test('configure() can be called multiple times to reconfigure', () {
        staffChatService.configure(111);
        expect(staffChatService.isConfigured, isTrue);

        staffChatService.configure(222);
        expect(staffChatService.isConfigured, isTrue);

        verify(() => mockLogger.logConnection(any())).called(2);
      });
    });

    group('sendMessage()', () {
      test('throws StateError when not configured', () {
        expect(
          () => staffChatService.sendMessage('Hello'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Staff chat not configured. Call configure() first.',
            ),
          ),
        );
      });

      test('sends message through MessageService when configured', () async {
        const chatId = 123456;
        const text = 'Hello staff!';
        final expectedMessage = createTestMessage(chatId: chatId, text: text);

        when(
          () => mockMessageService.sendText(chatId, text),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.sendMessage(text);

        verify(() => mockMessageService.sendText(chatId, text)).called(1);
        expect(result.chatId, chatId);
        expect(result.text, text);
      });

      test('returns TelegramMessage on successful send', () async {
        const chatId = 123456;
        const text = 'Staff message';
        final expectedMessage = createTestMessage(
          messageId: 789,
          chatId: chatId,
          text: text,
          direction: MessageDirection.outgoing,
        );

        when(
          () => mockMessageService.sendText(chatId, text),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.sendMessage(text);

        expect(result.messageId, 789);
        expect(result.direction, MessageDirection.outgoing);
      });

      test('handles empty text message', () async {
        const chatId = 123456;
        const text = '';
        final expectedMessage = createTestMessage(chatId: chatId, text: text);

        when(
          () => mockMessageService.sendText(chatId, text),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.sendMessage(text);

        expect(result.text, '');
      });

      test('handles unicode text correctly', () async {
        const chatId = 123456;
        const text = 'Привет команда! 你好 🎉';
        final expectedMessage = createTestMessage(chatId: chatId, text: text);

        when(
          () => mockMessageService.sendText(chatId, text),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.sendMessage(text);

        expect(result.text, text);
      });

      test('propagates MessageService exceptions', () async {
        const chatId = 123456;
        const text = 'Test';

        when(
          () => mockMessageService.sendText(chatId, text),
        ).thenThrow(Exception('Network error'));

        staffChatService.configure(chatId);

        expect(
          () => staffChatService.sendMessage(text),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('replyTo()', () {
      test('throws StateError when not configured', () {
        expect(
          () => staffChatService.replyTo(123, 'Reply text'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Staff chat not configured. Call configure() first.',
            ),
          ),
        );
      });

      test('sends reply through MessageService when configured', () async {
        const chatId = 123456;
        const messageId = 789;
        const text = 'This is a reply';
        final expectedMessage = createTestMessage(
          chatId: chatId,
          text: text,
          replyToMessageId: messageId,
        );

        when(
          () => mockMessageService.sendReply(chatId, messageId, text),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.replyTo(messageId, text);

        verify(
          () => mockMessageService.sendReply(chatId, messageId, text),
        ).called(1);
        expect(result.replyToMessageId, messageId);
        expect(result.text, text);
      });

      test('returns TelegramMessage with replyToMessageId set', () async {
        const chatId = 123456;
        const originalMessageId = 100;
        const replyText = 'Reply content';
        final expectedMessage = createTestMessage(
          messageId: 101,
          chatId: chatId,
          text: replyText,
          replyToMessageId: originalMessageId,
        );

        when(
          () => mockMessageService.sendReply(
            chatId,
            originalMessageId,
            replyText,
          ),
        ).thenAnswer((_) async => expectedMessage);

        staffChatService.configure(chatId);
        final result = await staffChatService.replyTo(
          originalMessageId,
          replyText,
        );

        expect(result.messageId, 101);
        expect(result.replyToMessageId, originalMessageId);
      });
    });

    group('getHistory()', () {
      test('throws StateError when not configured', () {
        expect(() => staffChatService.getHistory(), throwsA(isA<StateError>()));
      });

      test(
        'gets history through MessageService with default parameters',
        () async {
          const chatId = 123456;
          final expectedMessages = [
            createTestMessage(messageId: 1, text: 'First'),
            createTestMessage(messageId: 2, text: 'Second'),
          ];

          when(
            () => mockMessageService.getHistory(
              chatId,
              limit: 50,
              fromMessageId: 0,
            ),
          ).thenAnswer((_) async => expectedMessages);

          staffChatService.configure(chatId);
          final result = await staffChatService.getHistory();

          verify(
            () => mockMessageService.getHistory(
              chatId,
              limit: 50,
              fromMessageId: 0,
            ),
          ).called(1);
          expect(result.length, 2);
        },
      );

      test('gets history with custom limit', () async {
        const chatId = 123456;
        const limit = 100;
        final expectedMessages = <TelegramMessage>[];

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: limit,
            fromMessageId: 0,
          ),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        await staffChatService.getHistory(limit: limit);

        verify(
          () => mockMessageService.getHistory(
            chatId,
            limit: limit,
            fromMessageId: 0,
          ),
        ).called(1);
      });

      test('gets history with custom fromMessageId', () async {
        const chatId = 123456;
        const fromMessageId = 500;
        final expectedMessages = <TelegramMessage>[];

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: 50,
            fromMessageId: fromMessageId,
          ),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        await staffChatService.getHistory(fromMessageId: fromMessageId);

        verify(
          () => mockMessageService.getHistory(
            chatId,
            limit: 50,
            fromMessageId: fromMessageId,
          ),
        ).called(1);
      });

      test('gets history with both custom parameters', () async {
        const chatId = 123456;
        const limit = 25;
        const fromMessageId = 1000;
        final expectedMessages = <TelegramMessage>[];

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: limit,
            fromMessageId: fromMessageId,
          ),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        await staffChatService.getHistory(
          limit: limit,
          fromMessageId: fromMessageId,
        );

        verify(
          () => mockMessageService.getHistory(
            chatId,
            limit: limit,
            fromMessageId: fromMessageId,
          ),
        ).called(1);
      });

      test('returns empty list when no messages', () async {
        const chatId = 123456;

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: any(named: 'limit'),
            fromMessageId: any(named: 'fromMessageId'),
          ),
        ).thenAnswer((_) async => <TelegramMessage>[]);

        staffChatService.configure(chatId);
        final result = await staffChatService.getHistory();

        expect(result, isEmpty);
      });

      test('returns messages in correct order', () async {
        const chatId = 123456;
        final expectedMessages = [
          createTestMessage(messageId: 3, text: 'Third'),
          createTestMessage(messageId: 2, text: 'Second'),
          createTestMessage(messageId: 1, text: 'First'),
        ];

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: any(named: 'limit'),
            fromMessageId: any(named: 'fromMessageId'),
          ),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        final result = await staffChatService.getHistory();

        expect(result.length, 3);
        expect(result[0].messageId, 3);
        expect(result[1].messageId, 2);
        expect(result[2].messageId, 1);
      });
    });

    group('messages stream', () {
      test('throws StateError when not configured', () {
        expect(() => staffChatService.messages, throwsA(isA<StateError>()));
      });

      test('returns filtered stream for configured chat', () async {
        const chatId = 123456;
        final messageController = StreamController<TelegramMessage>.broadcast();

        when(
          () => mockRealtimeUpdates.messagesForChat(chatId),
        ).thenAnswer((_) => messageController.stream);

        staffChatService.configure(chatId);
        final stream = staffChatService.messages;

        expect(stream, isA<Stream<TelegramMessage>>());
        verify(() => mockRealtimeUpdates.messagesForChat(chatId)).called(1);

        await messageController.close();
      });

      test('stream emits messages from the configured chat', () async {
        const chatId = 123456;
        final messageController = StreamController<TelegramMessage>.broadcast();
        final testMessage = createTestMessage(
          chatId: chatId,
          text: 'New message',
        );

        when(
          () => mockRealtimeUpdates.messagesForChat(chatId),
        ).thenAnswer((_) => messageController.stream);

        staffChatService.configure(chatId);

        final messages = <TelegramMessage>[];
        final subscription = staffChatService.messages.listen(messages.add);

        messageController.add(testMessage);
        await Future.delayed(Duration.zero);

        expect(messages.length, 1);
        expect(messages[0].text, 'New message');

        await subscription.cancel();
        await messageController.close();
      });

      test('stream emits multiple messages in sequence', () async {
        const chatId = 123456;
        final messageController = StreamController<TelegramMessage>.broadcast();

        when(
          () => mockRealtimeUpdates.messagesForChat(chatId),
        ).thenAnswer((_) => messageController.stream);

        staffChatService.configure(chatId);

        final messages = <TelegramMessage>[];
        final subscription = staffChatService.messages.listen(messages.add);

        messageController.add(createTestMessage(messageId: 1, text: 'First'));
        messageController.add(createTestMessage(messageId: 2, text: 'Second'));
        messageController.add(createTestMessage(messageId: 3, text: 'Third'));
        await Future.delayed(Duration.zero);

        expect(messages.length, 3);
        expect(messages[0].text, 'First');
        expect(messages[1].text, 'Second');
        expect(messages[2].text, 'Third');

        await subscription.cancel();
        await messageController.close();
      });
    });

    group('search()', () {
      test('throws StateError when not configured', () {
        expect(
          () => staffChatService.search('query'),
          throwsA(isA<StateError>()),
        );
      });

      test('searches messages through MessageService', () async {
        const chatId = 123456;
        const query = 'search term';
        final expectedMessages = [
          createTestMessage(text: 'Contains search term'),
        ];

        when(
          () => mockMessageService.searchMessages(chatId, query),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        final result = await staffChatService.search(query);

        verify(
          () => mockMessageService.searchMessages(chatId, query),
        ).called(1);
        expect(result.length, 1);
        expect(result[0].text, contains('search term'));
      });

      test('returns empty list when no matches', () async {
        const chatId = 123456;
        const query = 'nonexistent';

        when(
          () => mockMessageService.searchMessages(chatId, query),
        ).thenAnswer((_) async => <TelegramMessage>[]);

        staffChatService.configure(chatId);
        final result = await staffChatService.search(query);

        expect(result, isEmpty);
      });

      test('handles empty query string', () async {
        const chatId = 123456;
        const query = '';

        when(
          () => mockMessageService.searchMessages(chatId, query),
        ).thenAnswer((_) async => <TelegramMessage>[]);

        staffChatService.configure(chatId);
        await staffChatService.search(query);

        verify(
          () => mockMessageService.searchMessages(chatId, query),
        ).called(1);
      });

      test('handles unicode query correctly', () async {
        const chatId = 123456;
        const query = 'Привет';
        final expectedMessages = [createTestMessage(text: 'Привет мир')];

        when(
          () => mockMessageService.searchMessages(chatId, query),
        ).thenAnswer((_) async => expectedMessages);

        staffChatService.configure(chatId);
        final result = await staffChatService.search(query);

        expect(result.length, 1);
      });
    });

    group('markAsRead()', () {
      test('throws StateError when not configured', () {
        expect(
          () => staffChatService.markAsRead(123),
          throwsA(isA<StateError>()),
        );
      });

      test('marks messages as read through MessageService', () async {
        const chatId = 123456;
        const upToMessageId = 789;

        when(
          () => mockMessageService.markAsRead(chatId, upToMessageId),
        ).thenAnswer((_) async {});

        staffChatService.configure(chatId);
        await staffChatService.markAsRead(upToMessageId);

        verify(
          () => mockMessageService.markAsRead(chatId, upToMessageId),
        ).called(1);
      });

      test('completes successfully when marking as read', () async {
        const chatId = 123456;
        const upToMessageId = 999;

        when(
          () => mockMessageService.markAsRead(chatId, upToMessageId),
        ).thenAnswer((_) async {});

        staffChatService.configure(chatId);

        await expectLater(
          staffChatService.markAsRead(upToMessageId),
          completes,
        );
      });
    });

    group('error handling', () {
      test('sendMessage propagates exceptions from MessageService', () async {
        const chatId = 123456;
        const errorMessage = 'Failed to send message';

        when(
          () => mockMessageService.sendText(chatId, any()),
        ).thenThrow(Exception(errorMessage));

        staffChatService.configure(chatId);

        expect(
          () => staffChatService.sendMessage('Test'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'toString',
              contains(errorMessage),
            ),
          ),
        );
      });

      test('replyTo propagates exceptions from MessageService', () async {
        const chatId = 123456;

        when(
          () => mockMessageService.sendReply(chatId, any(), any()),
        ).thenThrow(Exception('Reply failed'));

        staffChatService.configure(chatId);

        expect(
          () => staffChatService.replyTo(100, 'Reply'),
          throwsA(isA<Exception>()),
        );
      });

      test('getHistory propagates exceptions from MessageService', () async {
        const chatId = 123456;

        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: any(named: 'limit'),
            fromMessageId: any(named: 'fromMessageId'),
          ),
        ).thenThrow(Exception('History fetch failed'));

        staffChatService.configure(chatId);

        expect(() => staffChatService.getHistory(), throwsA(isA<Exception>()));
      });

      test('search propagates exceptions from MessageService', () async {
        const chatId = 123456;

        when(
          () => mockMessageService.searchMessages(chatId, any()),
        ).thenThrow(Exception('Search failed'));

        staffChatService.configure(chatId);

        expect(
          () => staffChatService.search('query'),
          throwsA(isA<Exception>()),
        );
      });

      test('markAsRead propagates exceptions from MessageService', () async {
        const chatId = 123456;

        when(
          () => mockMessageService.markAsRead(chatId, any()),
        ).thenThrow(Exception('Mark as read failed'));

        staffChatService.configure(chatId);

        expect(
          () => staffChatService.markAsRead(100),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('_ensureConfigured validation', () {
      test('all methods throw StateError before configuration', () {
        expect(() => staffChatService.sendMessage('text'), throwsStateError);
        expect(() => staffChatService.replyTo(1, 'text'), throwsStateError);
        expect(() => staffChatService.getHistory(), throwsStateError);
        expect(() => staffChatService.messages, throwsStateError);
        expect(() => staffChatService.search('query'), throwsStateError);
        expect(() => staffChatService.markAsRead(1), throwsStateError);
      });

      test('StateError has meaningful message', () {
        expect(
          () => staffChatService.sendMessage('text'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not configured'),
            ),
          ),
        );
      });

      test('methods work after configuration', () async {
        const chatId = 123456;
        final testMessage = createTestMessage();
        final messageController = StreamController<TelegramMessage>.broadcast();

        when(
          () => mockMessageService.sendText(chatId, any()),
        ).thenAnswer((_) async => testMessage);
        when(
          () => mockMessageService.sendReply(chatId, any(), any()),
        ).thenAnswer((_) async => testMessage);
        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: any(named: 'limit'),
            fromMessageId: any(named: 'fromMessageId'),
          ),
        ).thenAnswer((_) async => <TelegramMessage>[]);
        when(
          () => mockRealtimeUpdates.messagesForChat(chatId),
        ).thenAnswer((_) => messageController.stream);
        when(
          () => mockMessageService.searchMessages(chatId, any()),
        ).thenAnswer((_) async => <TelegramMessage>[]);
        when(
          () => mockMessageService.markAsRead(chatId, any()),
        ).thenAnswer((_) async {});

        staffChatService.configure(chatId);

        await expectLater(staffChatService.sendMessage('text'), completes);
        await expectLater(staffChatService.replyTo(1, 'text'), completes);
        await expectLater(staffChatService.getHistory(), completes);
        expect(() => staffChatService.messages, returnsNormally);
        await expectLater(staffChatService.search('query'), completes);
        await expectLater(staffChatService.markAsRead(1), completes);

        await messageController.close();
      });
    });

    group('integration scenarios', () {
      test('configure, send message, then get history', () async {
        const chatId = 123456;
        final sentMessage = createTestMessage(
          messageId: 100,
          chatId: chatId,
          text: 'Sent message',
        );
        final historyMessages = [
          sentMessage,
          createTestMessage(messageId: 99, text: 'Previous message'),
        ];

        when(
          () => mockMessageService.sendText(chatId, 'Sent message'),
        ).thenAnswer((_) async => sentMessage);
        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: any(named: 'limit'),
            fromMessageId: any(named: 'fromMessageId'),
          ),
        ).thenAnswer((_) async => historyMessages);

        staffChatService.configure(chatId);

        final sent = await staffChatService.sendMessage('Sent message');
        expect(sent.messageId, 100);

        final history = await staffChatService.getHistory();
        expect(history.length, 2);
        expect(history[0].messageId, 100);
      });

      test('reply to message and mark as read', () async {
        const chatId = 123456;
        const originalMessageId = 50;
        final replyMessage = createTestMessage(
          messageId: 51,
          chatId: chatId,
          text: 'Reply',
          replyToMessageId: originalMessageId,
        );

        when(
          () =>
              mockMessageService.sendReply(chatId, originalMessageId, 'Reply'),
        ).thenAnswer((_) async => replyMessage);
        when(
          () => mockMessageService.markAsRead(chatId, 51),
        ).thenAnswer((_) async {});

        staffChatService.configure(chatId);

        final reply = await staffChatService.replyTo(
          originalMessageId,
          'Reply',
        );
        expect(reply.replyToMessageId, originalMessageId);

        await staffChatService.markAsRead(reply.messageId);
        verify(() => mockMessageService.markAsRead(chatId, 51)).called(1);
      });

      test('search and then reply to found message', () async {
        const chatId = 123456;
        const query = 'important';
        final foundMessages = [
          createTestMessage(messageId: 200, text: 'This is important'),
        ];
        final replyMessage = createTestMessage(
          messageId: 201,
          text: 'I agree',
          replyToMessageId: 200,
        );

        when(
          () => mockMessageService.searchMessages(chatId, query),
        ).thenAnswer((_) async => foundMessages);
        when(
          () => mockMessageService.sendReply(chatId, 200, 'I agree'),
        ).thenAnswer((_) async => replyMessage);

        staffChatService.configure(chatId);

        final results = await staffChatService.search(query);
        expect(results.length, 1);

        final reply = await staffChatService.replyTo(
          results[0].messageId,
          'I agree',
        );
        expect(reply.replyToMessageId, 200);
      });

      test('realtime message stream with multiple subscribers', () async {
        const chatId = 123456;
        final messageController = StreamController<TelegramMessage>.broadcast();

        when(
          () => mockRealtimeUpdates.messagesForChat(chatId),
        ).thenAnswer((_) => messageController.stream);

        staffChatService.configure(chatId);

        final subscriber1Messages = <TelegramMessage>[];
        final subscriber2Messages = <TelegramMessage>[];

        final sub1 = staffChatService.messages.listen(subscriber1Messages.add);
        final sub2 = staffChatService.messages.listen(subscriber2Messages.add);

        final testMessage = createTestMessage(text: 'Broadcast message');
        messageController.add(testMessage);
        await Future.delayed(Duration.zero);

        expect(subscriber1Messages.length, 1);
        expect(subscriber2Messages.length, 1);
        expect(subscriber1Messages[0].text, 'Broadcast message');
        expect(subscriber2Messages[0].text, 'Broadcast message');

        await sub1.cancel();
        await sub2.cancel();
        await messageController.close();
      });

      test('reconfigure to different chat', () async {
        const chatId1 = 111;
        const chatId2 = 222;
        final message1 = createTestMessage(chatId: chatId1, text: 'Chat 1');
        final message2 = createTestMessage(chatId: chatId2, text: 'Chat 2');

        when(
          () => mockMessageService.sendText(chatId1, any()),
        ).thenAnswer((_) async => message1);
        when(
          () => mockMessageService.sendText(chatId2, any()),
        ).thenAnswer((_) async => message2);

        staffChatService.configure(chatId1);
        final result1 = await staffChatService.sendMessage('Test');
        expect(result1.chatId, chatId1);

        staffChatService.configure(chatId2);
        final result2 = await staffChatService.sendMessage('Test');
        expect(result2.chatId, chatId2);

        verify(() => mockMessageService.sendText(chatId1, 'Test')).called(1);
        verify(() => mockMessageService.sendText(chatId2, 'Test')).called(1);
      });

      test('pagination through history', () async {
        const chatId = 123456;
        final page1 = [
          createTestMessage(messageId: 100, text: 'Message 100'),
          createTestMessage(messageId: 99, text: 'Message 99'),
        ];
        final page2 = [
          createTestMessage(messageId: 98, text: 'Message 98'),
          createTestMessage(messageId: 97, text: 'Message 97'),
        ];

        when(
          () =>
              mockMessageService.getHistory(chatId, limit: 2, fromMessageId: 0),
        ).thenAnswer((_) async => page1);
        when(
          () => mockMessageService.getHistory(
            chatId,
            limit: 2,
            fromMessageId: 99,
          ),
        ).thenAnswer((_) async => page2);

        staffChatService.configure(chatId);

        final firstPage = await staffChatService.getHistory(limit: 2);
        expect(firstPage.length, 2);
        expect(firstPage[0].messageId, 100);

        final lastId = firstPage.last.messageId;
        final secondPage = await staffChatService.getHistory(
          limit: 2,
          fromMessageId: lastId,
        );
        expect(secondPage.length, 2);
        expect(secondPage[0].messageId, 98);
      });
    });
  });
}
