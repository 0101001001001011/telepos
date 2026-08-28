import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class ChatPermissions {
  final TdLibClient _client;
  final TdLibLogger _logger;

  ChatPermissions({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<void> setCashierPermissions(int chatId, int userId) async {
    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {
        '@type': 'chatMemberStatusRestricted',
        'is_member': true,
        'restricted_until_date': 0,
        'permissions': {
          '@type': 'chatPermissions',
          'can_send_basic_messages': true,
          'can_send_audios': false,
          'can_send_documents': true,
          'can_send_photos': true,
          'can_send_videos': false,
          'can_send_video_notes': false,
          'can_send_voice_notes': true,
          'can_send_polls': false,
          'can_send_other_messages': false,
          'can_add_web_page_previews': false,
          'can_change_info': false,
          'can_invite_users': false,
          'can_pin_messages': false,
          'can_manage_topics': false,
        },
      },
    });
    _logger.logConnection('Cashier permissions set for user $userId');
  }

  Future<void> setManagerPermissions(int chatId, int userId) async {
    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {
        '@type': 'chatMemberStatusAdministrator',
        'custom_title': 'Manager',
        'can_be_edited': true,
        'rights': {
          '@type': 'chatAdministratorRights',
          'can_manage_chat': true,
          'can_post_messages': true,
          'can_edit_messages': true,
          'can_delete_messages': true,
          'can_invite_users': true,
          'can_restrict_members': true,
          'can_pin_messages': true,
          'can_promote_members': false,
          'can_manage_video_chats': false,
          'is_anonymous': false,
        },
      },
    });
    _logger.logConnection('Manager permissions set for user $userId');
  }

  Future<void> setReadOnlyPermissions(int chatId, int userId) async {
    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {
        '@type': 'chatMemberStatusRestricted',
        'is_member': true,
        'restricted_until_date': 0,
        'permissions': {
          '@type': 'chatPermissions',
          'can_send_basic_messages': false,
          'can_send_audios': false,
          'can_send_documents': false,
          'can_send_photos': false,
          'can_send_videos': false,
          'can_send_video_notes': false,
          'can_send_voice_notes': false,
          'can_send_polls': false,
          'can_send_other_messages': false,
          'can_add_web_page_previews': false,
          'can_change_info': false,
          'can_invite_users': false,
          'can_pin_messages': false,
          'can_manage_topics': false,
        },
      },
    });
    _logger.logConnection('Read-only permissions set for user $userId');
  }

  Future<void> banUser(int chatId, int userId) async {
    await _client.send({
      '@type': 'setChatMemberStatus',
      'chat_id': chatId,
      'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
      'status': {'@type': 'chatMemberStatusBanned', 'banned_until_date': 0},
    });
    _logger.logConnection('User $userId banned from chat $chatId');
  }
}
