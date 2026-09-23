import 'dart:async';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/platform/local_file.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talker/talker.dart';

import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../presentation/common/help/help_button.dart';
import '../../../presentation/controllers/app/current_user_provider.dart';
import '../../../telegram/internal_chat/staff_chat_service.dart';
import '../../../telegram/internal_chat/staff_identity_service.dart';
import '../../../domain/entities/telegram/telegram_message.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/staff_role_label.dart';

final _telegramLinkStatusProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return false;

  if (GetIt.I.isRegistered<StaffIdentityService>()) {
    final identityService = GetIt.I<StaffIdentityService>();
    return identityService.isUserLinked(user.id);
  }
  return false;
});

final _staffMembersProvider = FutureProvider<List<StaffMember>>((ref) async {
  if (GetIt.I.isRegistered<StaffIdentityService>()) {
    final identityService = GetIt.I<StaffIdentityService>();
    return identityService.getAllStaffMembers();
  }
  return [];
});

class StaffChatScreen extends ConsumerStatefulWidget {
  const StaffChatScreen({super.key});

  @override
  ConsumerState<StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends ConsumerState<StaffChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _logger = GetIt.I.isRegistered<Talker>() ? GetIt.I<Talker>() : null;

  StaffChatService? _chatService;
  StaffIdentityService? _identityService;

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isConnected = false;
  bool _showLinkDialog = false;

  _ChatMessage? _replyingTo;

  StreamSubscription<TelegramMessage>? _messageSubscription;

  User? _currentUser;
  int? _currentUserTelegramId;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    if (GetIt.I.isRegistered<StaffChatService>()) {
      _chatService = GetIt.I<StaffChatService>();
    }
    if (GetIt.I.isRegistered<StaffIdentityService>()) {
      _identityService = GetIt.I<StaffIdentityService>();
    }

    setState(() {
      _isConnected = _chatService?.isConfigured ?? false;
    });

    await _loadCurrentUser();

    await _checkTelegramLink();

    await _loadMessages();

