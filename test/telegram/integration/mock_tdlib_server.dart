import 'dart:async';

import 'package:telepos/telegram/channels/channel_types.dart';

class MockTdLibServer {
  final Map<int, Map<String, dynamic>> _chats = {};
  final Map<int, List<Map<String, dynamic>>> _messages = {};
  final List<Map<String, dynamic>> _sentRequests = [];

  int _nextChatId = -1000000000;
  int _nextMessageId = 1;
  final int _currentUserId = 123456789;

  String _authState = 'authorizationStateWaitPhoneNumber';
  bool _isAuthorized = false;

  final _updateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  List<Map<String, dynamic>> get sentRequests =>
      List.unmodifiable(_sentRequests);

  bool get isAuthorized => _isAuthorized;

  int get currentUserId => _currentUserId;

  Future<Map<String, dynamic>> processRequest(
    Map<String, dynamic> request,
  ) async {
    _sentRequests.add(request);

    final type = request['@type'] as String?;
    if (type == null) {
      return _error('Request type is null');
    }

    switch (type) {
      case 'getAuthorizationState':
        return {'@type': _authState};

      case 'setAuthenticationPhoneNumber':
        _authState = 'authorizationStateWaitCode';
        _emitUpdate({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': _authState},
        });
        return {'@type': 'ok'};

      case 'checkAuthenticationCode':
        _authState = 'authorizationStateReady';
        _isAuthorized = true;
        _emitUpdate({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': _authState},
        });
        return {'@type': 'ok'};

      case 'checkAuthenticationPassword':
        _authState = 'authorizationStateReady';
        _isAuthorized = true;
        _emitUpdate({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': _authState},
        });
        return {'@type': 'ok'};

      case 'registerUser':
        _authState = 'authorizationStateReady';
        _isAuthorized = true;
        _emitUpdate({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': _authState},
        });
        return {'@type': 'ok'};

      case 'logOut':
        _authState = 'authorizationStateWaitPhoneNumber';
        _isAuthorized = false;
        return {'@type': 'ok'};

      case 'getMe':
        return {
          '@type': 'user',
          'id': _currentUserId,
          'first_name': 'Test',
          'last_name': 'User',
          'phone_number': '+77001234567',
        };

      case 'createNewSupergroupChat':
        final chatId = _nextChatId--;
        final title = request['title'] as String? ?? 'Untitled';
        final isChannel = request['is_channel'] as bool? ?? true;

        final chat = {
          '@type': 'chat',
          'id': chatId,
          'title': title,
          'type': {
            '@type': isChannel ? 'chatTypeSupergroup' : 'chatTypeBasicGroup',
            'supergroup_id': -chatId,
            'is_channel': isChannel,
          },
        };
        _chats[chatId] = chat;
        _messages[chatId] = [];

        _emitUpdate({'@type': 'updateNewChat', 'chat': chat});
        return chat;

      case 'leaveChat':
        return {'@type': 'ok'};

      case 'deleteSupergroup':
        final supergroupId = request['supergroup_id'] as int?;
        if (supergroupId != null) {
          _chats.remove(-supergroupId);
          _messages.remove(-supergroupId);
        }
        return {'@type': 'ok'};

      case 'getChat':
        final chatId = request['chat_id'] as int?;
        return _chats[chatId] ?? _error('Chat not found');

      case 'addChatMember':
      case 'addChatMembers':
      case 'setChatMemberStatus':
        return {'@type': 'ok'};

      case 'setChatTitle':
      case 'setChatDescription':
        return {'@type': 'ok'};

      case 'createChatInviteLink':
        return {
          '@type': 'chatInviteLink',
          'invite_link':
              'https://t.me/+mock_invite_link_${DateTime.now().millisecondsSinceEpoch}',
          'name': request['name'] ?? '',
        };

      case 'sendMessage':
        final chatId = request['chat_id'] as int? ?? 0;
        final messageId = _nextMessageId++;

        final message = {
          '@type': 'message',
          'id': messageId,
          'chat_id': chatId,
          'sender_id': {
            '@type': 'messageSenderUser',
            'user_id': _currentUserId,
          },
          'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'is_outgoing': true,
          'content': request['input_message_content'],
        };

        _messages.putIfAbsent(chatId, () => []).add(message);
        _emitUpdate({'@type': 'updateNewMessage', 'message': message});

        return message;

      case 'editMessageText':
        return {'@type': 'ok'};

      case 'deleteMessages':
        return {'@type': 'ok'};

      case 'getChatHistory':
        final chatId = request['chat_id'] as int? ?? 0;
        final limit = request['limit'] as int? ?? 50;
        final messages = _messages[chatId] ?? [];

        return {
          '@type': 'messages',
          'messages': messages.take(limit).toList(),
          'total_count': messages.length,
        };

      case 'searchChatMessages':
        final chatId = request['chat_id'] as int? ?? 0;
        final query = request['query'] as String? ?? '';
        final messages = _messages[chatId] ?? [];

        final results = messages.where((m) {
          final content = m['content'] as Map<String, dynamic>?;
          final text = content?['text']?['text'] as String? ?? '';
          return text.toLowerCase().contains(query.toLowerCase());
        }).toList();

        return {
          '@type': 'messages',
          'messages': results,
          'total_count': results.length,
        };

      case 'viewMessages':
        return {'@type': 'ok'};

      case 'downloadFile':
        return {
          '@type': 'file',
          'id': request['file_id'] ?? 1,
          'local': {
            'path': '/mock/path/to/file',
            'is_downloading_completed': true,
          },
        };

      case 'createNewSecretChat':
        final chatId = _nextChatId--;
        return {
          '@type': 'chat',
          'id': chatId,
          'type': {'@type': 'chatTypeSecret', 'secret_chat_id': -chatId},
        };

      case 'parseMarkdown':
      case 'parseTextEntities':
        return {
          '@type': 'formattedText',
          'text': request['text']?['text'] ?? '',
          'entities': [],
        };

      default:
        return {'@type': 'ok'};
    }
  }

