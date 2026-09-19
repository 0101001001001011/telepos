import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `isRegistered<…>` в презентационном слое — только поимённо и с доводом.
/// Задача 45.
///
/// # Почему сторож
///
/// Проверка «зарегистрирован ли договор» у экрана — это развилка «есть
/// привязка / нет привязки», и у неё два законных исхода и один дефектный:
///
/// - **законно**: отсутствие — состояние кассы (не подключены весы, не
///   настроен Telegram, стенд без эмулятора), и экран его **называет** или
///   ему нечего показывать;
/// - **дефект**: отсутствие — ошибка сборки контейнера, а экран прячет
///   кнопку или молча берёт умолчание. Так «Быстрые товары» в браузере
///   пропадали без слова, «Редактировать» делал скидку недостижимой, а
///   правила сканера молча откатывались к зашитым длинам кода.
///
/// Разобрать довод текстом сторож не может — поэтому список: каждая
/// развилка названа по файлу и договору, с числом вхождений и доводом.
/// Новая краснеет, пока её не впишут сознательно; исчезнувшая краснеет как
/// устаревшая запись.
///
/// # Разбор 2026-09-15 (задача 45)
///
/// На `9ac079a5` — 61 строка с `isRegistered<` в `lib/presentation`, из них
/// одна в докстринге (`sale_controller.dart`, история `DiscountPolicy`). Путь
/// продажи, оплаты и возврата разобран: закрыты пять —
/// `sale_screen.dart: QuickProductCatalog` (проводная реализация, кнопка
/// стоит всегда), `barcode_scanner_mixin.dart: ScannerRulesRepository`
/// (проводной `ScannerRulesReader`), и три проверки того же миксина на
/// `TerminalRepository`/`DeviceBindingRepository`/`DeviceProfileCatalog`
/// (привязаны в обеих точках входа, проверка была мёртвой). Остальные — ниже.
const _allowed = <String, ({int count, String reason})>{
  // ── диагностика оборудования ──────────────────────────────────────────────
  //
  // **Четыре записи ЗАКРЫТЫ 2026-09-19** пунктом «Достижимость с браузерного
  // терминала» плана `2026-09-19-hardware-diagnostics.md`.
  //
  // Было: вкладка принтера спрашивала `PrintQueue` и `ReceiptPrintService`,
  // вкладка фискализации — `AppDatabase` и `FiscalQueueStore`. Три из четырёх
  // договоров живут в `lib/data/` и `lib/hardware/`, которых в браузерной
  // сборке быть не может, и на планшете обе вкладки честно говорили, что
  // показывать нечем. Формулировка стояла «закрывается операциями провода на
  // чтение диагностики» — этой работой она и закрыта.
  //
  // Стало: между вкладкой и кассой стоит один доменный порт
  // `HardwareDiagnosticsRepository` с двумя реализациями —
  // `LocalHardwareDiagnostics` и `WtHardwareDiagnostics`. Развилка осталась
  // **одна на вкладку**, и она законна по тому же доводу, что у экранов
  // шаблона чека ниже: сборка без привязанного порта существует (голый
  // процесс `bin/telepos_backend.dart` без контейнера зависимостей), и такой
  // сборке вкладка говорит словами `errorDiagnosticsUnavailable`.
  //
  // Различать «порта нет» и «печатать нечем» обязательно: первое — про
  // сборку, второе — про кассу, и пустой список вместо любого из них отправил
  // бы наладчика искать беду в принтере, которого никто не спрашивал.
  'lib/presentation/screens/diagnostics/printer_diagnostics_tab.dart: HardwareDiagnosticsRepository': (
    count: 1,
    reason: 'названо: errorDiagnosticsUnavailable',
  ),
  'lib/presentation/screens/diagnostics/fiscal_diagnostics_tab.dart: HardwareDiagnosticsRepository': (
    count: 1,
    reason: 'названо: errorDiagnosticsUnavailable',
  ),
  // Запись `scales_diagnostics_tab.dart: ScalesService` отсюда **снята**
  // пунктом 4 того же плана: вкладка весов больше не знает `ScalesService`
  // вовсе. Вместе с ней на тот же порт переведены вкладки ящика и дисплея —
  // они службу вообще не спрашивали, а брали журнал из `GetIt` без проверки
  // и потому в браузере упали бы, а не сказали словами.
  //
  // Развилка у всех трёх теперь **одна и та же** и тот же довод, что у
  // принтера выше: сборка без привязанного порта существует, и такой сборке
  // вкладка говорит `errorDiagnosticsUnavailable`.
  //
  // «Порта нет», «памяти об импульсах нет» и «ящик не звали» — три разных
  // ответа, и все три названы своими словами: первый этой развилкой, два
  // других значениями (`available`, `bound`) с провода. Свести их в пустой
  // список значило бы отправить наладчика искать обрыв в проводке исправного
  // ящика.
  'lib/presentation/screens/diagnostics/drawer_diagnostics_tab.dart: HardwareDiagnosticsRepository': (
    count: 1,
    reason: 'названо: errorDiagnosticsUnavailable',
  ),
  'lib/presentation/screens/diagnostics/scales_diagnostics_tab.dart: HardwareDiagnosticsRepository': (
    count: 1,
    reason: 'названо: errorDiagnosticsUnavailable',
  ),
  'lib/presentation/screens/diagnostics/display_diagnostics_tab.dart: HardwareDiagnosticsRepository': (
    count: 1,
    reason: 'названо: errorDiagnosticsUnavailable',
  ),
  'lib/presentation/screens/diagnostics/payment_diagnostics_tab.dart: AppDatabase': (
    count: 1,
    reason:
        'ОТКРЫТО: намерения оплаты по коду лежат в базе кассы; на планшете '
        'вкладка говорит «данных об оплате на этом рабочем месте нет». '
        'Закрывается теми же операциями провода на чтение диагностики',
  ),
  'lib/presentation/screens/diagnostics/payment_diagnostics_tab.dart: QrProviderSetupRepository': (
    count: 1,
    reason:
        'адрес провайдера читается у той же стойки, что берёт им деньги; без '
        'неё вкладка не знает ни адреса, ни того, настроен ли провайдер — и '
        'говорит «провайдер QR на этой кассе не настроен», а не молчит пустым '
        'списком. Журнал терминала при этом читается напрямую: он общий на '
        'процесс и есть всегда',
  ),
  // ── продажа, оплата, возврат ──────────────────────────────────────────────
  'lib/presentation/common/mixins/barcode_scanner_mixin.dart: EmulatedScannerSourceFactory': (
    count: 1,
    reason:
        'эмулятор сканера есть только в стендовой сборке кассы; в продукте '
        'и браузере его нет законно',
  ),
  // `sale_controller.dart: BatchTrackingUseCase` и `: WmsConfigUseCase`
  // отсюда сняты — пункт 11 ревизии 2026-09-19. Ревизия предлагала закрыть
  // это «проверкой партии на кассе при добавлении строки», и так и сделано:
  // договор `ExpiryWarningReader` (один вопрос «партия просрочена?»), на
  // кассе за ним `LocalExpiryWarning` поверх тех же двух юзкейсов, в
  // браузере — `WtExpiryWarning` поверх `sale.expiryWarning`. Развилок в
  // контроллере не осталось ни одной.
  'lib/presentation/controllers/app/stock_revision.dart: StockChanges': (
    count: 1,
    reason:
        'подписка на изменение остатков соседнего рабочего места (пункт 12 '
        'ревизии 2026-09-19). Договор есть в обеих сборках продукта, но '
        'счётчик СТАРШЕ подписки: инвентаризация и перемещение поднимают '
        'его напрямую, и контейнер без провода и без базы кассы обязан '
        'работать ровно как до правки — свои изменения видны, чужие нет. '
        'Падение здесь сломало бы каталог у сборки, которой подписка не '
        'нужна; пряталось бы при этом НЕ отсутствие, а дополнение',
  ),
  'lib/presentation/screens/sale/sale_hardware_native.dart: T': (
    count: 1,
    reason:
        'весы, этикетки, дисплей покупателя — отсутствие устройства есть '
        'законное состояние кассы; файл только нативный',
  ),
  'lib/presentation/controllers/refund/refund_controller.dart: CartService': (
    count: 1,
    reason:
        'названо: поиск возврата без корзины отвечает '
        'error.refund_search_unavailable',
  ),
  'lib/presentation/screens/refund/refund_screen.dart: RecentReceipts': (
    count: 1,
    reason:
        'названо: диалог получает recentAvailable=false и говорит о '
        'переносе, а не «чеков нет»',
  ),
  'lib/presentation/screens/refund/refund_screen.dart: CertificateSlipPrinter': (
    count: 1,
    reason:
        'слип новой бумажки печатает КАССА (решение заказчика 2026-09-16), и '
        'беда его печати доходит до кассира отдельным предупреждением рядом '
        'с успехом возврата. Отсутствие порта — законное состояние: у '
        'браузерного терминала его нет вовсе, там печатает касса, и '
        'непринятое задание видно на её экране очереди печати',
  ),
  // ── смена ─────────────────────────────────────────────────────────────────
  'lib/presentation/screens/shift/widgets/shift_actions.dart: ShiftService': (
    count: 1,
    reason:
        'ОТКРЫТО (дорожка смены на кассе): без службы сводка нефискализованных '
        'при закрытии молча пуста',
  ),
  // ── вход ─────────────────────────────────────────────────────────────────
  'lib/presentation/controllers/auth/login_controller.dart: CashierOnDutyHolder': (
    count: 1,
    reason:
        'кто вошёл на кассе — пишет экран входа; в браузере кассир приходит '
        'с сеансом провода, держателя там нет',
  ),
  'lib/presentation/controllers/auth/login_controller.dart: SessionTokenStorage': (
    count: 1,
    reason: 'хранилище токена есть у браузера; у кассы вход без токена',
  ),
  'lib/presentation/controllers/auth/login_controller.dart: TerminalSecretStorage': (
    count: 1,
    reason: 'секрет терминала есть только у браузерной вкладки',
  ),
  'lib/presentation/controllers/app/current_user_provider.dart: AppDatabase': (
    count: 1,
    reason: 'читатель — чат персонала на кассе; в браузере базы нет',
  ),
  // ── фискализация ─────────────────────────────────────────────────────────
  'lib/presentation/screens/fiscal/unfiscalized_receipts_screen.dart: FiscalProviderRegistry': (
    count: 1,
    reason: 'экран только кассы; без реестра повтор назван «оператор не настроен»',
  ),
  'lib/presentation/screens/fiscal/unfiscalized_receipts_screen.dart: FiscalSettingsSource': (
    count: 1,
    reason: 'та же развилка экрана нефискализованных',
  ),
  'lib/presentation/screens/fiscal/widgets/orphan_qr_money_panel.dart: AppDatabase': (
    count: 1,
    reason: 'панель только кассы; в браузере базы нет',
  ),
  'lib/presentation/screens/settings/fiscal_settings_screen.dart: FiscalQueueStore': (
    count: 1,
    reason: 'счётчик очереди фискализации; без очереди — ноль законно',
  ),
  // ── настройки кассы ──────────────────────────────────────────────────────
  // `ScannerRulesRepository` здесь **больше не записан** — пункт 11 ревизии
  // 2026-09-19. Запись правил сканера приехала на провод
  // (`TillOps.scannerRulesSave`), `WtScannerRules` реализует пишущий договор
  // целиком, и `main_web.dart` привязывает его. Запись, оставленная тут,
  // краснела бы как устаревшая — это тоже сторож.
  'lib/presentation/screens/settings/hardware_settings_screen.dart: DeviceDiscovery': (
    count: 1,
    reason: 'названо: deviceSearchUnavailable',
  ),
  'lib/presentation/screens/settings/hardware_settings_screen.dart: DeviceCheck': (
    count: 1,
    reason: 'названо: проверка устройства недоступна',
  ),
  'lib/presentation/screens/settings/printer_settings_screen.dart: PrintQueue': (
    count: 1,
    reason: 'названо: printQueueUnavailable',
  ),
  // Решение заказчика 2026-09-18: оба экрана шаблона перестали спрашивать
  // `ReceiptPrintService` и `AppDatabase` — между ними и кассой встал
  // доменный порт с двумя реализациями (кассовая и провод). Прежние две
  // записи про `ReceiptPrintService` сняты вместе с вызовами.
  //
  // Развилка осталась одна на экран и **законна**: сборка без привязанного
  // порта существует (голая касса без контейнера зависимостей), и такой
  // сборке экран говорит словами `errorReceiptTemplatesUnavailable`. Пустой
  // список вместо слов был бы хуже: «шаблонов нет» и «спросить не у кого» —
  // для владельца разные вещи, и на первом он завёл бы второй шаблон
  // поверх невидимого первого.
  'lib/presentation/screens/settings/receipt/receipt_templates_screen.dart: ReceiptTemplateSetupRepository': (
    count: 1,
    reason: 'названо: errorReceiptTemplatesUnavailable',
  ),
  'lib/presentation/screens/settings/receipt/receipt_template_editor_screen.dart: ReceiptTemplateSetupRepository': (
    count: 1,
    reason: 'названо: errorReceiptTemplatesUnavailable',
  ),
  // Смена с браузерного терминала — решение заказчика того же дня. Та же
  // развилка и тот же довод: на доме терминала без порта остаётся снимок
  // входа (единственное, что у такой сборки есть), на экране смены —
  // фраза `errorShiftDeskUnavailable`.
  'lib/presentation/screens/terminal/terminal_home_screen.dart: ShiftDeskRepository': (
    count: 1,
    reason: 'без порта значок остаётся снимком входа — названо в докстринге',
  ),
  'lib/presentation/screens/terminal/terminal_shift_screen.dart: ShiftDeskRepository': (
    count: 1,
    reason: 'названо: errorShiftDeskUnavailable',
  ),
  'lib/presentation/controllers/settings/qr_payment_setup_controller.dart: QrProviderSetupRepository': (
    count: 1,
    reason: 'настройка провайдера QR — только на кассе',
  ),
  'lib/presentation/screens/settings/emulator_settings_screen.dart: QrProviderSetupRepository': (
    count: 1,
    reason:
        'встроенный эмулятор QR вписывает адрес в настройку провайдера — ту же '
        'самую, что правит экран настройки QR. Стойки может не быть вовсе '
        '(голая касса без контейнера, браузерная половина): тогда адрес '
        'по-прежнему показан и его можно вписать руками, а кнопка «вписать» не '
        'показывается. Прятать число было бы хуже, чем прятать кнопку',
  ),
  'lib/presentation/controllers/settings/auth_settings_controller.dart: SessionRegistry': (
    count: 1,
    reason: 'реестр сеансов живёт в процессе кассы',
  ),
  'lib/presentation/controllers/settings/auth_settings_controller.dart: SecurityJournal': (
    count: 1,
    reason: 'журнал безопасности кассы; запись — лучшее усилие',
  ),
  'lib/presentation/controllers/settings/auth_settings_controller.dart: Talker': (
    count: 1,
    reason: 'журнал приложения при записи отказа',
  ),
  'lib/presentation/screens/settings/user_management_screen.dart: SessionRegistry': (
    count: 1,
    reason: 'реестр сеансов живёт в процессе кассы',
  ),
  'lib/presentation/screens/settings/user_management_screen.dart: SecurityJournal': (
    count: 1,
    reason: 'журнал безопасности кассы; запись — лучшее усилие',
  ),
  'lib/presentation/screens/settings/user_management_screen.dart: Talker': (
    count: 1,
    reason: 'журнал приложения при записи отказа',
  ),
  // ── заставка ─────────────────────────────────────────────────────────────
  'lib/presentation/screens/splash/splash_screen.dart: FirstLaunchRepository': (
    count: 1,
    reason: 'первый запуск спрашивается там, где договор привязан',
  ),
  'lib/presentation/screens/splash/splash_screen.dart: BuildConfig': (
    count: 1,
    reason: 'версия на заставке; без конфигурации сборки — без номера',
  ),
  // ── склад и отчёты ───────────────────────────────────────────────────────
  'lib/presentation/controllers/supply/supply_controller.dart: WmsConfigUseCase': (
    count: 1,
    reason: 'склад включается конфигурацией кассы',
  ),
  'lib/presentation/screens/reports/tabs/products_tab.dart: WmsConfigUseCase': (
    count: 1,
    reason: 'отчёт по складу — только при включённом складе',
  ),
  'lib/presentation/controllers/reports/kz_reports_controller.dart: CalculateCogsUseCase': (
    count: 1,
    reason: 'себестоимость — при собранном модуле; иначе отчёт без неё',
  ),
  'lib/presentation/screens/wms/marking_codes_screen.dart: IsMptService': (
    count: 1,
    reason: 'ИС МПТ подключается настройкой',
  ),
  // ── синхронизация и Telegram ─────────────────────────────────────────────
  'lib/presentation/controllers/sync/sync_controller.dart: LocalProperties': (
    count: 1,
    reason: 'настройки синхронизации — где они заведены',
  ),
  'lib/presentation/controllers/sync/sync_controller.dart: CouchDbSyncCoordinator': (
    count: 1,
    reason: 'транспорт CouchDB включается настройкой',
  ),
  'lib/presentation/controllers/transport/transport_controller.dart: TelegramSyncEngine': (
    count: 1,
    reason: 'транспорт Telegram включается настройкой',
  ),
  'lib/presentation/controllers/transport/transport_controller.dart: CouchDbSyncCoordinator': (
    count: 1,
    reason: 'транспорт CouchDB включается настройкой',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: TelegramInitializer': (
    count: 1,
    reason: 'сброс служб Telegram — тех, что были собраны',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: TelegramAuthService': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: AutoSetupService': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: AutoChannelCreator': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: TdLibClient': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/controllers/telegram/telegram_setup_controller.dart: ChannelRegistry': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/screens/telegram/staff_chat_screen.dart: StaffIdentityService': (
    count: 3,
    reason: 'чат персонала — при подключённом Telegram',
  ),
  'lib/presentation/screens/telegram/staff_chat_screen.dart: Talker': (
    count: 1,
    reason: 'журнал приложения',
  ),
  'lib/presentation/screens/telegram/staff_chat_screen.dart: StaffChatService': (
    count: 1,
    reason: 'чат персонала — при подключённом Telegram',
  ),
  'lib/presentation/screens/telegram/telegram_settings_screen.dart: TelegramAuthService': (
    count: 2,
    reason: 'настройки Telegram — при собранных службах',
  ),
  'lib/presentation/screens/telegram/telegram_settings_screen.dart: ChannelRegistry': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/screens/telegram/telegram_settings_screen.dart: TelegramCredentials': (
    count: 1,
    reason: 'то же',
  ),
  'lib/presentation/screens/telegram/telegram_settings_screen.dart: AutoChannelCreator': (
    count: 1,
    reason: 'то же',
  ),
  // Повтор печати слипа сертификата — дыра 1 ревизии 2026-09-19, порт
  // сменился решением заказчика 2026-09-18.
  //
  // Развилка **законна**: печать слипа необязательна по построению —
  // `LocalCertificateIssuer` принимает её `null`-ом («касса без принтера
  // обязана выпускать сертификаты так же», докстринг
  // `CertificateSlipPrinter`), а голый процесс кассы очереди печати не
  // поднимает вовсе. Экран называет это словами
  // (`certificateSlipUnavailable`), а не прячет кнопку: пропавшая кнопка
  // повтора отправила бы кассира искать беду в принтере, которого никто не
  // спрашивал.
  //
  // **Спрашивается `CertificateSlipReprinter`, а не `CertificateSlipPrinter`
  // (2026-09-18).** Два шага повтора — «найти бумажку» и «отправить слип» —
  // съехали из экрана в порт: во вкладке второй такой связки быть не может,
  // она печатала бы обязательство магазина по своим полям. Браузер под этим
  // портом держит провод (`WtCertificateSlipReprinter`), то есть развилка
  // здесь больше **не** про «в браузере печати нет».
  //
  // Выпуск (`CertificateIssuer`) при этом спрашивается **без** развилки и
  // намеренно: сборка, где выпуска нет, а экран выпуска есть, — это ошибка
  // контейнера, а не состояние кассы, и падение резолва про неё честнее
  // любого «недоступно».
  'lib/presentation/screens/certificate/certificate_issue_screen.dart: CertificateSlipReprinter': (
    count: 1,
    reason: 'названо: certificateSlipUnavailable',
  ),
};

