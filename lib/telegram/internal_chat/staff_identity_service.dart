import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/internal_chat/staff_chat_service.dart';

class StaffIdentityService {
  StaffIdentityService({
    required AppDatabase db,
    required StaffChatService chatService,
    required TdLibLogger logger,
  }) : _db = db,
       _chatService = chatService,
       _logger = logger;

  final AppDatabase _db;
  final StaffChatService _chatService;
  final TdLibLogger _logger;

  final Map<int, int?> _userTelegramCache = {};

  Future<int?> getTelegramIdForUser(int userId) async {
    if (_userTelegramCache.containsKey(userId)) {
      return _userTelegramCache[userId];
    }

    try {
      final user = await _db.userDao.findById(userId);
      final telegramId = user?.telegramId;
      _userTelegramCache[userId] = telegramId;
      return telegramId;
    } catch (e) {
      _logger.logError('getTelegramIdForUser', e);
      return null;
    }
  }

  Future<bool> isUserLinked(int userId) async {
    final telegramId = await getTelegramIdForUser(userId);
    return telegramId != null;
  }

  Future<bool> linkTelegramAccount(int userId, int telegramId) async {
    try {
      final existingUser = await _db.userDao.findByTelegramId(telegramId);
      if (existingUser != null && existingUser.id != userId) {
        _logger.logWarning(
          'Telegram ID $telegramId already linked to user ${existingUser.id}',
        );
        return false;
      }

      await _db.userDao.updateTelegramId(userId, telegramId);
      _userTelegramCache[userId] = telegramId;

      _logger.logConnection('User $userId linked to Telegram $telegramId');
      return true;
    } catch (e) {
      _logger.logError('linkTelegramAccount', e);
      return false;
    }
  }

  Future<bool> unlinkTelegramAccount(int userId) async {
    try {
      await _db.userDao.unlinkTelegram(userId);
      _userTelegramCache.remove(userId);

      _logger.logConnection('User $userId unlinked from Telegram');
      return true;
    } catch (e) {
      _logger.logError('unlinkTelegramAccount', e);
      return false;
    }
  }

  Future<StaffMember?> findUserByTelegramId(int telegramId) async {
    try {
      final user = await _db.userDao.findByTelegramId(telegramId);
      if (user == null) return null;

      return StaffMember(
        userId: user.id,
        name: user.name ?? 'Пользователь #${user.id}',
        role: _roleFromInt(user.role),
        telegramId: telegramId,
      );
    } catch (e) {
      _logger.logError('findUserByTelegramId', e);
      return null;
    }
  }

  Future<bool> sendAsUser({
    required int userId,
    required String message,
  }) async {
    try {
      final user = await _db.userDao.findById(userId);
      if (user == null) {
        _logger.logWarning('User $userId not found');
        return false;
      }

      final formattedMessage = '**${user.name ?? "Пользователь"}:** $message';

      await _chatService.sendMessage(formattedMessage);

      _logger.logConnection('Message sent as user ${user.name}');
      return true;
    } catch (e) {
      _logger.logError('sendAsUser', e);
      return false;
    }
  }

  Future<List<StaffMember>> getAllStaffMembers() async {
    try {
      final users = await _db.userDao.findActiveUsers();

      return users
          .map(
            (user) => StaffMember(
              userId: user.id,
              name: user.name ?? 'Пользователь #${user.id}',
              role: _roleFromInt(user.role),
              telegramId: user.telegramId,
            ),
          )
          .toList();
    } catch (e) {
      _logger.logError('getAllStaffMembers', e);
      return [];
    }
  }

  Future<List<StaffMember>> getUnlinkedStaff() async {
    final all = await getAllStaffMembers();
    return all.where((s) => !s.isLinked).toList();
  }

  void clearCache() {
    _userTelegramCache.clear();
  }

  StaffRole _roleFromInt(int? role) {
    switch (role) {
      case 0:
        return StaffRole.owner;
      case 1:
        return StaffRole.administrator;
      case 2:
        return StaffRole.user;
      case 3:
        return StaffRole.cashier;
      default:
        return StaffRole.unknown;
    }
  }
}

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.name,
    required this.role,
    this.telegramId,
  });

  final int userId;

  final String name;

  final StaffRole role;

  final int? telegramId;

  bool get isLinked => telegramId != null;

  @override
  String toString() => 'StaffMember($name, role: $role, linked: $isLinked)';
}

enum StaffRole { owner, administrator, user, cashier, unknown }

extension StaffRoleExtension on StaffRole {
  String get displayName {
    switch (this) {
      case StaffRole.owner:
        return 'Владелец';
      case StaffRole.administrator:
        return 'Администратор';
      case StaffRole.user:
        return 'Пользователь';
      case StaffRole.cashier:
        return 'Кассир';
      case StaffRole.unknown:
        return 'Неизвестно';
    }
  }
}