    _subscribeToMessages();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null) {
        _currentUser = user;
        _currentUserTelegramId = _currentUser?.telegramId;
        _logger?.debug('Current user loaded: ${user.name} (id=${user.id})');
      } else {
        _logger?.warning('No authorized user in AppState');
      }
    } catch (e) {
      _logger?.error('Failed to load current user: $e');
    }
  }

  Future<void> _checkTelegramLink() async {
    if (_currentUser == null || _identityService == null) return;

    final isLinked = await _identityService!.isUserLinked(_currentUser!.id);
    if (!isLinked && mounted) {
      setState(() => _showLinkDialog = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_showLinkDialog && mounted) {
          _showTelegramLinkDialog();
        }
      });
    }
  }

  void _subscribeToMessages() {
    if (_chatService == null || !_chatService!.isConfigured) return;

    _messageSubscription = _chatService!.messages.listen(
      (message) {
        if (mounted) {
          _addIncomingMessage(message);
        }
      },
      onError: (e) {
        _logger?.error('Message stream error: $e');
      },
    );
  }

  void _addIncomingMessage(TelegramMessage telegramMessage) async {
    if (telegramMessage.isSystemMessage) return;

    final isMe = telegramMessage.senderId == _currentUserTelegramId;

    String senderName = 'Unknown';
    if (_identityService != null) {
      final staff = await _identityService!.findUserByTelegramId(
        telegramMessage.senderId,
      );
      if (staff != null) {
        senderName = staff.name;
      }
    }

    final chatMessage = _ChatMessage(
      id: telegramMessage.messageId,
      text: telegramMessage.text,
      senderId: telegramMessage.senderId,
      senderName: senderName,
      timestamp: telegramMessage.date,
      isMe: isMe,
      isSent: true,
      isRead: telegramMessage.isRead,
    );

    if (mounted) {
      setState(() {
        if (!_messages.any((m) => m.id == chatMessage.id)) {
          _messages.add(chatMessage);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffAsync = ref.watch(_staffMembersProvider);
    final participantCount = staffAsync.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.chatTitle),
            Text(
              AppLocalizations.of(context)!.chatParticipants(participantCount),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          const HelpButton(screenId: 'staff_chat'),
          IconButton(
            icon: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            onPressed: _reconnect,
            tooltip: _isConnected
                ? AppLocalizations.of(context)!.chatConnected
                : AppLocalizations.of(context)!.chatDisconnected,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'search',
                child: ListTile(
                  leading: const Icon(Icons.search),
                  title: Text(AppLocalizations.of(context)!.chatSearch),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'participants',
                child: ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(AppLocalizations.of(context)!.chatMembers),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'link_telegram',
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(AppLocalizations.of(context)!.chatLinkTelegram),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(AppLocalizations.of(context)!.navSettings),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.chatNoConnectionBanner,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _reconnect,
                    child: Text(AppLocalizations.of(context)!.printerConnect),
                  ),
                ],
              ),
            ),

          if (_currentUser?.telegramId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade100,
              child: Row(
                children: [
                  const Icon(TeleposIcons.info, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.chatLinkTelegramForId,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _showTelegramLinkDialog,
                    child: Text(AppLocalizations.of(context)!.chatLinkTelegram),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState(theme)
                : _buildMessagesList(theme),
          ),

          if (_replyingTo != null) _buildReplyIndicator(theme),

          _buildMessageInput(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.chatNoMessages,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.chatStartConversation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: _messages.length,
      reverse: true,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final previousMessage = index < _messages.length - 1
            ? _messages[_messages.length - 2 - index]
            : null;

        final showDateSeparator =
            previousMessage == null ||
            !_isSameDay(message.timestamp, previousMessage.timestamp);

        final showSenderInfo =
            previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            message.timestamp.difference(previousMessage.timestamp).inMinutes >
                5;

        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(theme, message.timestamp),
            _buildMessageBubble(theme, message, showSenderInfo),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(ThemeData theme, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ThemeData theme,
    _ChatMessage message,
    bool showSenderInfo,
  ) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSenderInfo) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: _getAvatarColor(message.senderId),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSenderInfo && !isMe) ...[
                      Text(
                        message.senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _getAvatarColor(message.senderId),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.replyTo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyTo!.senderName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              message.replyTo!.text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isMe
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isSent
                                ? (message.isRead ? Icons.done_all : Icons.done)
                                : Icons.schedule,
                            size: 14,
                            color: message.isRead
                                ? Colors.lightBlueAccent
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyingTo!.senderName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _replyingTo!.text,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(TeleposIcons.close),
            onPressed: () {
              setState(() => _replyingTo = null);
            },
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _attachFile,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.chatMessageHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: theme.colorScheme.primary),
                    onPressed: _sendMessage,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      if (_chatService != null && _chatService!.isConfigured) {
        final telegramMessages = await _chatService!.getHistory(limit: 50);

        final chatMessages = <_ChatMessage>[];
        for (final msg in telegramMessages) {
          if (msg.isSystemMessage) continue;

          final isMe = msg.senderId == _currentUserTelegramId;

          String senderName = 'Unknown';
          if (_identityService != null) {
            final staff = await _identityService!.findUserByTelegramId(
              msg.senderId,
            );
            if (staff != null) {
              senderName = staff.name;
            }
          }

          chatMessages.add(
            _ChatMessage(
              id: msg.messageId,
              text: msg.text,
              senderId: msg.senderId,
              senderName: senderName,
              timestamp: msg.date,
              isMe: isMe,
              isSent: true,
              isRead: msg.isRead,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(chatMessages);
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      _logger?.error('Failed to load messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final newMessage = _ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      text: text,
      senderId: _currentUserTelegramId ?? 1,
      senderName: _currentUser?.name ?? AppLocalizations.of(context)!.chatMe,
      timestamp: DateTime.now(),
      isMe: true,
      isSent: false,
      isRead: false,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
      _replyingTo = null;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      if (_identityService != null && _currentUser != null) {
        final success = await _identityService!.sendAsUser(
          userId: _currentUser!.id,
          message: text,
        );

        if (success && mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == newMessage.id);
            if (index != -1) {
              _messages[index] = newMessage.copyWith(isSent: true);
            }
            _isSending = false;
          });
          return;
        }
      }

      if (_chatService != null && _chatService!.isConfigured) {
        await _chatService!.sendMessage(text);
      }

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == newMessage.id);
          if (index != -1) {
            _messages[index] = newMessage.copyWith(isSent: true);
          }
          _isSending = false;
        });
      }
    } catch (e) {
      _logger?.error('Failed to send message: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.chatSendError(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessageOptions(_ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(AppLocalizations.of(ctx)!.chatReply),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = message);
                _focusNode.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(AppLocalizations.of(ctx)!.chatCopy),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(ctx)!.chatCopied)),
                );
              },
            ),
            if (message.isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(AppLocalizations.of(ctx)!.globalEdit),
                onTap: () {
                  Navigator.pop(ctx);
                  _messageController.text = message.text;
                  _focusNode.requestFocus();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(ctx)!.globalDelete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(_ChatMessage message) async {
    if (_chatService == null || !_chatService!.isConfigured) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatNotConfigured,
        isError: true,
      );
      return;
    }

    if (!message.isMe) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatCanDeleteOwnOnly,
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.chatDeleteMsg),
        content: Text(AppLocalizations.of(ctx)!.chatDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.globalCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(ctx)!.globalDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _chatService!.deleteMessage(message.id);

    if (!mounted) return;

    if (success) {
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
      _showSnackBar(AppLocalizations.of(context)!.chatMessageDeleted);
    } else {
      _showSnackBar(
        AppLocalizations.of(context)!.chatDeleteFailed,
        isError: true,
      );
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'search':
        _showSearchDialog();
        break;
      case 'participants':
        _showParticipantsDialog();
        break;
      case 'link_telegram':
        _showTelegramLinkDialog();
        break;
      case 'settings':
        _showChatSettingsDialog();
        break;
    }
  }

  void _showChatSettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    final isConfigured = _chatService?.isConfigured ?? false;
    final isLinked = _currentUserTelegramId != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.navSettings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isConfigured ? Icons.wifi : Icons.wifi_off,
                color: isConfigured ? Colors.green : Colors.red,
              ),
              title: Text(
                isConfigured ? l10n.chatConnected : l10n.chatDisconnected,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isLinked ? Icons.link : Icons.link_off,
                color: isLinked ? Colors.green : Colors.orange,
              ),
              title: Text(
                isLinked ? l10n.chatLinkTelegram : l10n.chatTelegramNotLinked,
              ),
              subtitle: (_currentUser?.name?.isNotEmpty ?? false)
                  ? Text(_currentUser!.name!)
                  : null,
              trailing: isLinked
                  ? null
                  : TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showTelegramLinkDialog();
                      },
                      child: Text(l10n.chatLinkTelegram),
                    ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people),
              title: Text(l10n.chatMembers),
              onTap: () {
                Navigator.pop(ctx);
                _showParticipantsDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.globalClose),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.chatSearch),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(ctx)!.chatSearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (query) async {
            Navigator.pop(ctx);
            if (query.isNotEmpty) {
              await _searchMessages(query);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (searchController.text.isNotEmpty) {
                await _searchMessages(searchController.text);
              }
            },
            child: Text(AppLocalizations.of(ctx)!.globalSearch),
          ),
        ],
      ),
    );
  }

  Future<void> _searchMessages(String query) async {
    if (_chatService == null || !_chatService!.isConfigured) {
      final found = _messages.where(
        (m) => m.text.toLowerCase().contains(query.toLowerCase()),
      );
      if (found.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.chatFoundMessages(found.length),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.chatNoResults)),
        );
      }
      return;
    }

    try {
      final results = await _chatService!.search(query);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.chatFoundMessages(results.length),
            ),
          ),
        );
      }
    } catch (e) {
      _logger?.error('Search failed: $e');
    }
  }

  void _showParticipantsDialog() {
    final staffAsync = ref.read(_staffMembersProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.chatMembers),
        content: staffAsync.when(
          data: (staff) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final member in staff)
                _buildParticipantTile(
                  member.name,
                  member.isLinked,
                  staffRoleLabel(
                    member.role,
                    AppLocalizations.of(context)!,
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          // Отказ говорится СЛОВАМИ. Здесь стояли два выдуманных участника —
          // «Менеджер Алия» и «Кассир Нурлан» — с признаком «привязан»:
          // экран показывал несуществующих людей как настоящих, и кассир не
          // мог отличить их от живого списка. Своя строка остаётся: про себя
          // экран знает и без загрузки.
          error: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildParticipantTile(
                _currentUser?.name ?? AppLocalizations.of(ctx)!.chatMe,
                _currentUserTelegramId != null,
                '',
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(ctx)!.chatMembersUnavailable,
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.globalClose),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(String name, bool isLinked, String role) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getAvatarColor(name.hashCode),
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(name),
      subtitle: role.isNotEmpty ? Text(role) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLinked)
            Tooltip(
              message: AppLocalizations.of(context)!.chatTelegramNotLinked,
              child: const Icon(Icons.link_off, size: 16, color: Colors.orange),
            ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLinked ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showTelegramLinkDialog() {
    final telegramIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.chatLinkTelegram),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(ctx)!.chatLinkInstructions),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(ctx)!.chatLinkHowTo,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: telegramIdController,
              decoration: const InputDecoration(
                labelText: 'Telegram User ID',
                hintText: '123456789',
                prefixIcon: Icon(Icons.telegram),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.globalCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final telegramId = int.tryParse(telegramIdController.text);
              if (telegramId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(ctx)!.errorInvalidFormat),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _linkTelegramAccount(telegramId);
            },
            child: Text(AppLocalizations.of(ctx)!.chatLinkTelegram),
          ),
        ],
      ),
    );
  }

  Future<void> _linkTelegramAccount(int telegramId) async {
    if (_currentUser == null || _identityService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatServiceUnavailable),
        ),
      );
      return;
    }

    final success = await _identityService!.linkTelegramAccount(
      _currentUser!.id,
      telegramId,
    );

    if (success) {
      setState(() {
        _currentUserTelegramId = telegramId;
        _showLinkDialog = false;
      });

      await _loadCurrentUser();

      ref.invalidate(_telegramLinkStatusProvider);
      ref.invalidate(_staffMembersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatTelegramLinked),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatLinkFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _attachFile() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: Text(AppLocalizations.of(ctx)!.chatPhoto),
              onTap: () {
                Navigator.pop(ctx);
                _attachPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(AppLocalizations.of(ctx)!.chatDocument),
              onTap: () {
                Navigator.pop(ctx);
                _attachDocument();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(AppLocalizations.of(ctx)!.chatLocation),
              onTap: () {
                Navigator.pop(ctx);
                _attachLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachPhoto() async {
    if (_chatService == null || !_chatService!.isConfigured) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatNotConfigured,
        isError: true,
      );
      return;
    }

    if (kIsWeb) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatPhotoUnavailableWeb,
        isError: true,
      );
      return;
    }

    try {
      final picker = ImagePicker();

      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.chatSelectSource),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(ctx)!.chatCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(ctx)!.chatGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null || !mounted) return;

      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null || !mounted) return;

      setState(() => _isSending = true);

      final success = await _chatService!.sendPhoto(image.path);

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        _showSnackBar(AppLocalizations.of(context)!.chatPhotoSent);
      } else {
        _showSnackBar(
          AppLocalizations.of(context)!.chatPhotoFailed,
          isError: true,
        );
      }
    } catch (e) {
      _logger?.error('Failed to attach photo: $e');
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar(
          AppLocalizations.of(context)!.chatPhotoError,
          isError: true,
        );
      }
    }
  }

  Future<void> _attachDocument() async {
    if (_chatService == null || !_chatService!.isConfigured) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatNotConfigured,
        isError: true,
      );
      return;
    }

    if (kIsWeb) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatDocUnavailableWeb,
        isError: true,
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      if (file.path == null) {
        _showSnackBar(
          AppLocalizations.of(context)!.chatDocPathError,
          isError: true,
        );
        return;
      }

      final fileSize = localFileLength(file.path!);
      if (fileSize > 50 * 1024 * 1024) {
        _showSnackBar(
          AppLocalizations.of(context)!.chatDocTooLarge,
          isError: true,
        );
        return;
      }

      setState(() => _isSending = true);

      final success = await _chatService!.sendDocument(file.path!);

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        _showSnackBar(AppLocalizations.of(context)!.chatDocSent);
      } else {
        _showSnackBar(
          AppLocalizations.of(context)!.chatDocFailed,
          isError: true,
        );
      }
    } catch (e) {
      _logger?.error('Failed to attach document: $e');
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar(
          AppLocalizations.of(context)!.chatDocError,
          isError: true,
        );
      }
    }
  }

  Future<void> _attachLocation() async {
    if (_chatService == null || !_chatService!.isConfigured) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatNotConfigured,
        isError: true,
      );
      return;
    }

    if (kIsWeb) {
      _showSnackBar(
        AppLocalizations.of(context)!.chatLocationUnavailableWeb,
        isError: true,
      );
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showSnackBar(
              AppLocalizations.of(context)!.chatLocationDenied,
              isError: true,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
            AppLocalizations.of(context)!.chatLocationDeniedForever,
            isError: true,
          );
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnackBar(
            AppLocalizations.of(context)!.chatLocationServiceDisabled,
            isError: true,
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isSending = true);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      final success = await _chatService!.sendLocation(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        _showSnackBar(AppLocalizations.of(context)!.chatLocationSent);
      } else {
        _showSnackBar(
          AppLocalizations.of(context)!.chatLocationFailed,
          isError: true,
        );
      }
    } catch (e) {
      _logger?.error('Failed to get location: $e');
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar(
          AppLocalizations.of(context)!.chatLocationError,
          isError: true,
        );
      }
    }
  }

  void _reconnect() async {
    if (_chatService != null) {
      setState(() => _isConnected = _chatService!.isConfigured);

      if (_isConnected) {
        await _loadMessages();
        _subscribeToMessages();
      }
    } else {
      setState(() => _isConnected = !_isConnected);
    }

    if (_isConnected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.chatConnected)),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return AppLocalizations.of(context)!.historyToday;
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return AppLocalizations.of(context)!.historyYesterday;
    } else {
      return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getAvatarColor(int id) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[id.abs() % colors.length];
  }
}

class _ChatMessage {
  final int id;
  final String text;
  final int senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isSent;
  final bool isRead;
  final _ChatMessage? replyTo;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    this.isSent = false,
    this.isRead = false,
    this.replyTo,
  });

  _ChatMessage copyWith({
    int? id,
    String? text,
    int? senderId,
    String? senderName,
    DateTime? timestamp,
    bool? isMe,
    bool? isSent,
    bool? isRead,
    _ChatMessage? replyTo,
  }) {
    return _ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      isSent: isSent ?? this.isSent,
      isRead: isRead ?? this.isRead,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}
