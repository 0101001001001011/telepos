import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/permission_label.dart';
import 'package:telepos/presentation/common/utils/role_label.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

final _usersProvider = FutureProvider<List<User>>((ref) async {
  final db = GetIt.I<AppDatabase>();
  return db.userDao.findAll();
});

/// Гасит живые сеансы одного пользователя этой кассы — задача 19 закрытия
/// долга безопасности. `SessionRegistry.revokeAll()` существовал с задачи 9
/// и был документирован как реакция именно на смену пароля и отзыв
/// доступа, но не звался ни одной строкой рабочего кода: экран менял пароль
/// и блокировал пользователя, а сеанс, выписанный на его прежний PIN или на
/// аккаунт, который только что заблокировали, продолжал жить до истечения
/// по бездействию.
///
/// Первая версия этой правки звала `revokeAll()` целиком — гасила **все**
/// сеансы этой кассы, а не только сеансы затронутого пользователя. В
/// магазине это значило «кассир сменил себе PIN — вышибло коллег посреди
/// смены»: надобности в этом нет, смена PIN одного человека не делает
/// чужие сеансы недействительными. `SessionRegistry.revokeForUser` сужает
/// отзыв до сеансов, выписанных на затронутого [userId]; сеансы других
/// пользователей той же кассы не трогает — см. докстринг метода.
///
/// `isRegistered` — та же защита, что уже стоит в
/// `AuthSettingsController.setSessionIdleMinutes`: экран может открыться в
/// тесте или на сборке без поднятого провода, где `SessionRegistry` в
/// get_it не заведён вовсе.
void _revokeUserLiveSessions(int userId) {
  if (GetIt.I.isRegistered<SessionRegistry>()) {
    GetIt.I<SessionRegistry>().revokeForUser(userId);
  }
}

/// Пишет одну запись в журнал событий безопасности — задача 21 закрытия
/// долга безопасности.
///
/// `isRegistered`-охрана тем же приёмом, что у [_revokeUserLiveSessions]
/// рядом: экран может открыться в тесте или на сборке, где `SecurityJournal`
/// в get_it не заведён вовсе.
///
/// `userId` здесь — тот кассир, чьё событие это (чей PIN сменили, чьи права
/// изменили, кого удалили, кто заведён, чья роль сменилась) — **субъект**
/// события, тем же смыслом, каким это поле уже несёт `auth.login` (кандидат
/// входа) и сеансы (владелец сеанса), а не тот, кто нажал «Сохранить».
///
/// # Колонка «кто» хранит «над кем» (пункт 4 брифа закрытия долга
/// безопасности, 2026-08-22)
///
/// В отличие от `wire.denied`/`auth.login`/`session.issued`, где субъект и
/// действующий — одно и то же лицо (сеанс выписывается тому, кто вошёл), у
/// всех событий этой функции они **разные**: строка `user.pinChanged,
/// userId=B` читается как «B сменил себе PIN», тогда как на самом деле A
/// (администратор за этим экраном) сменил PIN у B. У схемы
/// (`SecurityEvents`, `security_tables.dart`) нет отдельного поля для
/// действующего — решение сознательное: добавить его значило бы
/// регенерировать сгенерированный код drift для всей 87-таблицной базы
/// (`app_database.g.dart`, ~85 тыс. строк) ради одного нового столбца,
/// использованного двумя точками вставки, и это отложено, а не сделано
/// впопыхах поверх чужого поля не по имени (`correlationId` уже занят
/// сквозным идентификатором действия — И69, класть туда действующего
/// значило бы смешать два разных смысла в одном поле). Экран, ЗНАЮЩИЙ
/// действующего (`ref.watch(appStateProvider.select((s) => s.userId))` —
/// доступен здесь дёшево, `UserManagementScreen.build` уже принимает `ref`),
/// сегодня не может его записать никуда: `userId` уже занят субъектом.
/// Проверяющий это читающий обязан знать данную границу, а не считать
/// `userId` действующим по умолчанию — она названа явно здесь, а не
/// спрятана.
Future<void> _recordUserSecurityEvent({
  required String eventType,
  required int userId,
  String outcome = SecurityOutcome.success,
}) async {
  if (!GetIt.I.isRegistered<SecurityJournal>()) return;
  try {
    // Пункт 7 брифа закрытия долга безопасности (2026-08-22): до этой
    // правки `terminalDao.self()` стояла СНАРУЖИ этого try/catch, а сам
    // вызов этой функции целиком уходил через `unawaited(...)` на месте
    // вызова (`_save`/`_confirmDelete` ниже) — отказ базы здесь (диск
    // занят, заперта) утекал необработанной асинхронной ошибкой мимо
    // `try/catch` вызывающего. Единственное место во всей волне, где
    // обещание `SecurityJournal.record` «журнал никогда не бросает»
    // (`security_journal.dart`, докстринг класса) не держалось на самом
    // деле: `record` ловит всё внутри себя, но здесь исключение случалось
    // ДО того, как `record` вообще был позван. Чинится переносом одной
    // строки внутрь этого try — исключение теперь ловится тем же приёмом,
    // каким `SecurityJournal.record` ловит свои собственные отказы.
    final terminalId = await _actingTerminalId();
    await GetIt.I<SecurityJournal>().record(
      eventType: eventType,
      outcome: outcome,
      terminalId: terminalId,
      userId: userId,
    );
  } catch (error, stack) {
    if (GetIt.I.isRegistered<Talker>()) {
      GetIt.I<Talker>().warning(
        'журнал безопасности: запись "$eventType" не удалась '
        '(${safeErrorText(error)}) — событие потеряно, операция не '
        'остановлена',
        null,
        stack,
      );
    }
  }
}

