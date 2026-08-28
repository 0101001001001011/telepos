import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/models/telegram_channel.dart';

class MockTdLibClient extends Mock implements TdLibClient {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

void main() {
  late MockTdLibClient mockClient;
  late MockTdLibLogger mockLogger;
  late ChannelManager channelManager;

  setUp(() {
    mockClient = MockTdLibClient();
    mockLogger = MockTdLibLogger();
    channelManager = ChannelManager(client: mockClient, logger: mockLogger);

    when(() => mockLogger.logConnection(any())).thenReturn(null);
  });

  group('ChannelManager', () {
    group('createChannel', () {
      test('creates a private channel successfully', () async {
        const title = 'TestStore-POS-Sales';
        const description = 'Real-time sales feed';
        const channelType = SystemChannelType.posSales;
        const storeName = 'TestStore';
        const posId = 'POS-001';
        const expectedChatId = 123456789;

        when(
          () =>
              mockClient.createChannel(title: title, description: description),
        ).thenAnswer(
          (_) async => {'@type': 'chat', 'id': expectedChatId, 'title': title},
        );

        final result = await channelManager.createChannel(
          title: title,
          description: description,
          channelType: channelType,
          storeName: storeName,
          posId: posId,
        );

        expect(result, isA<TelegramChannel>());
        expect(result.chatId, expectedChatId);
        expect(result.title, title);
        expect(result.channelType, channelType);
        expect(result.description, description);
        expect(result.isChannel, isTrue);
        expect(result.isPrivate, isTrue);
        expect(result.storeName, storeName);
        expect(result.posId, posId);
        expect(result.createdAt, isNotNull);

        verify(
          () =>
              mockClient.createChannel(title: title, description: description),
        ).called(1);
        verify(
          () => mockLogger.logConnection('Creating channel: $title'),
        ).called(1);
        verify(
          () => mockLogger.logConnection(
            'Channel created: $title (id=$expectedChatId)',
          ),
        ).called(1);
      });

      test('creates channel without optional parameters', () async {
        const title = 'TestStore-POS-System';
        const description = 'System events';
        const channelType = SystemChannelType.posSystem;
        const expectedChatId = 987654321;

        when(
          () =>
              mockClient.createChannel(title: title, description: description),
        ).thenAnswer(
          (_) async => {'@type': 'chat', 'id': expectedChatId, 'title': title},
        );

        final result = await channelManager.createChannel(
          title: title,
          description: description,
          channelType: channelType,
        );

        expect(result.chatId, expectedChatId);
        expect(result.storeName, isNull);
        expect(result.posId, isNull);
      });

      test('handles missing id in response gracefully', () async {
        const title = 'TestChannel';
        const description = 'Test description';
        const channelType = SystemChannelType.posAlerts;

        when(
          () =>
              mockClient.createChannel(title: title, description: description),
        ).thenAnswer((_) async => {'@type': 'chat', 'title': title});

        final result = await channelManager.createChannel(
          title: title,
          description: description,
          channelType: channelType,
        );

        expect(result.chatId, 0);
      });

      test('propagates exception from TdLibClient', () async {
        const title = 'FailChannel';
        const description = 'Will fail';
        const channelType = SystemChannelType.posReports;

        when(
          () =>
              mockClient.createChannel(title: title, description: description),
        ).thenThrow(TdLibException(code: 400, message: 'CHANNELS_TOO_MUCH'));

        expect(
          () => channelManager.createChannel(
            title: title,
            description: description,
            channelType: channelType,
          ),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('createGroup', () {
      test('creates a private group (supergroup) successfully', () async {
        const title = 'TestStore-Staff-Chat';
        const description = 'Staff internal chat';
        const channelType = SystemChannelType.staffChat;
        const storeName = 'TestStore';
        const expectedChatId = 111222333;

        when(
          () => mockClient.sendSync({
            '@type': 'createNewSupergroupChat',
            'title': title,
            'is_channel': false,
            'description': description,
            'is_forum': false,
          }),
        ).thenAnswer(
          (_) async => {'@type': 'chat', 'id': expectedChatId, 'title': title},
        );

        final result = await channelManager.createGroup(
          title: title,
          description: description,
          channelType: channelType,
          storeName: storeName,
        );

        expect(result, isA<TelegramChannel>());
        expect(result.chatId, expectedChatId);
        expect(result.title, title);
        expect(result.channelType, channelType);
        expect(result.description, description);
        expect(result.isChannel, isFalse);
        expect(result.isPrivate, isTrue);
        expect(result.storeName, storeName);
        expect(result.createdAt, isNotNull);

        verify(() => mockClient.sendSync(any())).called(1);
        verify(
          () => mockLogger.logConnection('Creating group: $title'),
        ).called(1);
        verify(
          () => mockLogger.logConnection(
            'Group created: $title (id=$expectedChatId)',
          ),
        ).called(1);
      });

      test('creates group without storeName', () async {
        const title = 'Test-Group';
        const description = 'Test group';
        const channelType = SystemChannelType.staffChat;
        const expectedChatId = 444555666;

        when(() => mockClient.sendSync(any())).thenAnswer(
          (_) async => {'@type': 'chat', 'id': expectedChatId, 'title': title},
        );

        final result = await channelManager.createGroup(
          title: title,
          description: description,
          channelType: channelType,
        );

        expect(result.storeName, isNull);
      });

      test('handles missing id in response gracefully', () async {
        const title = 'TestGroup';
        const description = 'Test description';
        const channelType = SystemChannelType.staffChat;

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => {'@type': 'chat', 'title': title});

        final result = await channelManager.createGroup(
          title: title,
          description: description,
          channelType: channelType,
        );

        expect(result.chatId, 0);
      });
    });

    group('addMember', () {
      test('adds a single member to chat successfully', () async {
        const chatId = 123456789;
        const userId = 987654321;

        when(
          () => mockClient.send({
            '@type': 'addChatMember',
            'chat_id': chatId,
            'user_id': userId,
          }),
        ).thenAnswer((_) async {});

        await channelManager.addMember(chatId, userId);

        verify(
          () => mockClient.send({
            '@type': 'addChatMember',
            'chat_id': chatId,
            'user_id': userId,
          }),
        ).called(1);
        verify(
          () => mockLogger.logConnection(
            'Member added: user=$userId to chat=$chatId',
          ),
        ).called(1);
      });

      test('propagates exception when adding member fails', () async {
        const chatId = 123456789;
        const userId = 987654321;

        when(() => mockClient.send(any())).thenThrow(
          TdLibException(code: 400, message: 'USER_NOT_MUTUAL_CONTACT'),
        );

        expect(
          () => channelManager.addMember(chatId, userId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('addMembers', () {
      test('adds multiple members to chat successfully', () async {
        const chatId = 123456789;
        const userIds = [111, 222, 333, 444];

        when(
          () => mockClient.send({
            '@type': 'addChatMembers',
            'chat_id': chatId,
            'user_ids': userIds,
          }),
        ).thenAnswer((_) async {});

        await channelManager.addMembers(chatId, userIds);

        verify(
          () => mockClient.send({
            '@type': 'addChatMembers',
            'chat_id': chatId,
            'user_ids': userIds,
          }),
        ).called(1);
        verify(
          () => mockLogger.logConnection(
            'Members added: ${userIds.length} users to chat=$chatId',
          ),
        ).called(1);
      });

      test('handles empty user list', () async {
        const chatId = 123456789;
        const userIds = <int>[];

        when(
          () => mockClient.send({
            '@type': 'addChatMembers',
            'chat_id': chatId,
            'user_ids': userIds,
          }),
        ).thenAnswer((_) async {});

        await channelManager.addMembers(chatId, userIds);

        verify(
          () => mockClient.send({
            '@type': 'addChatMembers',
            'chat_id': chatId,
            'user_ids': userIds,
          }),
        ).called(1);
      });
    });

    group('removeMember', () {
      test('removes a member from chat successfully', () async {
        const chatId = 123456789;
        const userId = 987654321;

        when(
          () => mockClient.send({
            '@type': 'setChatMemberStatus',
            'chat_id': chatId,
            'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
            'status': {'@type': 'chatMemberStatusLeft'},
          }),
        ).thenAnswer((_) async {});

        await channelManager.removeMember(chatId, userId);

        verify(
          () => mockClient.send({
            '@type': 'setChatMemberStatus',
            'chat_id': chatId,
            'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
            'status': {'@type': 'chatMemberStatusLeft'},
          }),
        ).called(1);
        verify(
          () => mockLogger.logConnection(
            'Member removed: user=$userId from chat=$chatId',
          ),
        ).called(1);
      });

      test('propagates exception when removing member fails', () async {
        const chatId = 123456789;
        const userId = 987654321;

        when(
          () => mockClient.send(any()),
        ).thenThrow(TdLibException(code: 400, message: 'USER_NOT_PARTICIPANT'));

        expect(
          () => channelManager.removeMember(chatId, userId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('createInviteLink', () {
      test('creates invite link successfully', () async {
        const chatId = 123456789;
        const expectedLink = 'https://t.me/+AbCdEfGhIjK';

        when(
          () => mockClient.sendSync({
            '@type': 'createChatInviteLink',
            'chat_id': chatId,
            'name': 'TelePOS invite',
            'expiration_date': 0,
            'member_limit': 0,
            'creates_join_request': false,
          }),
        ).thenAnswer(
          (_) async => {
            '@type': 'chatInviteLink',
            'invite_link': expectedLink,
            'name': 'TelePOS invite',
          },
        );

        final result = await channelManager.createInviteLink(chatId);

        expect(result, expectedLink);
        verify(() => mockClient.sendSync(any())).called(1);
      });

      test('returns empty string when invite_link is null', () async {
        const chatId = 123456789;

        when(() => mockClient.sendSync(any())).thenAnswer(
          (_) async => {'@type': 'chatInviteLink', 'name': 'TelePOS invite'},
        );

        final result = await channelManager.createInviteLink(chatId);

        expect(result, '');
      });

      test('propagates exception when creating invite link fails', () async {
        const chatId = 123456789;

        when(
          () => mockClient.sendSync(any()),
        ).thenThrow(TdLibException(code: 400, message: 'CHAT_ADMIN_REQUIRED'));

        expect(
          () => channelManager.createInviteLink(chatId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('updateDescription', () {
      test('updates channel description successfully', () async {
        const chatId = 123456789;
        const description = 'Updated description for the channel';

        when(
          () => mockClient.send({
            '@type': 'setChatDescription',
            'chat_id': chatId,
            'description': description,
          }),
        ).thenAnswer((_) async {});

        await channelManager.updateDescription(chatId, description);

        verify(
          () => mockClient.send({
            '@type': 'setChatDescription',
            'chat_id': chatId,
            'description': description,
          }),
        ).called(1);
      });

      test('handles empty description', () async {
        const chatId = 123456789;
        const description = '';

        when(
          () => mockClient.send({
            '@type': 'setChatDescription',
            'chat_id': chatId,
            'description': description,
          }),
        ).thenAnswer((_) async {});

        await channelManager.updateDescription(chatId, description);

        verify(
          () => mockClient.send({
            '@type': 'setChatDescription',
            'chat_id': chatId,
            'description': description,
          }),
        ).called(1);
      });

      test('propagates exception when update fails', () async {
        const chatId = 123456789;
        const description = 'New description';

        when(
          () => mockClient.send(any()),
        ).thenThrow(TdLibException(code: 400, message: 'CHAT_ADMIN_REQUIRED'));

        expect(
          () => channelManager.updateDescription(chatId, description),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('updateTitle', () {
      test('updates channel title successfully', () async {
        const chatId = 123456789;
        const title = 'New Channel Title';

        when(
          () => mockClient.send({
            '@type': 'setChatTitle',
            'chat_id': chatId,
            'title': title,
          }),
        ).thenAnswer((_) async {});

        await channelManager.updateTitle(chatId, title);

        verify(
          () => mockClient.send({
            '@type': 'setChatTitle',
            'chat_id': chatId,
            'title': title,
          }),
        ).called(1);
      });

      test('propagates exception when update fails', () async {
        const chatId = 123456789;
        const title = 'New Title';

        when(
          () => mockClient.send(any()),
        ).thenThrow(TdLibException(code: 400, message: 'CHAT_TITLE_EMPTY'));

        expect(
          () => channelManager.updateTitle(chatId, title),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('deleteChannel', () {
      test('deletes channel successfully', () async {
        const chatId = 123456789;

        when(
          () => mockClient.send({
            '@type': 'deleteSupergroup',
            'supergroup_id': chatId,
          }),
        ).thenAnswer((_) async {});

        await channelManager.deleteChannel(chatId);

        verify(
          () => mockLogger.logConnection('Deleting channel: $chatId'),
        ).called(1);
        verify(
          () => mockClient.send({
            '@type': 'deleteSupergroup',
            'supergroup_id': chatId,
          }),
        ).called(1);
      });

      test('propagates exception when deletion fails', () async {
        const chatId = 123456789;

        when(
          () => mockClient.send(any()),
        ).thenThrow(TdLibException(code: 400, message: 'SUPERGROUP_NOT_FOUND'));

        expect(
          () => channelManager.deleteChannel(chatId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('getChatInfo', () {
      test('retrieves chat info successfully', () async {
        const chatId = 123456789;
        final expectedInfo = {
          '@type': 'chat',
          'id': chatId,
          'title': 'Test Channel',
          'type': {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 1000123,
            'is_channel': true,
          },
        };

        when(
          () => mockClient.getChat(chatId),
        ).thenAnswer((_) async => expectedInfo);

        final result = await channelManager.getChatInfo(chatId);

        expect(result, expectedInfo);
        expect(result['id'], chatId);
        expect(result['title'], 'Test Channel');
        verify(() => mockClient.getChat(chatId)).called(1);
      });

      test('propagates exception when retrieval fails', () async {
        const chatId = 123456789;

        when(
          () => mockClient.getChat(chatId),
        ).thenThrow(TdLibException(code: 400, message: 'CHAT_NOT_FOUND'));

        expect(
          () => channelManager.getChatInfo(chatId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('getMemberCount', () {
      test('returns member count from supergroup info', () async {
        const chatId = 123456789;
        const supergroupId = 1000123;
        const expectedMemberCount = 42;

        when(() => mockClient.getChat(chatId)).thenAnswer(
          (_) async => {
            '@type': 'chat',
            'id': chatId,
            'type': {
              '@type': 'chatTypeSupergroup',
              'supergroup_id': supergroupId,
            },
          },
        );

        when(
          () => mockClient.sendSync({
            '@type': 'getSupergroupFullInfo',
            'supergroup_id': supergroupId,
          }),
        ).thenAnswer(
          (_) async => {
            '@type': 'supergroupFullInfo',
            'member_count': expectedMemberCount,
          },
        );

        final result = await channelManager.getMemberCount(chatId);

        expect(result, expectedMemberCount);
        verify(() => mockClient.getChat(chatId)).called(1);
        verify(
          () => mockClient.sendSync({
            '@type': 'getSupergroupFullInfo',
            'supergroup_id': supergroupId,
          }),
        ).called(1);
      });

      test('returns 0 when supergroup_id is null', () async {
        const chatId = 123456789;

        when(() => mockClient.getChat(chatId)).thenAnswer(
          (_) async => {
            '@type': 'chat',
            'id': chatId,
            'type': {'@type': 'chatTypePrivate'},
          },
        );

        final result = await channelManager.getMemberCount(chatId);

        expect(result, 0);
        verify(() => mockClient.getChat(chatId)).called(1);
        verifyNever(() => mockClient.sendSync(any()));
      });

      test('returns 0 when type is null', () async {
        const chatId = 123456789;

        when(
          () => mockClient.getChat(chatId),
        ).thenAnswer((_) async => {'@type': 'chat', 'id': chatId});

        final result = await channelManager.getMemberCount(chatId);

        expect(result, 0);
      });

      test('returns 0 when member_count is null in response', () async {
        const chatId = 123456789;
        const supergroupId = 1000123;

        when(() => mockClient.getChat(chatId)).thenAnswer(
          (_) async => {
            '@type': 'chat',
            'id': chatId,
            'type': {
              '@type': 'chatTypeSupergroup',
              'supergroup_id': supergroupId,
            },
          },
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => {'@type': 'supergroupFullInfo'});

        final result = await channelManager.getMemberCount(chatId);

        expect(result, 0);
      });

      test('propagates exception when getChat fails', () async {
        const chatId = 123456789;

        when(
          () => mockClient.getChat(chatId),
        ).thenThrow(TdLibException(code: 400, message: 'CHAT_NOT_FOUND'));

        expect(
          () => channelManager.getMemberCount(chatId),
          throwsA(isA<TdLibException>()),
        );
      });

      test('propagates exception when getSupergroupFullInfo fails', () async {
        const chatId = 123456789;
        const supergroupId = 1000123;

        when(() => mockClient.getChat(chatId)).thenAnswer(
          (_) async => {
            '@type': 'chat',
            'id': chatId,
            'type': {
              '@type': 'chatTypeSupergroup',
              'supergroup_id': supergroupId,
            },
          },
        );

        when(
          () => mockClient.sendSync(any()),
        ).thenThrow(TdLibException(code: 400, message: 'SUPERGROUP_NOT_FOUND'));

        expect(
          () => channelManager.getMemberCount(chatId),
          throwsA(isA<TdLibException>()),
        );
      });
    });

    group('error handling', () {
      test('TdLibException contains correct code and message', () {
        const code = 400;
        const message = 'CHAT_ADMIN_REQUIRED';
        final exception = TdLibException(code: code, message: message);

        expect(exception.code, code);
        expect(exception.message, message);
        expect(exception.toString(), 'TdLibException($code): $message');
      });

      test('handles StateError from uninitialized client', () async {
        const chatId = 123456789;

        when(
          () => mockClient.getChat(chatId),
        ).thenThrow(StateError('TDLib client is not initialized'));

        expect(
          () => channelManager.getChatInfo(chatId),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('SystemChannelType integration', () {
      test('creates channel for each SystemChannelType', () async {
        for (final channelType in SystemChannelType.values) {
          final title = channelType.formatTitle('TestStore', 'POS-001');
          final description = channelType.description;

          when(
            () => mockClient.createChannel(
              title: title,
              description: description,
            ),
          ).thenAnswer(
            (_) async => {
              '@type': 'chat',
              'id': channelType.index + 1000,
              'title': title,
            },
          );

          when(
            () => mockClient.sendSync({
              '@type': 'createNewSupergroupChat',
              'title': title,
              'is_channel': false,
              'description': description,
              'is_forum': false,
            }),
          ).thenAnswer(
            (_) async => {
              '@type': 'chat',
              'id': channelType.index + 2000,
              'title': title,
            },
          );

          if (channelType.isGroup) {
            final result = await channelManager.createGroup(
              title: title,
              description: description,
              channelType: channelType,
              storeName: 'TestStore',
            );
            expect(result.isChannel, isFalse);
          } else {
            final result = await channelManager.createChannel(
              title: title,
              description: description,
              channelType: channelType,
              storeName: 'TestStore',
            );
            expect(result.isChannel, isTrue);
          }
        }
      });
    });
  });
}
