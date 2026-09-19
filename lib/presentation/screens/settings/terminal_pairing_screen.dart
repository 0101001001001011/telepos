import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/backend/api_server_reachability.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/settings/terminal_service_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Экран, оживляющий `PairingInvites.mint()` — задача 2 работы «знакомство
/// терминала с кассой», исправленный волной правок «касса говорит, что
/// набирать» (2026-08-23) после разбора фазы 1.
///
/// # Чего не было до этого экрана
///
/// `PairingInvites.mint()` выдаёт код на 15 минут, `redeem()` тратит его один
/// раз, `/ca.crt` требует его в `?invite=` и отвечает 403 без него — механизм
/// написан и охраняет. Но задача 1 обнаружила, что достать `PairingInvites`
/// было **нечем**: он не выходил из `ApiServer` ни одним путём, и задача 1
/// положила его в `GetIt` тем же приёмом, что и `SessionRegistry`
/// (`service_locator.dart`). До этого экрана вызывающего для `mint()` не было
/// ни одной строки `lib/` — новое устройство не могло получить корень никак,
/// кроме ручного копирования файла сертификата.
///
/// # БЛОКЕР разбора фазы 1: экран не называл форму `?invite=`
///
/// Первая версия этого экрана показывала адрес кассы (`https://host:8787`) и
/// код рядом, с подсказкой «наберите адрес вместе с кодом ниже» — но
/// единственный потребитель кода, `GET /ca.crt?invite=<код>`, эту форму не
/// называл нигде: ни экран, ни отдаваемая страница, ни браузерная сборка.
/// Оператор, делавший буквально написанное, попадал на интерстициал
/// недоверенного корня — тот самый, ради обхода которого код и выдаётся.
/// Правка показывает **целиком** то, что нужно набрать —
/// `https://host:port/ca.crt?invite=<код>` — одной строкой, копируемой и
/// рисуемой QR-кодом (`qr_flutter` уже был в дереве —
/// `telegram_auth_screen.dart` рисует им код входа в Telegram тем же
/// `QrImageView`; тащить новую зависимость ради этого не пришлось).
///
/// # Почему только на кассе, не в браузерном терминале
///
/// `PairingInvites` живёт в `lib/backend/`, в процессе кассы, — у браузерной
/// вкладки его не достать никаким проводом (мятить приглашение самому себе
/// смысла не имеет). Тот же довод, что и у `TerminalServiceSettingsScreen`:
/// заведён только в десктопном маршрутизаторе (`app_router.dart`), не в
/// `createSetupRouter`.
///
/// # Почему код нельзя увидеть дважды, и что происходит со старым при новой
/// выдаче
///
/// `mint()` возвращает код ровно один раз, и `PairingInvites` не хранит
/// историю выданных кодов открытым текстом — хранить её значило бы держать
/// вторую, более долгоживущую копию пропуска, задуманного как одноразовый
/// момент, а не постоянная запись. Поэтому экран держит последний выданный
/// код только в собственном виджет-состоянии: уход со страницы уничтожает
/// `State` вместе с ним.
///
/// Разбор фазы 1 назвал дефект: `mint()` не трогает чужие записи, и до этой
/// правки прежний код **оставался действительным** до истечения 15 минут,
/// пока экран говорил «вы не увидите его снова» — ни слова про то, что
/// старый всё ещё годен. Решение — строже дешёвого варианта «просто сказать
/// правду»: `_mint()` теперь зовёт `invites.revoke(previous.code)` сразу
/// после выдачи нового, если на экране уже был непредъявленный код. Отзыв
/// узкий — только код **этого экземпляра экрана**: у второй открытой вкладки
/// свой код, и он этой операцией не тронут (у него нет способа узнать про
/// код первой). См. докстринг `PairingInvites.revoke`.
///
/// # Почему адрес завязан на работающий сервер, а не на настройку — разбор
/// фазы 1, пункт 6
///
/// Первая версия экрана читала `TerminalServiceChoice` — **настройку** — и
/// делала это один раз в `initState`. Два дефекта разом:
///
/// 1. Оператор уходит с этого экрана в «Настройки терминалов», включает
///    обслуживание, возвращается `pop()`'ом на живой `State` — и по-прежнему
///    видит «касса не обслуживает терминалы», потому что `initState()` для
///    существующего `State` второй раз не зовётся. Экран читает состояние
///    заново в каждой сборке `build()`, а не кэширует его полем — то есть тот
///    же вопрос задаётся при каждом возврате.
/// 2. Даже перечитанная настройка — не то же самое, что работающий сервер:
///    `TerminalServiceSettingsScreen` сама предупреждает —
///    «Изменение вступит в силу после перезапуска кассы» — то есть между
///    «включил» и «перезапустил» настройка уже `true`, а `ApiServer` этого
///    процесса всё ещё поднят с `ListenScope.loopback`. Экран, спрашивающий
///    настройку, в этом окне бодро выдал бы код по адресу, на котором никто
///    не отвечает, — ровно то состояние, ради которого гейт и заводился.
///
/// Источник истины теперь — [ApiServerReachability]: маленький признак
/// наружу из `ApiServer`, который сознательно не в `GetIt` (см. докстринг
/// класса). `lib/main.dart` пишет туда после исхода `ApiServer.start()`.
/// Настройка не забыта — она решает, какое из двух сообщений показать, пока
/// адреса ещё нет: «обслуживание выключено, включите» или «обслуживание
/// включено, но касса ещё не перезапущена».
class TerminalPairingScreen extends ConsumerStatefulWidget {
  const TerminalPairingScreen({super.key});