/// Терминал, с которого действует этот экран — свой собственный,
/// `isSelf`: настройки кассира открыты на самой кассе, а не через провод, и
/// единственный терминал, за которым сидит десктопная касса, — её же
/// (`TerminalDao.self`).
///
/// `0` — сентинел «терминал не найден», не настоящий id (`TerminalDao`
/// заводит строки автоинкрементом от 1) — тем же приёмом, что и
/// `buildWireDeniedJournalHandler` (`lib/backend/security_journal.dart`).
/// Практически недостижимо на этом экране: список пользователей уже
/// подразумевает пройденный мастер настройки, а он заводит `isSelf`-строку.
Future<int> _actingTerminalId() async {
  final self = await GetIt.I<AppDatabase>().terminalDao.self();
  return self?.id ?? 0;
}

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final usersAsync = ref.watch(_usersProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setUserManagementTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(TeleposIcons.add),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l10n.setUsersLoadError(e.toString()),
            style: AppTextStyles.body,
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.setUsersEmpty,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(TeleposIcons.add),
                    label: Text(l10n.setAddUser),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 16,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final role = UserRole.fromIndex(user.role ?? 3);
              final isActive = user.status == 'active';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                    child: Icon(TeleposIcons.person, color: _roleColor(role)),
                  ),
                  title: Text(
                    user.name ?? l10n.setUserNumber(user.id.toString()),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      _RoleBadge(role: role),
                      const SizedBox(width: 8),
                      Icon(
                        isActive ? TeleposIcons.checkCircle : Icons.block,
                        size: 14,
                        color: isActive
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive
                            ? l10n.setUserActive
                            : (user.status ?? 'blocked'),
                        style: context.styles.caption.copyWith(
                          color: isActive
                              ? AppColors.success
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showEditDialog(context, ref, user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _UserEditDialog(user: null),
    );
    if (saved == true) {
      ref.invalidate(_usersProvider);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserEditDialog(user: user),
    );
    if (saved == true) {
      ref.invalidate(_usersProvider);
    }
  }

  static Color _roleColor(UserRole role) {
    return switch (role) {
      UserRole.owner => Colors.purple,
      UserRole.administrator => Colors.blue,
      UserRole.user => Colors.green,
      UserRole.cashier => Colors.orange,
    };
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = UserManagementScreen._roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      ),
      child: Text(
        role.label(AppLocalizations.of(context)!),
        style: context.styles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.user});

  final User? user;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _pinController;
  late int _selectedRole;
  late bool _isActive;

  Map<String, bool> _permissions = {};
  bool _permissionsLoading = true;

  bool get isCreating => widget.user == null;
  bool get isOwner => _selectedRole == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _pinController = TextEditingController();
    _selectedRole = widget.user?.role ?? 3;
    _isActive = widget.user?.status == 'active' || isCreating;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermissions());
  }

  Future<void> _loadPermissions() async {
    if (!mounted) return;
    final db = GetIt.I<AppDatabase>();

    if (isCreating) {
      final perms = <String, bool>{};
      for (final key in PermissionKeys.allPermissions) {
        perms[key] = true;
      }
      if (mounted) {
        setState(() {
          _permissions = perms;
          _permissionsLoading = false;
        });
      }
      return;
    }

    final allowed = await db.userPermissionDao.getAllowedKeys(widget.user!.id);
    final perms = <String, bool>{};
    for (final key in PermissionKeys.allPermissions) {
      perms[key] = allowed.contains(key);
    }
    if (mounted) {
      setState(() {
        _permissions = perms;
        _permissionsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dialogWidth = MediaQuery.sizeOf(context).width > 700
        ? 560.0
        : MediaQuery.sizeOf(context).width * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: 520,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isCreating ? l10n.setNewUser : l10n.setEditUser,
                      style: AppTextStyles.h3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TeleposIcons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: l10n.setUserTabProfile),
                Tab(text: l10n.setUserTabPin),
                Tab(text: l10n.setUserTabPermissions),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildPinTab(),
                  _buildPermissionsTab(),
                ],
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isCreating) ...[
                    TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        l10n.globalDelete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.globalCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(l10n.globalSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.setUserName,
              prefixIcon: const Icon(TeleposIcons.person),
            ),
            autofocus: isCreating,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.setUserNameRequired
                : null,
          ),
          const SizedBox(height: AppTheme.spacing),

          DropdownButtonFormField<int>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: l10n.setUserRole,
              prefixIcon: const Icon(Icons.shield),
            ),
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.setRoleOwner)),
              DropdownMenuItem(
                value: 1,
                child: Text(l10n.setRoleAdministrator),
              ),
              DropdownMenuItem(value: 2, child: Text(l10n.setRoleUser)),
              DropdownMenuItem(value: 3, child: Text(l10n.setRoleCashier)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                // Правка Б-3 закрытия долга безопасности (2026-08-22):
                // понижение с владельца до не-владельца.
                //
                // Владелец никогда не получает строк прав —
                // `LocalAuthRepository._issue` выдаёт ему
                // `PermissionKeys.allPermissions` в обход таблицы целиком
                // (докстринг `PermissionKeys.roleDefaults`), поэтому
                // `_permissions`, которые `_loadPermissions` загрузила для
                // РЕАЛЬНОГО владельца через `getAllowedKeys`, — это не
                // снимок настоящих прав, а пустая таблица (owner-строк
                // просто нет). Если оставить их как есть при понижении,
                // все переключатели на вкладке прав окажутся выключены (они
                // рисуются `isOwner ? true : (_permissions[key] ?? true)`
                // — при `isOwner == false` читается уже выключенный
                // `_permissions[key]`), и «Сохранить» запишет запрещающие
                // строки на всё — человек без единого права.
                //
                // Подставляем умолчания НОВОЙ роли — то же самое, что
                // получил бы кассир, заведённый заново.
                if (isOwner && v != 0) {
                  final defaults =
                      PermissionKeys.roleDefaults[UserRole.fromIndex(v)] ??
                      const <String>{};
                  _permissions = {
                    for (final key in PermissionKeys.allPermissions)
                      key: defaults.contains(key),
                  };
                }
                _selectedRole = v;
              });
            },
          ),
          const SizedBox(height: AppTheme.spacing),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.setUserActive),
            subtitle: Text(
              _isActive ? l10n.setUserActiveDesc : l10n.setUserBlockedDesc,
              style: context.styles.caption,
            ),
            value: _isActive,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPinTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isCreating ? l10n.setUserPinLabel : l10n.setUserPinChange,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 6),
          Text(
            isCreating ? l10n.setUserPinSetHint : l10n.setUserPinKeepHint,
            style: context.styles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: TextFormField(
              controller: _pinController,
              readOnly: true,
              showCursor: true,
              textAlign: TextAlign.center,
              obscureText: true,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: isCreating
                    ? l10n.setUserPinLabel
                    : l10n.setUserPinNew,
                prefixIcon: const Icon(Icons.lock),
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (v) {
                if (isCreating) {
                  if (v == null || v.isEmpty) return l10n.setUserPinRequired;
                  if (v.length < 4) return l10n.setUserPinMin;
                } else if (v != null && v.isNotEmpty && v.length < 4) {
                  return l10n.setUserPinMin;
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          NumPad(
            showEnter: false,
            buttonSize: 60,
            onKeyPressed: (d) {
              if (_pinController.text.length >= 6) return;
              _pinController.text += d;
            },
            onBackspace: () {
              final t = _pinController.text;
              if (t.isNotEmpty) {
                _pinController.text = t.substring(0, t.length - 1);
              }
            },
            onClear: () => _pinController.clear(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_permissionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isOwner) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(TeleposIcons.info, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.setUserOwnerFullAccess,
                    style: AppTextStyles.body.copyWith(color: Colors.purple),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPermissionsList(disabled: true)),
        ],
      );
    }

    return _buildPermissionsList(disabled: false);
  }

  Widget _buildPermissionsList({required bool disabled}) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: PermissionKeys.groups.entries.map((group) {
        final groupKey = group.key;
        final keys = group.value;
        final allOn = keys.every((k) => _permissions[k] == true);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      permissionGroupLabel(groupKey, AppLocalizations.of(context)!),
                      style: AppTextStyles.h3.copyWith(fontSize: 15),
                    ),
                  ),
                  TextButton(
                    onPressed: disabled
                        ? null
                        : () {
                            setState(() {
                              final newValue = !allOn;
                              for (final k in keys) {
                                _permissions[k] = newValue;
                              }
                            });
                          },
                    child: Text(
                      allOn ? l10n.setUserDeselectAll : l10n.setUserSelectAll,
                      style: context.styles.caption.copyWith(
                        color: disabled
                            ? AppColors.textDisabled
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...keys.map((key) {
              return SwitchListTile(
                dense: true,
                title: Text(
                  permissionLabel(key, AppLocalizations.of(context)!),
                  style: AppTextStyles.body,
                ),
                value: isOwner ? true : (_permissions[key] ?? true),
                activeColor: AppColors.primary,
                onChanged: disabled
                    ? null
                    : (v) {
                        setState(() => _permissions[key] = v);
                      },
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _confirmDelete() async {
    final user = widget.user;
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setDeleteUserTitle),
        content: Text(
          l10n.setDeleteUserConfirm(
            user.name ?? l10n.setUserNumber(user.id.toString()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.globalDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = GetIt.I<AppDatabase>();
    try {
      await db.userPermissionDao.deleteByUserId(user.id);
      await (db.delete(db.users)..where((u) => u.id.equals(user.id))).go();
      // Задача 19 закрытия долга безопасности: удалённый пользователь не
      // должен оставаться вошедшим на живой сессии до истечения по
      // бездействию — см. докстринг `_revokeUserLiveSessions`.
      _revokeUserLiveSessions(user.id);
      // Задача 21 закрытия долга безопасности: журнал событий безопасности.
      // `unawaited`-эквивалент — экран уже внутри `await`-цепочки `_save`, а
      // запись не имеет права задержать закрытие диалога.
      unawaited(
        _recordUserSecurityEvent(
          eventType: SecurityEventType.userDeleted,
          userId: user.id,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setDeleteUserError(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _tabController.animateTo(0);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.setUserNameRequired)));
      }
      return;
    }

    if (isCreating && _pinController.text.trim().length < 4) {
      _tabController.animateTo(1);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.setUserPinRange)));
      }
      return;
    }

    final db = GetIt.I<AppDatabase>();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final status = _isActive ? 'active' : 'blocked';

    try {
      debugPrint(
        '[UserMgmt] _save called, isCreating=$isCreating, name=$name, role=$_selectedRole',
      );
      if (isCreating) {
        final pin = _pinController.text.trim();

        // Никакого ключа из базы здесь больше не нужно: PIN хранится как
        // PBKDF2-свёртка со своей солью на каждого пользователя. Прежняя
        // проверка «нет RSA-ключа — нельзя завести пользователя» ушла вместе с
        // ключом, иначе на новой установке нельзя было бы создать никого.
        final encryptedPin = PinCredential.create(pin);

        final id = await db.userDao.getNextId();
        debugPrint('[UserMgmt] Creating user with id=$id');

        await db.userDao.insertUser(
          UsersCompanion(
            id: Value(id),
            name: Value(name),
            role: Value(_selectedRole),
            status: Value(status),
            editTime: Value(now),
            passwordEnc: Value(encryptedPin),
          ),
        );

        // БЛОКЕР 1 закрытия долга безопасности (2026-08-22): до этой правки
        // заведение кассира — вставка `Users` с `PinCredential.create(pin)`
        // и полным набором прав — было единственным действием этой формы,
        // не оставлявшим ни одного следа в журнале: завести себе учётку с
        // PIN был самый дешёвый бэкдор в продукте. `unawaited` — не
        // задерживает закрытие диалога, тем же приёмом, что и записи PIN/
        // прав в ветке редактирования ниже. `outcome` — заведённая роль:
        // единственная содержательная деталь, которую есть куда положить
        // для события без предшествующего состояния.
        unawaited(
          _recordUserSecurityEvent(
            eventType: SecurityEventType.userCreated,
            userId: id,
            outcome: UserRole.fromIndex(_selectedRole).name,
          ),
        );

        if (_selectedRole != 0) {
          // Все ключи, а не только выключенные: человек видел каждый
          // переключатель на экране и мог его тронуть, поэтому «создать и
          // не трогать» должно писать явные строки на всё, что было
          // показано включённым — а не молчаливые ноль строк, как раньше
          // (`if (changed.isNotEmpty)` пропускал запись целиком, если никто
          // ничего не выключил). Тот же охват, что и ветка редактирования
          // ниже.
          final changed = <String, bool>{
            for (final entry in _permissions.entries) entry.key: entry.value,
          };
          await db.userPermissionDao.setPermissions(id, changed);
        }
      } else {
        final userId = widget.user!.id;
        final wasActive = widget.user!.status == 'active';
        // БЛОКЕР 1 закрытия долга безопасности (2026-08-22): роль ДО
        // сохранения — тот же источник умолчания, что и `initState`
        // (`_selectedRole = widget.user?.role ?? 3`), чтобы сравнение ниже
        // не путало «роль не менялась» с «роль пришла null».
        final oldRole = widget.user!.role ?? 3;

        final newPin = _pinController.text.trim();
        Value<String?> passwordEnc = const Value.absent();
        final pinChanged = newPin.isNotEmpty;
        if (pinChanged) {
          // Смена PIN всегда даёт новую соль, поэтому один и тот же PIN,
          // выставленный дважды, хранится по-разному.
          passwordEnc = Value(PinCredential.create(newPin));
        }

        await db.userDao.updateUser(
          userId,
          UsersCompanion(
            name: Value(name),
            role: Value(_selectedRole),
            status: Value(status),
            editTime: Value(now),
            passwordEnc: passwordEnc,
          ),
        );

        // Задача 19 закрытия долга безопасности: смена PIN и деактивация
        // зовут `SessionRegistry.revokeForUser(userId)` — см. докстринг
        // `_revokeUserLiveSessions`. Смена PIN гасит сеансы этого
        // пользователя независимо от того, чья это учётка: до задачи 19
        // сеанс, выписанный на прежний, уже смененный PIN, продолжал жить
        // до истечения по бездействию; сеансы других кассиров этой кассы
        // не трогает. Деактивация — только на переходе `active` →
        // `blocked` (`wasActive && !_isActive`), а не на каждом сохранении
        // уже заблокированного пользователя: повторное сохранение того же
        // состояния не должно вышибать его же сеанс заново.
        if (pinChanged || (wasActive && !_isActive)) {
          _revokeUserLiveSessions(userId);
        }

        // БЛОКЕР 1 закрытия долга безопасности (2026-08-22): смена роли как
        // таковая не журналировалась вовсе — писалась только перезапись
        // прав (`permissionsChanged` ниже), которая роли не называет, и та
        // вдобавок была не заведена при повышении до владельца (`if
        // (_selectedRole != 0)`, см. довод там). Кассир→администратор не
        // оставлял ни единого следа. Эта запись пишется всегда, когда роль
        // РЕАЛЬНО изменилась, — независимо от того, пишутся ли права ниже:
        // условие `_selectedRole != 0` НЕ применяется здесь нарочно.
        // `unawaited`: не задерживает диалог, тем же приёмом, что и
        // остальные записи этой функции.
        if (oldRole != _selectedRole) {
          unawaited(
            _recordUserSecurityEvent(
              eventType: SecurityEventType.roleChanged,
              userId: userId,
              outcome:
                  '${UserRole.fromIndex(oldRole).name}->'
                  '${UserRole.fromIndex(_selectedRole).name}',
            ),
          );
        }

        // Задача 21 закрытия долга безопасности: журнал событий
        // безопасности. Отдельная запись за PIN — реальный секрет меняется,
        // это отдельное от прав событие (бриф задачи 21: «нет сеанса» и
        // «нет права» разводили отдельной правкой, тем же духом здесь
        // разводится «сменили PIN» от «сменили права» — разные вещи для
        // того, кто читает журнал). `unawaited`: не задерживает диалог.
        if (pinChanged) {
          unawaited(
            _recordUserSecurityEvent(
              eventType: SecurityEventType.pinChanged,
              userId: userId,
            ),
          );
        }

        if (_selectedRole != 0) {
          final changed = <String, bool>{};
          for (final entry in _permissions.entries) {
            changed[entry.key] = entry.value;
          }
          await db.userPermissionDao.setPermissions(userId, changed);
          // Задача 21 закрытия долга безопасности: журнал событий
          // безопасности — см. довод у записи PIN чуть выше про то, почему
          // это отдельное от неё событие.
          unawaited(
            _recordUserSecurityEvent(
              eventType: SecurityEventType.permissionsChanged,
              userId: userId,
            ),
          );
        }
        // Правка Б-3 закрытия долга безопасности (2026-08-22): при
        // `_selectedRole == 0` (повышение до владельца) строки НЕ пишутся
        // и НЕ стираются — до этой правки здесь стоял `deleteByUserId`,
        // безвозвратно стиравший вручную настроенный набор прав на каждое
        // повышение. Решено в пользу «не трогать»: владелец и так не читает
        // эту таблицу (`LocalAuthRepository._issue` обходит её целиком, тот
        // же довод, что и у `PermissionKeys.roleDefaults`) — оставшиеся
        // строки мертвы, но безвредны, пока роль не понизят обратно, а
        // понижение (см. `onChanged` дропдауна роли выше) в любом случае
        // перезаписывает явным набором умолчаний новой роли при сохранении,
        // так что несостоявшееся удаление здесь ничего не портит и ничего
        // не подделывает — только не выбрасывает данные, которые можно
        // было бы сохранить бесплатно.
        //
        // БЛОКЕР 1 закрытия долга безопасности (2026-08-22): этот `if`
        // по-прежнему охраняет именно ЗАПИСЬ ПРАВ (`permissionsChanged`) —
        // и правильно охраняет, права здесь и правда не пишутся при
        // повышении до владельца, событие о том, чего не произошло, было
        // бы неправдой. Но САМА СМЕНА РОЛИ — другое событие
        // (`roleChanged`, чуть выше) и этим условием больше не охраняется:
        // кассир→владелец пишет свою строку точно так же, как
        // кассир→администратор.
      }

      debugPrint('[UserMgmt] Save successful');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      // safeErrorText, не сам объект и не голый тип — ни в журнал, ни на
      // экран. Этот блок пишет `passwordEnc` (см. `UsersCompanion` выше), и
      // `SqliteException.toString()` печатает `parameters: …` — тот же
      // риск, что нашёлся в `LocalAuthRepository.login` финальным разбором
      // ветки 2026-08-20-browser-terminal-login, только здесь `e.toString()`
      // ещё и уходил в `SnackBar` — на живой экран кассы, а не только в
      // журнал.
      final safeText = safeErrorText(e);
      debugPrint('[UserMgmt] Save ERROR ($safeText)\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setUsersLoadError(safeText)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
