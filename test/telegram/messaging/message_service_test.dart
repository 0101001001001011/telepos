import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';

class MockTdLibClient extends Mock implements TdLibClient {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

void main() {
  late MessageService messageService;
  late MockTdLibClient mockClient;
  late MockTdLibLogger mockLogger;

  setUp(() {
    mockClient = MockTdLibClient();
    mockLogger = MockTdLibLogger();
    messageService = MessageService(client: mockClient, logger: mockLogger);
  });

  Map<String, dynamic> createMessageResponse({
    int id = 12345,
    int chatId = 100,
    int senderId = 200,
    bool isOutgoing = true,
    String contentType = 'messageText',
    String text = 'Test message',
    int date = 1700000000,
    int? editDate,
    int? replyToMessageId,
  }) {
    return {
      '@type': 'message',
      'id': id,
      'chat_id': chatId,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': senderId},
      'is_outgoing': isOutgoing,
      'content': {
        '@type': contentType,
        'text': {'@type': 'formattedText', 'text': text},
      },
      'date': date,
      if (editDate != null) 'edit_date': editDate,
      if (replyToMessageId != null)
        'reply_to': {
          '@type': 'messageReplyToMessage',
          'message_id': replyToMessageId,
        },
    };
  }

  group('MessageService', () {
    group('sendText()', () {
      test('sends text message with correct TDLib request structure', () async {
        const chatId = 123456;
        const text = 'Hello, World!';
        final response = createMessageResponse(chatId: chatId, text: text);

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(chatId, text);

        verify(
          () => mockClient.sendSync({
            '@type': 'sendMessage',
            'chat_id': chatId,
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': text},
            },
          }),
        ).called(1);

        expect(result.chatId, chatId);
        expect(result.text, text);
      });

      test(
        'returns TelegramMessage with correct direction for outgoing',
        () async {
          final response = createMessageResponse(isOutgoing: true);
          when(
            () => mockClient.sendSync(any()),
          ).thenAnswer((_) async => response);

          final result = await messageService.sendText(100, 'Test');

          expect(result.direction, MessageDirection.outgoing);
        },
      );

      test('parses message date correctly', () async {
        const timestamp = 1700000000;
        final response = createMessageResponse(date: timestamp);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'Test');

        expect(
          result.date,
          DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
        );
      });

      test('handles empty text message', () async {
        final response = createMessageResponse(text: '');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, '');

        expect(result.text, '');
      });

      test('handles unicode text correctly', () async {
        const unicodeText = 'Привет мир! 你好世界! 🎉';
        final response = createMessageResponse(text: unicodeText);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, unicodeText);

        expect(result.text, unicodeText);
      });
    });

    group('sendMarkdown()', () {
      test('parses markdown before sending', () async {
        const chatId = 123456;
        const markdown = '**bold** _italic_';
        final parseResult = {
          '@type': 'formattedText',
          'text': 'bold italic',
          'entities': [
            {'@type': 'textEntityTypeBold', 'offset': 0, 'length': 4},
            {'@type': 'textEntityTypeItalic', 'offset': 5, 'length': 6},
          ],
        };
        final messageResponse = createMessageResponse(text: 'bold italic');

        var callCount = 0;
        when(() => mockClient.sendSync(any())).thenAnswer((invocation) async {
          callCount++;
          if (callCount == 1) {
            return parseResult;
          } else {
            return messageResponse;
          }
        });

        await messageService.sendMarkdown(chatId, markdown);

        verify(
          () => mockClient.sendSync({
            '@type': 'parseMarkdown',
            'text': {'@type': 'formattedText', 'text': markdown},
          }),
        ).called(1);
      });

      test('sends parsed markdown result as message content', () async {
        const chatId = 123456;
        const markdown = '**bold**';
        final parseResult = {
          '@type': 'formattedText',
          'text': 'bold',
          'entities': [
            {'@type': 'textEntityTypeBold', 'offset': 0, 'length': 4},
          ],
        };
        final messageResponse = createMessageResponse(text: 'bold');

        var callCount = 0;
        when(() => mockClient.sendSync(any())).thenAnswer((invocation) async {
          callCount++;
          if (callCount == 1) {
            return parseResult;
          } else {
            return messageResponse;
          }
        });

        await messageService.sendMarkdown(chatId, markdown);

        verify(
          () => mockClient.sendSync({
            '@type': 'sendMessage',
            'chat_id': chatId,
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': parseResult,
            },
          }),
        ).called(1);
      });

      test('returns correctly parsed TelegramMessage', () async {
        const chatId = 123456;
        final parseResult = {
          '@type': 'formattedText',
          'text': 'formatted text',
        };
        final messageResponse = createMessageResponse(
          chatId: chatId,
          text: 'formatted text',
        );

        var callCount = 0;
        when(() => mockClient.sendSync(any())).thenAnswer((invocation) async {
          callCount++;
          return callCount == 1 ? parseResult : messageResponse;
        });

        final result = await messageService.sendMarkdown(
          chatId,
          '**formatted text**',
        );

        expect(result.chatId, chatId);
        expect(result.text, 'formatted text');
      });
    });

    group('sendSilent()', () {
      test('sends message with disable_notification option', () async {
        const chatId = 123456;
        const text = 'Silent message';
        final response = createMessageResponse(chatId: chatId, text: text);

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.sendSilent(chatId, text);

        verify(
          () => mockClient.sendSync({
            '@type': 'sendMessage',
            'chat_id': chatId,
            'options': {
              '@type': 'messageSendOptions',
              'disable_notification': true,
            },
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': text},
            },
          }),
        ).called(1);
      });

      test('returns TelegramMessage on success', () async {
        const chatId = 123456;
        const text = 'Silent notification';
        final response = createMessageResponse(chatId: chatId, text: text);

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendSilent(chatId, text);

        expect(result.chatId, chatId);
        expect(result.text, text);
        expect(result.direction, MessageDirection.outgoing);
      });
    });

    group('sendReply()', () {
      test('sends message with reply_to field', () async {
        const chatId = 123456;
        const replyToMessageId = 789;
        const text = 'This is a reply';
        final response = createMessageResponse(
          chatId: chatId,
          text: text,
          replyToMessageId: replyToMessageId,
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.sendReply(chatId, replyToMessageId, text);

        verify(
          () => mockClient.sendSync({
            '@type': 'sendMessage',
            'chat_id': chatId,
            'reply_to': {
              '@type': 'inputMessageReplyToMessage',
              'message_id': replyToMessageId,
            },
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': text},
            },
          }),
        ).called(1);
      });

      test('returns TelegramMessage with replyToMessageId set', () async {
        const chatId = 123456;
        const replyToMessageId = 789;
        const text = 'Reply text';
        final response = createMessageResponse(
          chatId: chatId,
          text: text,
          replyToMessageId: replyToMessageId,
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendReply(
          chatId,
          replyToMessageId,
          text,
        );

        expect(result.replyToMessageId, replyToMessageId);
        expect(result.text, text);
      });
    });

    group('editMessage()', () {
      test('sends editMessageText request with correct structure', () async {
        const chatId = 123456;
        const messageId = 789;
        const newText = 'Updated message';

        when(() => mockClient.send(any())).thenAnswer((_) async {});

        await messageService.editMessage(chatId, messageId, newText);

        verify(
          () => mockClient.send({
            '@type': 'editMessageText',
            'chat_id': chatId,
            'message_id': messageId,
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': newText},
            },
          }),
        ).called(1);
      });

      test('uses async send (no response wait)', () async {
        const chatId = 123456;
        const messageId = 789;
        const newText = 'Edited content';

        when(() => mockClient.send(any())).thenAnswer((_) async {});

        await messageService.editMessage(chatId, messageId, newText);

        verify(() => mockClient.send(any())).called(1);
        verifyNever(() => mockClient.sendSync(any()));
      });
    });

    group('deleteMessage()', () {
      test('sends deleteMessages request with revoke=true', () async {
        const chatId = 123456;
        const messageId = 789;

        when(() => mockClient.send(any())).thenAnswer((_) async {});

        await messageService.deleteMessage(chatId, messageId);

        verify(
          () => mockClient.send({
            '@type': 'deleteMessages',
            'chat_id': chatId,
            'message_ids': [messageId],
            'revoke': true,
          }),
        ).called(1);
      });

      test('sends message_ids as list with single ID', () async {
        const chatId = 123456;
        const messageId = 999;

        when(() => mockClient.send(any())).thenAnswer((_) async {});

        await messageService.deleteMessage(chatId, messageId);

        final captured = verify(() => mockClient.send(captureAny())).captured;
        final request = captured.first as Map<String, dynamic>;

        expect(request['message_ids'], isA<List>());
        expect(request['message_ids'], contains(messageId));
        expect((request['message_ids'] as List).length, 1);
      });
    });

    group('getHistory()', () {
      test('sends getChatHistory request with default parameters', () async {
        const chatId = 123456;
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
          'total_count': 0,
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.getHistory(chatId);

        verify(
          () => mockClient.sendSync({
            '@type': 'getChatHistory',
            'chat_id': chatId,
            'from_message_id': 0,
            'offset': 0,
            'limit': 50,
            'only_local': false,
          }),
        ).called(1);
      });

      test('sends getChatHistory with custom limit', () async {
        const chatId = 123456;
        const limit = 100;
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.getHistory(chatId, limit: limit);

        verify(
          () => mockClient.sendSync({
            '@type': 'getChatHistory',
            'chat_id': chatId,
            'from_message_id': 0,
            'offset': 0,
            'limit': limit,
            'only_local': false,
          }),
        ).called(1);
      });

      test('sends getChatHistory with custom fromMessageId', () async {
        const chatId = 123456;
        const fromMessageId = 500;
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.getHistory(chatId, fromMessageId: fromMessageId);

        verify(
          () => mockClient.sendSync({
            '@type': 'getChatHistory',
            'chat_id': chatId,
            'from_message_id': fromMessageId,
            'offset': 0,
            'limit': 50,
            'only_local': false,
          }),
        ).called(1);
      });

      test('returns empty list when messages is null', () async {
        const chatId = 123456;
        final response = {'@type': 'messages', 'messages': null};

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.getHistory(chatId);

        expect(result, isEmpty);
      });

      test('returns empty list when messages key is missing', () async {
        const chatId = 123456;
        final response = {'@type': 'messages'};

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.getHistory(chatId);

        expect(result, isEmpty);
      });

      test('parses multiple messages correctly', () async {
        const chatId = 123456;
        final response = {
          '@type': 'messages',
          'messages': [
            createMessageResponse(id: 1, text: 'First'),
            createMessageResponse(id: 2, text: 'Second'),
            createMessageResponse(id: 3, text: 'Third'),
          ],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.getHistory(chatId);

        expect(result.length, 3);
        expect(result[0].messageId, 1);
        expect(result[0].text, 'First');
        expect(result[1].messageId, 2);
        expect(result[1].text, 'Second');
        expect(result[2].messageId, 3);
        expect(result[2].text, 'Third');
      });

      test('parses messages with different content types', () async {
        const chatId = 123456;
        final response = {
          '@type': 'messages',
          'messages': [
            createMessageResponse(id: 1, contentType: 'messageText'),
            createMessageResponse(id: 2, contentType: 'messagePhoto'),
            createMessageResponse(id: 3, contentType: 'messageDocument'),
          ],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.getHistory(chatId);

        expect(result[0].contentType, MessageContentType.text);
        expect(result[1].contentType, MessageContentType.photo);
        expect(result[2].contentType, MessageContentType.document);
      });
    });

    group('searchMessages()', () {
      test('sends searchChatMessages request with query', () async {
        const chatId = 123456;
        const query = 'search term';
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.searchMessages(chatId, query);

        verify(
          () => mockClient.sendSync({
            '@type': 'searchChatMessages',
            'chat_id': chatId,
            'query': query,
            'from_message_id': 0,
            'offset': 0,
            'limit': 20,
            'filter': null,
            'message_thread_id': 0,
          }),
        ).called(1);
      });

      test('sends searchChatMessages with custom limit', () async {
        const chatId = 123456;
        const query = 'test';
        const limit = 50;
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        await messageService.searchMessages(chatId, query, limit: limit);

        final captured = verify(
          () => mockClient.sendSync(captureAny()),
        ).captured;
        final request = captured.first as Map<String, dynamic>;

        expect(request['limit'], limit);
      });

      test('returns empty list when no messages found', () async {
        const chatId = 123456;
        final response = {
          '@type': 'messages',
          'messages': <Map<String, dynamic>>[],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.searchMessages(
          chatId,
          'nonexistent',
        );

        expect(result, isEmpty);
      });

      test('returns matching messages', () async {
        const chatId = 123456;
        const query = 'hello';
        final response = {
          '@type': 'messages',
          'messages': [
            createMessageResponse(id: 1, text: 'hello world'),
            createMessageResponse(id: 2, text: 'say hello'),
          ],
        };

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.searchMessages(chatId, query);

        expect(result.length, 2);
        expect(result[0].text, contains('hello'));
        expect(result[1].text, contains('hello'));
      });
    });

    group('_parseMessage() behavior (via public methods)', () {
      test('parses messageId correctly', () async {
        const expectedId = 999999;
        final response = createMessageResponse(id: expectedId);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.messageId, expectedId);
      });

      test('parses chatId correctly', () async {
        const expectedChatId = 888888;
        final response = createMessageResponse(chatId: expectedChatId);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(expectedChatId, 'test');

        expect(result.chatId, expectedChatId);
      });

      test('parses senderId correctly', () async {
        const expectedSenderId = 777777;
        final response = createMessageResponse(senderId: expectedSenderId);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.senderId, expectedSenderId);
      });

      test('parses incoming message direction', () async {
        final response = createMessageResponse(isOutgoing: false);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.direction, MessageDirection.incoming);
      });

      test('parses outgoing message direction', () async {
        final response = createMessageResponse(isOutgoing: true);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.direction, MessageDirection.outgoing);
      });

      test('parses editDate when present', () async {
        const editTimestamp = 1700001000;
        final response = createMessageResponse(editDate: editTimestamp);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(
          result.editDate,
          DateTime.fromMillisecondsSinceEpoch(editTimestamp * 1000),
        );
      });

      test('editDate is null when not present', () async {
        final response = createMessageResponse();
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.editDate, isNull);
      });

      test('editDate is null when edit_date is 0', () async {
        final response = createMessageResponse();
        response['edit_date'] = 0;
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.editDate, isNull);
      });

      test('handles missing sender_id gracefully', () async {
        final response = createMessageResponse();
        response.remove('sender_id');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.senderId, 0);
      });

      test('handles missing content gracefully', () async {
        final response = createMessageResponse();
        response.remove('content');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.text, '');
        expect(result.contentType, MessageContentType.text);
      });

      test('maps messagePhoto content type', () async {
        final response = createMessageResponse(contentType: 'messagePhoto');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.photo);
      });

      test('maps messageDocument content type', () async {
        final response = createMessageResponse(contentType: 'messageDocument');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.document);
      });

      test('maps messageVideo content type', () async {
        final response = createMessageResponse(contentType: 'messageVideo');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.video);
      });

      test('maps messageAudio content type', () async {
        final response = createMessageResponse(contentType: 'messageAudio');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.audio);
      });

      test('maps messageSticker content type', () async {
        final response = createMessageResponse(contentType: 'messageSticker');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.sticker);
      });

      test('maps messageAnimation content type', () async {
        final response = createMessageResponse(contentType: 'messageAnimation');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.animation);
      });

      test('maps messageLocation content type', () async {
        final response = createMessageResponse(contentType: 'messageLocation');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.location);
      });

      test('maps messageContact content type', () async {
        final response = createMessageResponse(contentType: 'messageContact');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.contact);
      });

      test('maps unknown content type to text', () async {
        final response = createMessageResponse(
          contentType: 'messageUnknownType',
        );
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.contentType, MessageContentType.text);
      });

      test('handles missing id with default 0', () async {
        final response = createMessageResponse();
        response.remove('id');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.messageId, 0);
      });

      test('handles missing chat_id with default 0', () async {
        final response = createMessageResponse();
        response.remove('chat_id');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.chatId, 0);
      });

      test('handles missing date with epoch', () async {
        final response = createMessageResponse();
        response.remove('date');
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.date, DateTime.fromMillisecondsSinceEpoch(0));
      });

      test('parses replyToMessageId from reply_to structure', () async {
        const replyId = 54321;
        final response = createMessageResponse(replyToMessageId: replyId);
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => response);

        final result = await messageService.sendText(100, 'test');

        expect(result.replyToMessageId, replyId);
      });
    });

    group('markAsRead()', () {
      test('sends viewMessages request correctly', () async {
        const chatId = 123456;
        const upToMessageId = 789;

        when(() => mockClient.send(any())).thenAnswer((_) async {});

        await messageService.markAsRead(chatId, upToMessageId);

        verify(
          () => mockClient.send({
            '@type': 'viewMessages',
            'chat_id': chatId,
            'message_ids': [upToMessageId],
            'force_read': true,
          }),
        ).called(1);
      });
    });

    group('error handling', () {
      test('propagates client exceptions on sendText', () async {
        when(
          () => mockClient.sendSync(any()),
        ).thenThrow(TdLibException(code: 400, message: 'Bad Request'));

        expect(
          () => messageService.sendText(100, 'test'),
          throwsA(isA<TdLibException>()),
        );
      });

      test('propagates client exceptions on getHistory', () async {
        when(
          () => mockClient.sendSync(any()),
        ).thenThrow(TdLibException(code: 401, message: 'Unauthorized'));

        expect(
          () => messageService.getHistory(100),
          throwsA(isA<TdLibException>()),
        );
      });

      test('propagates client exceptions on searchMessages', () async {
        when(
          () => mockClient.sendSync(any()),
        ).thenThrow(TdLibException(code: 404, message: 'Chat not found'));

        expect(
          () => messageService.searchMessages(100, 'query'),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('integration scenarios', () {
      test('send and then edit message flow', () async {
        const chatId = 123456;
        const originalText = 'Original';
        const editedText = 'Edited';

        final sendResponse = createMessageResponse(
          id: 789,
          chatId: chatId,
          text: originalText,
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => sendResponse);
        when(() => mockClient.send(any())).thenAnswer((_) async {});

        final sentMessage = await messageService.sendText(chatId, originalText);
        expect(sentMessage.messageId, 789);

        await messageService.editMessage(
          chatId,
          sentMessage.messageId,
          editedText,
        );

        verify(
          () => mockClient.send({
            '@type': 'editMessageText',
            'chat_id': chatId,
            'message_id': 789,
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': editedText},
            },
          }),
        ).called(1);
      });

      test('send reply to existing message', () async {
        const chatId = 123456;
        const originalMessageId = 100;
        const replyText = 'This is my reply';

        final replyResponse = createMessageResponse(
          id: 101,
          chatId: chatId,
          text: replyText,
          replyToMessageId: originalMessageId,
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => replyResponse);

        final reply = await messageService.sendReply(
          chatId,
          originalMessageId,
          replyText,
        );

        expect(reply.replyToMessageId, originalMessageId);
        expect(reply.text, replyText);
      });

      test('get history with pagination', () async {
        const chatId = 123456;

        final firstPageResponse = {
          '@type': 'messages',
          'messages': [
            createMessageResponse(id: 50, text: 'Message 50'),
            createMessageResponse(id: 49, text: 'Message 49'),
          ],
        };

        final secondPageResponse = {
          '@type': 'messages',
          'messages': [
            createMessageResponse(id: 48, text: 'Message 48'),
            createMessageResponse(id: 47, text: 'Message 47'),
          ],
        };

        var callCount = 0;
        when(() => mockClient.sendSync(any())).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? firstPageResponse : secondPageResponse;
        });

        final firstPage = await messageService.getHistory(chatId, limit: 2);
        expect(firstPage.length, 2);
        expect(firstPage.first.messageId, 50);

        final lastMessageId = firstPage.last.messageId;
        final secondPage = await messageService.getHistory(
          chatId,
          limit: 2,
          fromMessageId: lastMessageId,
        );
        expect(secondPage.length, 2);
        expect(secondPage.first.messageId, 48);
      });
    });
  });
}