  @override
  ConsumerState<TerminalPairingScreen> createState() =>
      _TerminalPairingScreenState();
}

class _TerminalPairingScreenState extends ConsumerState<TerminalPairingScreen> {
  /// Последний выданный код. `null` — ничего не мятилось на этом экране
  /// (или экран только что создан заново после ухода со страницы).
  PairingInvite? _invite;

  void _mint() {
    final invites = GetIt.I<PairingInvites>();
    final previous = _invite;
    final invite = invites.mint();
    // Разбор фазы 1, пункт 4: прежний непредъявленный код отзывается —
    // строгий вариант, а не только честная надпись. См. докстринг класса.
    if (previous != null) {
      invites.revoke(previous.code);
    }
    setState(() => _invite = invite);
  }

  String _time(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Перечитывается на каждой сборке — не кэшируется полем `initState`.
    // Это и есть способ, которым возврат `pop()` с «Настроек терминалов»
    // видит уже включённое обслуживание (разбор фазы 1, пункт 6).
    final reachableUrl = GetIt.I<ApiServerReachability>().url;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairingTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: reachableUrl != null
            ? [
                _linkCard(l10n, reachableUrl),
                const SizedBox(height: 12),
                _codeCard(l10n),
                const SizedBox(height: 12),
                _onceNote(l10n),
              ]
            : [_notReachableCard(l10n)],
      ),
    );
  }

  /// Не «выключено обслуживание» единым цветом — две разные причины, две
  /// разные подсказки (разбор фазы 1, пункт 6).
  Widget _notReachableCard(AppLocalizations l10n) {
    final settingOn = TerminalServiceChoice.read(
      ref.read(sharedPreferencesProvider),
    ).enabled;

    if (settingOn) {
      // Настройка включена, сервер этого процесса — ещё нет: гонка
      // «включил / перезапустил», которую спрашивание настройки скрывало бы.
      return Card(
        color: AppColors.warningLight,
        child: ListTile(
          key: const ValueKey('pairing-restart-note'),
          leading: const Icon(Icons.restart_alt, color: AppColors.warning),
          title: Text(l10n.pairingRestartNote),
        ),
      );
    }

    // Разбор фазы 1, пункт 7: кнопка ниже ведёт на маршрут с ДРУГИМ ключом
    // права (`settings.terminalService`), не тем, что уже защищает этот
    // экран (`settings.users`, см. `_routePermissions` в
    // `permission_keys.dart`). У кого есть один и нет другого — молчаливый
    // увод домом (тем же приёмом, что ловили в прошлой работе). Нет права —
    // нет кнопки, а не «показать и не дать нажать» (раздел 11 управляющего
    // документа).
    final canOpenTerminalSettings = ref.watch(
      appStateProvider.select(
        (s) => s.permissions.contains(PermissionKeys.settingsTerminalService),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.warningLight,
          child: ListTile(
            key: const ValueKey('pairing-disabled-note'),
            leading: const Icon(Icons.lan_outlined, color: AppColors.warning),
            title: Text(l10n.pairingDisabledNote),
            isThreeLine: false,
          ),
        ),
        if (canOpenTerminalSettings) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('pairing-open-terminal-service'),
            onPressed: () => context.push(AppRoutes.terminalServiceSettings),
            child: Text(l10n.pairingDisabledAction),
          ),
        ],
      ],
    );
  }

  /// То, что человек набирает или сканирует целиком — базовый адрес плюс
  /// `/ca.crt?invite=<код>`, а не адрес без формы, которую называет только
  /// докстринг `ApiServer._rootCertificate` (разбор фазы 1, блокер 1).
  Widget _linkCard(AppLocalizations l10n, String baseUrl) {
    final invite = _invite;
    final fullUrl = invite == null
        ? null
        : '$baseUrl/ca.crt?invite=${invite.code}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListTile(
                    key: const ValueKey('pairing-address'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.pairingAddressLabel),
                    subtitle: Text(
                      fullUrl == null
                          ? l10n.pairingLinkPending
                          : '$fullUrl\n${l10n.pairingAddressHint}',
                    ),
                    isThreeLine: fullUrl != null,
                  ),
                ),
                if (fullUrl != null)
                  IconButton(
                    key: const ValueKey('pairing-copy-link'),
                    icon: const Icon(Icons.copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: fullUrl)),
                  ),
              ],
            ),
            // Иконка `Icons.qr_code_2` здесь стояла и раньше — но ничего не
            // рисовала: обещала QR, которого не было. `qr_flutter` уже в
            // pubspec (`telegram_auth_screen.dart` рисует им код входа), так
            // что решение разбора фазы 1 — нарисовать настоящий, а не убрать
            // обещание.
            if (fullUrl != null) ...[
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  key: const ValueKey('pairing-qr'),
                  data: fullUrl,
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _codeCard(AppLocalizations l10n) {
    final invite = _invite;
    if (invite == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.key, size: 32, color: AppColors.primary),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('pairing-mint'),
                onPressed: _mint,
                icon: const Icon(Icons.key),
                label: Text(l10n.pairingMint),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.pairingCodeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    invite.code,
                    key: const ValueKey('pairing-code'),
                    style: TextStyle(
                      fontFamily: AppTypography.familyMono,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('pairing-copy-code'),
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: invite.code)),
                ),
              ],
            ),
            Text(
              l10n.pairingExpiresAt(_time(invite.expiresAt)),
              key: const ValueKey('pairing-expires'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('pairing-mint-again'),
              onPressed: _mint,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.pairingMintAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onceNote(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: AppColors.warningLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            TeleposIcons.info,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.pairingOnceNote,
              key: const ValueKey('pairing-once-note'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
