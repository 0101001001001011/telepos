import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/settings/sessions_controller.dart';

/// Список живых сеансов этой кассы и их отзыв — задача 19 закрытия долга
/// безопасности (закрывает седьмую фазу). `SessionRegistry.revokeAll()`
/// существовал с задачи 9 и не звался ни одной строкой рабочего кода (снят
/// задачей 21) — этот экран и есть недостающий вызывающий для отзыва одного
/// сеанса (`revokeSession`); смена PIN и деактивация в
/// `user_management_screen.dart` зовут `revokeForUser` — сужение до
/// затронутого пользователя, а не `revokeAll()`, которого больше нет.
///
/// Достижим из хаба настроек (`GeneralSettingsScreen`, плитка рядом с
/// «Пользователи» и «Вход и сеанс») под правом `settings.users` — тот же
/// периметр «кто и как входит в кассу», что и у `/auth-settings` (задача
/// 18): отзыв чужого сеанса не то же самое, что настройка оборудования.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(sessionsControllerProvider.notifier).load(),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  Future<void> _confirmRevoke(LiveSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionsRevokeConfirmTitle),
        content: Text(l10n.sessionsRevokeConfirmBody(session.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.globalCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.sessionsRevoke,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final revoked = await ref
        .read(sessionsControllerProvider.notifier)
        .revoke(session.terminalId);
    if (!mounted) return;

    if (revoked) {
      _snack(l10n.sessionsRevoked(session.name));
    } else {
      final error = ref.read(sessionsControllerProvider).error;
      _snack(l10n.sessionsRevokeError(error ?? session.name), error: true);
    }
  }

  String _time(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(sessionsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.sessions.isEmpty
          ? Center(
              key: const ValueKey('sessions-empty'),
              child: Text(l10n.sessionsEmpty),
            )
          : ListView.builder(
              key: const ValueKey('sessions-list'),
              padding: const EdgeInsets.all(16),
              itemCount: state.sessions.length,
              itemBuilder: (context, index) {
                final session = state.sessions[index];
                final revoking = state.revokingTerminalId == session.terminalId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      TeleposIcons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      session.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${session.role} · '
                      '${l10n.sessionsTerminalLabel(session.terminalId.toString())}\n'
                      '${l10n.sessionsTimes(_time(session.issuedAt), _time(session.expiresAt))}',
                    ),
                    isThreeLine: true,
                    trailing: TextButton(
                      key: ValueKey('sessions-revoke-${session.terminalId}'),
                      onPressed: revoking
                          ? null
                          : () => _confirmRevoke(session),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: revoking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.sessionsRevoke),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
