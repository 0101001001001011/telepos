import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/domain/shift/shift_desk.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Куда браузерный терминал приходит после входа, если у этого хоста нет
/// своей базы.
///
/// # Почему не `/shift` и не экран продажи
///
/// `getPostLoginRoute()` в `login_controller.dart` спрашивает
/// `HostCapabilities.ownsData`, а не облик хоста (`lib/domain/host/host_capabilities.dart`,
/// раздел 4 управляющего документа). `/shift` и экран продажи читают
/// `AppDatabase` напрямую — drift, `dart:ffi`, которого в браузерной сборке
/// не бывает, — и там, где `ownsData == false`, вход ведёт сюда вместо них.
///
/// # Права проверяются показом
///
/// Плитка, до которой у вошедшего нет действующего права
/// ([AuthSession.permissions], уже пересечённых с правами режима точки на
/// кассе), не строится вовсе — не строится, а не строится и блокируется:
/// показанная кнопка, которая ничего не делает по нажатию, обещание, которого
/// система не держит (раздел 11 управляющего документа).
///
/// # Что здесь переиспользовано, а не написано заново
///
/// `SettingsSection`/`SettingsTile`/`WizardMetrics` — та же тройка, которой
/// был собран `WtTerminalReadyScreen`, экран, который этот файл заменяет на
/// маршруте `/login`. Форма подошла без изменений: сгруппированный список в
/// духе Telegram с заголовком, подвалом и разделителями в один физический
/// пиксель. Сам состав секций и правило видимости плиток написаны заново —
/// у прежнего экрана их не было вовсе, он показывал только состояние мастера.
class TerminalHomeScreen extends ConsumerWidget {
  const TerminalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final metrics = WizardMetrics.resolve(
      layout: Breakpoints.of(context),
      input: ref.watch(inputModeProvider),
    );