void main() {
  test('каждая развилка isRegistered в презентации названа поимённо', () {
    final ask = RegExp(r'isRegistered<(\w+)>');
    final comments = RegExp(r'//[^\n]*');
    final found = <String, int>{};

    for (final entity in Directory('lib/presentation').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // Докстринг, рассказывающий историю снятой проверки, развилкой не
      // является — иначе сторож наказывал бы за объяснение.
      final code = entity.readAsStringSync().replaceAll(comments, '');
      for (final match in ask.allMatches(code)) {
        final key = '$path: ${match.group(1)}';
        found[key] = (found[key] ?? 0) + 1;
      }
    }

    expect(found, isNotEmpty, reason: 'предпосылка: обход нашёл файлы');

    final unlisted = [
      for (final entry in found.entries)
        if (_allowed[entry.key]?.count != entry.value)
          '${entry.key} ×${entry.value}'
              '${_allowed.containsKey(entry.key) ? ' (в списке ×${_allowed[entry.key]!.count})' : ''}',
    ]..sort();
    expect(
      unlisted,
      isEmpty,
      reason:
          'новая развилка «есть привязка / нет привязки» в презентации: если '
          'отсутствие — ошибка сборки, заведите реализацию и уберите проверку; '
          'если законное состояние — впишите с доводом',
    );

    final stale = [
      for (final key in _allowed.keys)
        if (!found.containsKey(key)) key,
    ]..sort();
    expect(stale, isEmpty, reason: 'развилки больше нет — запись устарела');
  });
}
