import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/net/till_network_name.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Единственное место, где оператор открывает и закрывает порт кассы.
///
/// # Почему экран, а не флаг сборки
///
/// Порт в сеть магазина — решение о безопасности, и принимать его обязан
/// владелец установки: «Новая установка не открывает наружу ничего. Каждая
/// открытая возможность — сознательное включение владельцем, а не состояние из
/// коробки» (`docs/system-architecture.md`, раздел 16). До 2026-08-06 решение
/// принималось за него определением сборки `TELEPOS_API`, которого не было ни в
/// одной сборке, — то есть не принималось вовсе, и браузерный терминал не
/// работал ни у кого. Обоснование выбора целиком — на
/// [TerminalServiceChoice].
///
/// # Почему экран только на кассе
///
/// Он настраивает сокеты **этой машины**. У браузерной вкладки своих сокетов
/// нет, и показывать ей этот переключатель значило бы предложить настроить
/// чужой компьютер: И11 — недоступная возможность означает, что экрана нет.
/// Поэтому он живёт в `app_router.dart` (десктопный маршрутизатор) и не
/// заведён в `createSetupRouter`.
class TerminalServiceSettingsScreen extends ConsumerStatefulWidget {
  const TerminalServiceSettingsScreen({super.key});

  @override
  ConsumerState<TerminalServiceSettingsScreen> createState() =>
      _TerminalServiceSettingsScreenState();
}

class _TerminalServiceSettingsScreenState
    extends ConsumerState<TerminalServiceSettingsScreen> {
  /// Что стоит в настройках сейчас.
  late bool _enabled;

  /// Что стояло в них, когда экран открыли.
  ///
  /// Нужно ровно на одно: показать напоминание о перезапуске только тому, кто
  /// действительно поменял решение. Напоминание, висящее всегда, читается как
  /// украшение и перестаёт читаться совсем — а именно оно объясняет, почему
  /// планшет не подключился сразу после щелчка.
  late bool _asStarted;

  @override
  void initState() {
    super.initState();
    final choice = TerminalServiceChoice.read(
      ref.read(sharedPreferencesProvider),
    );
    _enabled = choice.enabled;
    _asStarted = choice.enabled;
  }

  /// Пишет решение сразу, без кнопки «Сохранить».
  ///
  /// Кнопка здесь была бы третьим состоянием — «переключил, но не сохранил», —
  /// и именно в нём человек ушёл бы перезапускать кассу.
  Future<void> _apply(bool value) async {
    setState(() => _enabled = value);
    await TerminalServiceChoice.write(
      ref.read(sharedPreferencesProvider),
      enabled: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Порт из умолчания `ApiServer.port`. Показывается вместе с именем, потому
    // что адрес без порта — это адрес, по которому ничего не откроется.
    const port = 8787;
    final address = 'https://${tillNetworkName()}.local:$port';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.terminalServiceTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              key: const ValueKey('terminal-service-enable'),
              value: _enabled,
              onChanged: _apply,
              title: Text(l10n.terminalServiceEnable),
              subtitle: Text(
                _enabled
                    ? l10n.terminalServiceEnabledNote
                    : l10n.terminalServiceDisabledNote,
              ),
              secondary: Icon(
                _enabled ? Icons.lan : Icons.lan_outlined,
                color: _enabled
                    ? AppColors.success
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_enabled != _asStarted) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.warning.withValues(alpha: 0.12),
              child: ListTile(
                key: const ValueKey('terminal-service-restart-note'),
                leading: const Icon(
                  Icons.restart_alt,
                  color: AppColors.warning,
                ),
                title: Text(l10n.terminalServiceRestartNote),
              ),
            ),
          ],
          if (_enabled) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const ValueKey('terminal-service-address'),
                leading: const Icon(Icons.qr_code_2),
                title: Text(l10n.terminalServiceAddress),
                subtitle: Text('$address\n${l10n.terminalServiceAddressHint}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: address)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