    // `ref.watch` — не снимок: любая перемена сеанса (выход, новое право,
    // открытие смены другим путём) перерисовывает экран сама, без ручного
    // опроса. Живой подпиской в собственном смысле слова (потоком с кассы)
    // здесь оборачивать нечего — вся нужная информация уже приехала в
    // `AuthSession` при входе и лежит в `AppState`.
    final state = ref.watch(appStateProvider);
    final canOpenHardwareSettings = state.hasPermission(
      PermissionKeys.settingsHardware,
    );
    // Задача «второй порядок» закрытия долга безопасности (2026-08-22),
    // пункт 6: `/sessions` — тот же периметр `settings.users`, что уже
    // держит `/hardware-settings` вход браузерного терминала (`settings
    // .hardware`) — плитка ниже даёт вошедшему администратору путь до
    // отзыва чужого сеанса, которого раньше не было вовсе.
    final canOpenSessions = state.hasPermission(PermissionKeys.settingsUsers);
    // Настройка оплаты по QR — решение заказчика 2026-09-18. Ключ показа тот
    // же, что у маршрута и у четырёх операций провода
    // (`settings.accounts`): провайдер решает, куда уходят деньги
    // покупателя, — это периметр счетов кассы, а не оборудования.
    final canSetUpQr = state.hasPermission(PermissionKeys.settingsAccounts);
    // Шаблон чека — решение заказчика 2026-09-18. Ключ показа тот же, что у
    // маршрута и у шести операций провода (`settings.printer`): ширину
    // ленты, на которой собран предпросмотр, задаёт экран принтера, и
    // шаблон без неё не имеет смысла.
    final canEditReceipt = state.hasPermission(PermissionKeys.settingsPrinter);
    // Смена — решение заказчика 2026-09-18. Ключ показа тот же, что у
    // маршрута `/terminal-shift` и у трёх операций провода (`nav.shift`).
    final canOpenShift = state.hasPermission(PermissionKeys.navShift);
    // Задача 13. Право проверяет **и** касса: `nav.sale` — довод каждой
    // операции `sale.*` в каталоге провода (`sale_ops.dart`), и сторож
    // `wireGuardForTill` отказывает до вызова обработчика. Здесь оно
    // работает показом — кассир без права не видит плитки, — а не вместо
    // проверки: скрытая кнопка правом не является (И162).
    final canSell = state.hasPermission(PermissionKeys.navSale);
    // Задача 20 плана «Продажа с браузерного терминала»: возврат — первый
    // **рабочий** экран кассира в браузере, а не настройка. Маршрут
    // `/refund` без плитки был бы работой, до которой нельзя дойти нажатием:
    // браузерная таблица оболочки не имеет, стека переходов у вкладки нет, и
    // единственным путём остался бы набранный адрес. Ровно этот дефект уже
    // стоил круга на `/sessions` — операции отзыва сеанса были готовы, а
    // вызвать их из браузера было нечем, и нашла это живая проверка.
    final canOpenRefund = state.hasPermission(PermissionKeys.navRefund);
    // Приём аванса — требование заказчика 2026-09-18. Ключ показа тот же,
    // что у маршрута (`nav.cashOperation`): приём денег у покупателя это
    // кассовая операция, а не продажа. Границу держит не показ —
    // `redirect` браузерной таблицы проверяет тот же ключ, а саму операцию
    // касса охраняет `op.creditRepay` сверх `nav.sale` (И162: скрытая
    // кнопка правом не является).
    final canTakePrepayment = state.hasPermission(
      PermissionKeys.navCashOperation,
    );
    // Выпуск сертификата — дыра 1 ревизии 2026-09-19. Ключ показа тот же,
    // что у маршрута и у операции провода (`op.issueCertificate`): выпуск
    // создаёт обязательство кассы из ничего, и `nav.sale` его не сторожит.
    // Умолчаний роли у ключа нет — плитки не увидит и кассир, пока владелец
    // не даст ему это право сам, и это решение, а не пробел.
    //
    // Границу при этом держит не показ: `redirect` браузерной таблицы
    // проверяет тот же ключ, экран спрашивает его перед вызовом, а касса —
    // перед обработчиком (И162).
    final canIssueCertificate = state.hasPermission(
      PermissionKeys.opIssueCertificate,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: metrics.columnMaxWidth ?? double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.pageMargin,
                vertical: AppTokens.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    header: l10n.terminalHomeWhoHeader,
                    children: [
                      SettingsTile(
                        metrics: metrics,
                        icon: Icons.person_outline,
                        title: l10n.terminalHomeUserLabel,
                        value: state.userName ?? '—',
                      ),
                      _ShiftTile(
                        metrics: metrics,
                        atLogin: state.shift,
                        canOpenShift: canOpenShift,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space16),
                  // Подпись — `l10n.hwSettingsTitle`, тот же ключ, каким это
                  // называется в `general_settings_screen.dart` и
                  // `hardware_settings_screen.dart`, а не отдельная строка со
                  // своим текстом: у этой плитки один пункт назначения
                  // (`/hardware-settings`), а не два имени на него.
                  // Право показом, а не запретом нажатия: без
                  // `settings.hardware` эта секция не строится вовсе, а не
                  // строится серой.
                  if (canOpenHardwareSettings) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.settings_outlined,
                          title: l10n.hwSettingsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.hardwareSettings),
                        ),
                        // Диагностика оборудования — пункт «Достижимость с
                        // браузерного терминала» плана 2026-09-19. **В той
                        // же секции, что и настройки оборудования, а не
                        // отдельной**: это один и тот же периметр, один и
                        // тот же ключ (`settings.hardware`), и наладчик
                        // ходит между ними подряд — привязал прибор, глянул,
                        // что ушло.
                        //
                        // Плитка обязательна, а не украшение: маршрут без
                        // неё — работа, до которой нельзя дойти нажатием
                        // (оболочки у браузерной таблицы нет, стека
                        // переходов у вкладки тоже), и сторож
                        // `browser_routes_test` красит именно это. Тот же
                        // дефект уже стоил круга на `/sessions` и `/refund`.
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.monitor_heart_outlined,
                          title: l10n.diagnosticsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () =>
                              context.go(AppRoutes.terminalDiagnostics),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Настройка оплаты по QR — решение заказчика 2026-09-18.
                  // Рядом с оборудованием, а не среди рабочих плиток ниже:
                  // это настройка кассы, которую делают один раз, а не
                  // работа кассира.
                  //
                  // Плитка обязательна, а не украшение: маршрут без неё —
                  // работа, до которой нельзя дойти нажатием (оболочки у
                  // браузерной таблицы нет, стека переходов у вкладки тоже),
                  // и сторож `browser_routes_test` красит именно это. Тот же
                  // дефект уже стоил круга на `/sessions` и `/refund`.
                  //
                  // Право показом (`settings.accounts` — тот же ключ, что у
                  // маршрута), а не запретом нажатия; границу держит
                  // `redirect` таблицы и те же четыре операции на кассе.
                  if (canSetUpQr) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.qr_code_2,
                          title: l10n.qrSettingsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.qrProviderSettings),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Шаблон чека — решение заказчика 2026-09-18. Рядом с
                  // настройкой QR и по тому же доводу: это настройка кассы,
                  // которую делают один раз, а не работа кассира.
                  //
                  // Плитка обязательна, а не украшение: маршрут без неё —
                  // работа, до которой нельзя дойти нажатием (оболочки у
                  // браузерной таблицы нет, стека переходов у вкладки тоже),
                  // и сторож `browser_routes_test` красит именно это.
                  if (canEditReceipt) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.receipt_long_outlined,
                          title: l10n.receiptTemplatesTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.receiptTemplates),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Пункт 6 закрытия долга безопасности, правка «второй
                  // порядок»: тот же приём, что у плитки оборудования выше —
                  // право показом, не запретом нажатия.
                  if (canOpenSessions) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.devices_other,
                          title: l10n.sessionsTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.sessions),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Задача 20: возврат — первый **рабочий** экран кассира
                  // в браузере, а не настройка. Маршрут `/refund` без плитки
                  // был бы работой, до которой нельзя дойти нажатием:
                  // браузерная таблица оболочки не имеет, стека переходов у
                  // вкладки нет, и единственным путём остался бы набранный
                  // адрес. Ровно этот дефект уже стоил круга на `/sessions`.
                  //
                  // Право показом, а не запретом нажатия. Границу держит не
                  // показ: `redirect` браузерной таблицы проверяет
                  // `nav.refund`, а сами операции возврата охраняет касса
                  // ключами `op.refund` и `op.refundWithoutReceipt`
                  // (задача 19). Скрытая кнопка правом не является.
                  if (canOpenRefund) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.assignment_return,
                          title: l10n.navRefund,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.refund),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  // Задача 13: продажа переехала в браузерную таблицу
                  // маршрутов, и эта плитка перестала быть обещанием.
                  //
                  // До неё здесь стоял значок часов и подпись «экран
                  // продажи читает базу кассы напрямую и под браузер пока
                  // не собирается» — правда на тот день. Нажать было
                  // нельзя, и это было честно. Теперь и плитка, и подпись
                  // говорят про то, как есть: право показом (`nav.sale`),
                  // тем же приёмом, что у плиток выше.
                  //
                  // Порядок плиток решён слиянием: возврат выше продажи,
                  // потому что ветвь задачи 20 ставила его над **обещанием**
                  // продажи, а не над рабочей плиткой, и «выше» там значило
                  // «первое рабочее». Обе рабочие — первой идёт та, что
                  // пришла раньше по плану.
                  if (canSell) ...[
                    SettingsSection(
                      footer: l10n.terminalHomeSaleNote,
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.point_of_sale,
                          title: l10n.navSale,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.sale),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppTokens.space16),
                  // Приём аванса — требование заказчика 2026-09-18. Плитка
                  // здесь по тому же доводу, каким её получил возврат:
                  // маршрут без плитки — это работа, до которой нельзя
                  // дойти нажатием, потому что оболочки у браузерной
                  // таблицы нет и стека переходов у вкладки тоже.
                  //
                  // Ниже продажи: приём аванса случается реже, чем чек, и
                  // первым кассир ищет не его.
                  if (canTakePrepayment) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.savings,
                          title: l10n.prepaymentIntakeTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.prepayment),
                        ),
                      ],
                    ),
                  ],
                  // Выпуск сертификата — дыра 1 ревизии 2026-09-19. Плитка
                  // здесь по тому же доводу, каким её получили возврат и
                  // приём аванса: маршрут без плитки — это работа, до
                  // которой нельзя дойти нажатием, потому что оболочки у
                  // браузерной таблицы нет и стека переходов у вкладки
                  // тоже. Ниже аванса: бумажку выписывают реже, чем берут
                  // деньги вперёд.
                  if (canIssueCertificate) ...[
                    SettingsSection(
                      children: [
                        SettingsTile(
                          metrics: metrics,
                          icon: Icons.card_giftcard,
                          title: l10n.certificateIssueTitle,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => context.go(AppRoutes.certificateIssue),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppTokens.space24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(_logout(context, ref)),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.loginLogout),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        minimumSize: const Size(
                          double.infinity,
                          AppTokens.rowHeightTouch,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Гасит сеанс и уводит на вход.
  ///
  /// [LoginNotifier.logout] чистит `AppState` (и вместе с ним — право
  /// `settings.hardware`, если оно было) и токен вкладки **первым делом**,
  /// не дожидаясь кассы, и лишь затем — без `await` — сообщает ей
  /// (`AuthRepository.logout`); переход на `/login` следует сразу за этим.
  /// Выход обязан состояться независимо от кассы: у обмена с ней нет ни
  /// таймаута, ни отмены (`WtDispatcher.ask`), и молчащий провод не имеет
  /// права держать кнопку выхода нерабочей. Касса узнаёт о выходе, если
  /// ответит; если нет — сеанс там всё равно погаснет сам по истечении
  /// бездействия.
  ///
  /// До появления [LoginNotifier.logout] здесь чистился только `AppState`:
  /// ни касса, ни `sessionStorage` о выходе не узнавали — сеанс на кассе
  /// оставался живым до истечения бездействия, а токен пережил бы саму
  /// вкладку.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(loginControllerProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

/// Значок состояния смены — **живой**, а не снимок входа.
///
/// # Что он чинил
///
/// Замерено живьём 2026-09-18: дом браузерного терминала показывал «Смена
/// открыта» зелёным значком и при просроченной смене. Значение бралось из
/// `AppState.shift`, а туда оно попадало **один раз** — из `AuthSession`,
/// выписанного при входе (`SessionRegistry.mint`, `shiftOpen`). Ни одной
/// операции провода про смену в каталоге не было, поэтому ни закрытие смены
/// на кассе, ни переход суток на вкладку не доезжали никак: значок оставался
/// зелёным до перезагрузки страницы, и кассир узнавал о беде, только
/// упершись в продажу.
///
/// Теперь состояние приходит подпиской (`TillOps.shiftState`), и у значка
/// **три состояния вместо двух**: закрыта, открыта, открыта дольше суток.
/// Третье — то самое, которого не было: смена формально открыта, а продажа
/// уже заперта, и зелёная галочка тут прямая ложь.
///
/// # Возраст смены не считается здесь
///
/// `overAge` приходит с кассы готовым. Предел (сутки, сравнение `>=`) живёт
/// в `ShiftAgeRule` — том самом правиле, которым касса **запирает продажу**.
/// Посчитай вкладка возраст сама, значок говорил бы одно, а продажа другое:
/// две арифметики над одним вопросом расходятся на первой же правке предела.
///
/// # Откуда берётся значение, пока подписка не ответила
///
/// [atLogin] — то, что приехало в сеансе. Это по-прежнему снимок, но он
/// честен ровно в тот миг, когда других сведений нет, и лучше пустого места:
/// первый кадр подписки приходит не мгновенно, а дом строится сразу после
/// входа. Как только кадр пришёл, снимок больше не читается ни разу.
///
/// Порт может быть не привязан вовсе (кассовая сборка этого экрана не
/// открывает, но собрать его можно) — тогда остаётся снимок, и это
/// единственное, что у такой сборки есть.
class _ShiftTile extends StatefulWidget {
  const _ShiftTile({
    required this.metrics,
    required this.atLogin,
    required this.canOpenShift,
  });

  final WizardMetrics metrics;

  /// Состояние смены, приехавшее в `AuthSession` при входе.
  final ShiftStatus atLogin;

  /// Есть ли право `nav.shift`. Без него плитка не ведёт никуда — показом, а
  /// не запретом нажатия: скрытая кнопка правом не является (И162), и
  /// границу держит `redirect` таблицы вместе с тремя операциями кассы.
  final bool canOpenShift;

  @override
  State<_ShiftTile> createState() => _ShiftTileState();
}

/// # Почему плитка со своим состоянием, а не `StatelessWidget`
///
/// Ради **одной подписки на весь открытый экран**. `watch()` — настоящая
/// подписка на кассу (`TillOps.shiftState`), а дом терминала перерисовывается
/// от `ref.watch(appStateProvider)` при всякой перемене сеанса. Поток,
/// созданный в `build`, заводил бы новую подписку на каждую такую
/// перерисовку, и снимал бы их только уход вкладки.
class _ShiftTileState extends State<_ShiftTile> {
  ShiftDeskRepository? get _desk => GetIt.I.isRegistered<ShiftDeskRepository>()
      ? GetIt.I<ShiftDeskRepository>()
      : null;

  late final Stream<ShiftDeskView>? _state = _desk?.watch();

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return _fromSnapshot(context);
    return StreamBuilder<ShiftDeskView>(
      stream: state,
      builder: (context, snapshot) {
        final view = snapshot.data;
        if (view == null) return _fromSnapshot(context);
        return _tile(
          context,
          // Три состояния, а не два: просроченная смена — своё.
          state: !view.open
              ? _ShiftLook.closed
              : view.overAge
              ? _ShiftLook.overAge
              : _ShiftLook.open,
        );
      },
    );
  }

  Widget _fromSnapshot(BuildContext context) => _tile(
    context,
    state: switch (widget.atLogin) {
      ShiftStatus.open => _ShiftLook.open,
      ShiftStatus.closed => _ShiftLook.closed,
      ShiftStatus.unknown => _ShiftLook.unknown,
    },
  );

  Widget _tile(BuildContext context, {required _ShiftLook state}) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsTile(
      metrics: widget.metrics,
      icon: switch (state) {
        _ShiftLook.open => Icons.lock_open,
        // У просроченной смены замок **открыт**, как и у обычной: смена и
        // правда открыта. Беду называет правая половина плитки и подпись, а
        // не левый значок — иначе кассир прочёл бы «смена закрыта».
        _ShiftLook.overAge => Icons.lock_open,
        _ShiftLook.closed => TeleposIcons.lock,
        _ShiftLook.unknown => Icons.help_outline,
      },
      title: l10n.navShift,
      value: switch (state) {
        _ShiftLook.open => l10n.loginShiftOpen,
        _ShiftLook.overAge => l10n.shiftOverAgeTitle,
        _ShiftLook.closed => l10n.loginShiftClosed,
        _ShiftLook.unknown => l10n.loginShiftUnknown,
      },
      trailing: Icon(
        switch (state) {
          _ShiftLook.open => TeleposIcons.checkCircle,
          _ShiftLook.overAge => Icons.warning_amber_rounded,
          _ShiftLook.closed => Icons.radio_button_unchecked,
          _ShiftLook.unknown => Icons.help_outline,
        },
        color: switch (state) {
          _ShiftLook.open => AppColors.success,
          _ShiftLook.overAge => AppColors.warning,
          _ShiftLook.closed => AppColors.warning,
          _ShiftLook.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
        },
      ),
      // Плитка обязана **вести**, а не только показывать: маршрут без
      // перехода — работа, до которой нельзя дойти нажатием (оболочки у
      // браузерной таблицы нет, стека переходов у вкладки тоже), и сторож
      // `browser_routes_test` красит именно это.
      onTap: widget.canOpenShift
          ? () => context.go(AppRoutes.terminalShift)
          : null,
    );
  }
}

/// Как выглядит смена на доме терминала. Три состояния, а не два — разбор в
/// докстринге [_ShiftTile].
enum _ShiftLook { open, overAge, closed, unknown }