  void simulateIncomingMessage({
    required int chatId,
    required int senderId,
    required String text,
  }) {
    final messageId = _nextMessageId++;

    final message = {
      '@type': 'message',
      'id': messageId,
      'chat_id': chatId,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': senderId},
      'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'is_outgoing': false,
      'content': {
        '@type': 'messageText',
        'text': {'@type': 'formattedText', 'text': text},
      },
    };

    _messages.putIfAbsent(chatId, () => []).add(message);
    _emitUpdate({'@type': 'updateNewMessage', 'message': message});
  }

  void simulateAuthStateChange(String newState) {
    _authState = newState;
    _isAuthorized = newState == 'authorizationStateReady';
    _emitUpdate({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': _authState},
    });
  }

  int createMockChannel(String title, SystemChannelType type) {
    final chatId = _nextChatId--;
    _chats[chatId] = {
      '@type': 'chat',
      'id': chatId,
      'title': title,
      'type': {
        '@type': 'chatTypeSupergroup',
        'supergroup_id': -chatId,
        'is_channel': true,
      },
    };
    _messages[chatId] = [];
    return chatId;
  }

  void reset() {
    _chats.clear();
    _messages.clear();
    _sentRequests.clear();
    _nextChatId = -1000000000;
    _nextMessageId = 1;
    _authState = 'authorizationStateWaitPhoneNumber';
    _isAuthorized = false;
  }

  Future<void> dispose() async {
    await _updateController.close();
  }

  void _emitUpdate(Map<String, dynamic> update) {
    if (!_updateController.isClosed) {
      _updateController.add(update);
    }
  }

  Map<String, dynamic> _error(String message) {
    return {'@type': 'error', 'code': 400, 'message': message};
  }
}
