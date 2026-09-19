/// Полнота `PermissionKeys.routeToPermissionKey()` против настоящей
/// десктопной таблицы маршрутов — сторож, а не глаза (правка «маршрут →
/// ключ», закрытие долга безопасности, 2026-08-22).
///
/// Задача 17 нашла, что `routeToPermissionKey()` покрывала 15 из 71
/// маршрута и правильно не стала чинить это в маршрутизаторе — вторая карта
/// «маршрут → право» рядом с существующей была бы тем самым дублированием,
/// из-за которого долг и возник. Эта правка расширила саму карту в
/// `permission_keys.dart` восемью `settings.*`-маршрутами и сделала
/// сопоставление по префиксу, а не по равенству (`/tables/:tableId` и
/// подобные). Но расширение вручную — то же самое «на глаз», которым
/// покрытие уже один раз разошлось с таблицей: этот тест обходит **все**
/// маршруты, реально зарегистрированные в `_buildRoutes()` (через
/// `createRouter().configuration.routes`, а не производные списки
/// `AppRoutes.shellRoutes`/`standaloneRoutes` — они, как нашла задача 17,
/// разошлись с самой таблицей), и требует, чтобы у каждого было **решение**: ключ права,
/// запись в `AppRoutes.publicRoutes`, либо запись в
/// `_intentionallyOpenRoutes` ниже — с обоснованием.
///
/// Новый маршрут, добавленный в `_buildRoutes()` без решения, попадает ни в
/// одну из трёх корзин — и красит этот тест, а не остаётся тихим пробелом.
///
/// # Счёт с тех пор рос ещё трижды
///
/// Задачи 18/19 добавили `/auth-settings` и `/sessions` (оба — ключ
/// `settingsUsers`), подняв таблицу `_buildRoutes()` с 72 до 74 записей.
/// Правка «второй порядок» закрытия долга безопасности (2026-08-22, пункт
/// 1) связала ещё три маршрута, которые не были закрыты вообще ничем —
/// `/terminal-service-settings`, `/log-journal`, `/appliance-settings`.
/// Финальная волна правок (блокер 2) нашла восьмой лживый случай: `/telegram
/// -setup` значился «нет ключа права ни для одной роли», хотя
/// `settingsTelegram` уже существовал и был связан с соседним
/// `/telegram-settings` — связан тем же ключом, а не оставлен открытым.
/// Итог на 2026-08-22: 32 из 74 маршрутов имели ключ права (15 nav +
/// 8 settings правки «маршрут → ключ» + 2 settingsUsers задач 18/19 + 3
/// правки «второй порядок» + `/telegram-setup` блокера 2 + 3
/// параметрических по префиксу).
///
/// Задача 2 работы «знакомство терминала с кассой» (2026-08-23) добавила
/// `/terminal-pairing` (ключ `settingsUsers` — тот же периметр «кто и как
/// входит в кассу», что и у `/sessions`/`/auth-settings`) и подняла оба
/// числа на единицу: таблица `_buildRoutes()` — с 74 до **75** маршрутов,
/// покрытие — с 32 до **33**. Докстринги здесь и в `app_router.dart` не
/// обновились в тот же момент — разошедшийся текст вписан в
/// `docs/internal/ROADMAP.md` и закрыт этой правкой (измерено 2026-08-27: `grep -c
/// 'path: AppRoutes\.' lib/app/router/app_router.dart` даёт 75, обход
/// `createRouter().configuration.routes` с фильтром по
/// `routeToPermissionKey() != null` — 33).
///
/// Ревизия 2026-09-19 добавила два маршрута, оба с ключом, подняв счёт с
/// **81/42** до **83/44**: `/certificate-issue` (`op.issueCertificate` —
/// выпуск подарочного сертификата, дыра 1) и `/prepayment-refund`
/// (`op.creditRepay` — выдача аванса деньгами, дыра 2). Оба — случаи одной
/// породы: работа написана целиком, охранялась правом и покрыта пробами, но
/// кассиру недостижима, потому что двери не существовало (`ProductType` не
/// упоминался в `lib/presentation/` ни разу; `refundPrepayment` не звал ни
/// один экран). Поимённый разбор каждого — у своей проверки ниже.
///
/// Число не поддерживается вручную нигде, кроме этого абзаца и проверки
/// «счёт таблицы не расходится с фактом» ниже — но сама проверка теперь
/// сверяет **точное** число, а не диапазон: `greaterThan(60)` не покраснел
/// бы, укради кто-то из таблицы хоть полтора десятка маршрутов, то есть
/// охранял бы только собственное существование теста, а не факт. Точное
/// число здесь — тот же протокол, каким в `docs/internal/testing-notes.md`, раздел
/// «Порог», держится порог всего набора: число не должно уменьшаться без
/// объяснения, а рост — объясняться поимённо (какой маршрут добавлен и с
/// каким решением), а не сдвигом среднего.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telepos/app/router/app_router.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/core/constants/permission_keys.dart';

/// Обходит дерево маршрутов рекурсивно (`ShellRoute` не сама `GoRoute`, её
/// `path` не читается — только вложенные `routes`, у любого `RouteBase`).
List<String> _allGoRoutePaths(List<RouteBase> routes) {
  final result = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      result.add(route.path);
    }
    result.addAll(_allGoRoutePaths(route.routes));
  }
  return result;
}

/// Маршруты без ключа права, оставленные достижимыми любому вошедшему
/// **намеренно** — решение, а не пробел. Каждая запись обоснована.
///
/// Общее обоснование для помеченных «нет ключа права ни для одной роли»:
/// `PermissionKeys.allPermissions`/`roleDefaults` не моделирует право для
/// этого экрана вовсе — «не пускать по умолчанию» здесь значило бы завести
/// новый запрет там, где раньше не было даже показа/скрытия пункта меню, и
/// заперло бы владельца (единственная роль без обхода через ключ, которого
/// не существует) от собственного экрана. Это тот же протокол, которым
/// задача 17 объяснила исходные 49 маршрутов без ключа
/// («Решение про маршрут без ключа: пускать»); список
/// ниже — исчерпывающая, поимённая версия того же решения, а не общее
/// «маршрут без ключа = открыт навсегда»: восемь `settings.*`-маршрутов,
/// которые уже получили ключ этой правкой, в этом списке не значатся.
const Map<String, String> _intentionallyOpenRoutes = {
  // Поток продажи/оплаты — не пункт бокового меню, эти два открываются
  // только изнутри `/sale`/`/refund`; отдельного ключа права для них в
  // системе нет — вход уже требуется тем же `redirect`.
  AppRoutes.payment: 'часть потока продажи, вызывается только из /sale',
  AppRoutes.customerDisplay:
      'витринный экран, вызывается только из потока оплаты',

  // Складские операции — нет ключа права ни для одной роли.
  AppRoutes.shiftHistory: 'нет ключа права ни для одной роли',
  AppRoutes.stockRegistry: 'нет ключа права ни для одной роли',
  AppRoutes.supplierOrder: 'нет ключа права ни для одной роли',
  AppRoutes.markupSettings: 'нет ключа права ни для одной роли',
  // `/promotions` ушёл отсюда задачей 19 плана «полнота продажи»
  // (2026-09-07): экран акций получил единственный вход (пункт меню в
  // настройках) и вместе с ним ключ `op.editPrice` — акция это постоянно
  // действующее изменение цены, тот же периметр, что и разовая правка цены
  // в чеке; довод целиком — в `permission_keys.dart`, над записью
  // `'/promotions'`.
  AppRoutes.movement: 'нет ключа права ни для одной роли',
  AppRoutes.supplierReturn: 'нет ключа права ни для одной роли',
  AppRoutes.reorderRules: 'нет ключа права ни для одной роли',
  AppRoutes.writeoff: 'нет ключа права ни для одной роли',
  AppRoutes.inventory: 'нет ключа права ни для одной роли',

  // Настройки/системные экраны — нет ключа права ни для одной роли.
  //
  // `/terminal-service-settings`, `/log-journal`, `/appliance-settings`
  // ушли отсюда правкой «второй порядок» закрытия долга безопасности
  // (2026-08-22, пункт 1) — раньше это были три маршрута без защиты ничем:
  // ни ключа права, ни `ownerOnlyScaffold`. Теперь у каждого свой ключ
  // (`settingsTerminalService`/`settingsLogJournal`/`settingsAppliance`) —
  // см. тест ниже, «три маршрута без ключа и без ownerOnlyScaffold».
  AppRoutes.labelPrinterSettings: 'нет ключа права ни для одной роли',
  AppRoutes.labelTemplates: 'нет ключа права ни для одной роли',
  AppRoutes.labelTemplateEdit: 'нет ключа права ни для одной роли',
  // `/receipt-templates` и `/receipt-templates/edit` ушли отсюда решением
  // заказчика 2026-09-18: шаблон чека стал достижим с браузерного терминала,
  // а `redirect` браузерной таблицы проверяет право маршрута — без записи
  // экран открылся бы любому вошедшему. Ключ существующий,
  // `settings.printer`: тот же, что у `/printer-settings`, задающего ширину
  // ленты, без которой шаблон не имеет смысла. Довод целиком — в
  // `permission_keys.dart`, над записью `'/receipt-templates'`. Одной записи
  // хватает на оба: `routeToPermissionKey` сопоставляет **по префиксу**.
  // `/system-management` и `/system-terminal` остаются здесь: они закрыты
  // ДРУГИМ механизмом — `ownerOnlyScaffold` (`system_management_screen
  // .dart`, `system_terminal_screen.dart` проверяют роль виджетом
  // напрямую), а не ключом права. Оставлены намеренно открытыми для этого
  // теста (он проверяет только маршрутизацию), а не забыты — в отличие от
  // трёх выше, у которых до этой правки не было ни одной защиты.
  AppRoutes.systemManagement: 'нет ключа права; закрыт ownerOnlyScaffold',
  AppRoutes.systemTerminal: 'нет ключа права; закрыт ownerOnlyScaffold',

  // Документы ЕСФ/СНТ/ЕСУТД/ISMPT — регуляторная интеграция, ключа права
  // ни для одной роли не заведено.
  AppRoutes.esfSettings: 'нет ключа права ни для одной роли',
  AppRoutes.esfOutbox: 'нет ключа права ни для одной роли',
  AppRoutes.snt: 'нет ключа права ни для одной роли',
  AppRoutes.sntSettings: 'нет ключа права ни для одной роли',
  AppRoutes.esutd: 'нет ключа права ни для одной роли',
  AppRoutes.esutdSettings: 'нет ключа права ни для одной роли',
  AppRoutes.ismptSettings: 'нет ключа права ни для одной роли',

  // Прочее без права в модели.
  AppRoutes.additional:
      'нет ключа права ни для одной роли; хаб плиток на прочие экраны',
  AppRoutes.staffChat: 'нет ключа права ни для одной роли',
  AppRoutes.serviceCatalog: 'нет ключа права ни для одной роли',

  // WMS-модуль целиком — нет ключа права ни для одной роли.
  AppRoutes.wmsDashboard: 'нет ключа права ни для одной роли',
  AppRoutes.wmsWarehouses: 'нет ключа права ни для одной роли',
  AppRoutes.wmsBatches: 'нет ключа права ни для одной роли',
  AppRoutes.wmsSerials: 'нет ключа права ни для одной роли',
  AppRoutes.wmsCellStock: 'нет ключа права ни для одной роли',
  AppRoutes.wmsClaims: 'нет ключа права ни для одной роли',
  AppRoutes.wmsMarking: 'нет ключа права ни для одной роли',
  AppRoutes.wmsSettings: 'нет ключа права ни для одной роли',
};

/// Производит имя ключа, каким его называла бы `_routePermissions`, будь
/// маршрут связан с ключом семьи `settings.*` по той же схеме именования,
/// что и восемь уже связанных этой правкой (`/foo-settings` →
/// `settings.foo`). `null`, если путь не оканчивается на `-settings`/
/// `-setup` — тогда у него нет очевидного кандидата, и проверка ниже его не
/// трогает: не всякий маршрут без ключа — часть семьи `settings.*`
/// (складские операции, документы ЕСФ/СНТ/ЕСУТД, WMS).
///
/// `/label-printer-settings` → `settings.labelPrinter`,
/// `/telegram-setup` → `settings.telegram`.
String? _settingsKeyGuessFor(String route) {
  final segments = route.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final last = segments.last.split('-');
  if (last.length < 2) return null;
  final suffix = last.last;
  if (suffix != 'settings' && suffix != 'setup') return null;

  final topicWords = last.sublist(0, last.length - 1);
  if (topicWords.isEmpty) return null;
  final topic = topicWords.first + topicWords.skip(1).map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join();
  return 'settings.$topic';
}

void main() {
  group(
    'PermissionKeys.routeToPermissionKey — полнота против настоящей таблицы',
    () {
      late List<String> allRoutes;

      setUpAll(() {
        allRoutes = _allGoRoutePaths(createRouter().configuration.routes);
      });

      test(
        'счёт таблицы маршрутов и её покрытия ключами права не расходится '
        'с фактом (порог — точное число, а не диапазон)',
        () {
          // Точное число, а не `greaterThan(...)` — тем же протоколом, каким
          // в docs/internal/testing-notes.md, раздел «Порог», держится порог всего
          // набора: число не должно уменьшаться незамеченным, а расти —
          // обязано объясняться поимённо (какой маршрут добавлен, с каким
          // решением), а не средним. Диапазон здесь однажды уже соврал:
          // `greaterThan(60)` стоял, пока факт (74, затем 75 маршрутов; 32,
          // затем 33 покрытых) ушёл на полтора десятка вперёд — тест
          // оставался зелёным ровно потому, что охранял только собственное
          // существование, а не число. Проверено обратным ходом при этой
          // правке: с фиктивным лишним маршрутом в `_buildRoutes()` без
          // записи в `_routePermissions`/`publicRoutes`/
          // `_intentionallyOpenRoutes` эта проверка красит первой — раньше,
          // чем тест «каждый маршрут — решение» ниже успевает пожаловаться
          // на конкретное имя.
          //
          // 75 маршрутов зарегистрировано в _buildRoutes() на 2026-08-27
          // (grep -c 'path: AppRoutes\.' lib/app/router/app_router.dart), 33
          // из них имеют ключ права через routeToPermissionKey() (измерено
          // тем же обходом, что и allRoutes выше, с фильтром по
          // `!= null`) — было 74/32 до задачи 2 работы «знакомство
          // терминала с кассой» (2026-08-23, `/terminal-pairing`, ключ
          // `settingsUsers`), см. докстринг файла.
          // 75 → 76: задача 11 плана «полнота продажи» (2026-09-07)
          // завела `/unfiscalized-receipts` — один экран нефискализованных
          // чеков, единственный вход в него из экрана фискальных настроек.
          // 76 → 77: задача 12 того же плана завела `/discount-limits` —
          // экран пределов ручной скидки, единственный вход в него пунктом
          // «Пределы скидки» в общих настройках. Экран входит **той же
          // работой**, что и таблица `DiscountLimits`: таблица без экрана
          // стала бы четвёртой колонкой без читателя вслед за тремя
          // `usersAllowedTo*` в `ThisPosEntries`.
          // 77 → 78: задача 24 того же плана завела `/credit-contracts` —
          // договоры рассрочки покупателя, единственный вход в них кнопкой
          // «Рассрочки» в карточке контрагента. Экран входит **той же
          // работой**, что и таблицы `CreditContracts`/
          // `CreditScheduleEntries`: без него договор писался бы продажей
          // и читался бы ниоткуда — пятая колонка без читателя вслед за
          // тремя `usersAllowedTo*` и `sellInDebt`.
          //
          // Маршрут, а не `MaterialPageRoute` из диалога: право
          // `op.creditRepay` проверяет `redirect` по этой самой карте, и
          // экран, вытолкнутый мимо таблицы, прошёл бы мимо проверки
          // целиком.
          //
          // 78 → 79: пункт 8 C плана «продажи: что осталось» (2026-09-15)
          // завёл `/qr-provider-settings` — настройку провайдера QR и
          // выключатель вида оплаты 6, единственный вход пунктом «Оплата по
          // QR» в общих настройках. До экрана строку `qr_provider_configs`
          // писала только дверь стенда.
          //
          // 79 → 80: первый пункт плана встроенных эмуляторов (2026-09-19)
          // завёл `/emulator-settings` — выключатель встроенного эмулятора
          // принтера и показ его адреса. Экран настраивает сокеты ЭТОЙ
          // машины, поэтому живёт только в десктопной таблице, как и
          // `/terminal-service-settings`.
          //
          // 80 → 81: пункт плана диагностики (2026-09-19) завёл
          // `/diagnostics` — контейнер вкладок «Принтер» и «Фискализация».
          // Сами вкладки были написаны раньше и до этого дня не были
          // достижимы ни одним переходом: экраны без маршрута.
          //
          // 81 → 82: дыра 1 ревизии 2026-09-19 завела `/certificate-issue`
          // — выпуск подарочного сертификата и повтор печати его слипа.
          // Вход один: плитка «Выпуск подарочного сертификата» на экране
          // «Дополнительно». До этого маршрута право `op.issueCertificate`
          // охраняло операцию, которой кассир не мог вызвать ничем:
          // `ProductType` не упоминался в `lib/presentation/` ни разу.
          //
          // 82 → 83: дыра 2 той же ревизии завела `/prepayment-refund` —
          // выдачу аванса деньгами. Вход один: кнопка «Выдать аванс» в
          // карточке контрагента, соседняя с приёмом. Юзкейс
          // (`CustomerPaymentUseCase.refundPrepayment`) был заведён
          // 2026-09-19 целиком и до этого маршрута не звался ни одним
          // экраном: деньги, внесённые вперёд, вернуть было нечем.
          expect(
            allRoutes.length,
            83,
            reason:
                'Число маршрутов в _buildRoutes() изменилось. Если добавлен '
                'новый маршрут — обнови это число и докстринг файла '
                'поимённо (какой маршрут, зачем); если маршрут удалён — то '
                'же самое, а не молчаливое уменьшение порога.',
          );

          final coveredCount = allRoutes
              .where((r) => PermissionKeys.routeToPermissionKey(r) != null)
              .length;
          // 33 → 34: задача 19 плана «полнота продажи» (2026-09-07) связала
          // `/promotions` с `op.editPrice`. Маршрут не добавлялся — он был
          // в таблице всё это время, без единого перехода из `lib/` и без
          // ключа права; число маршрутов поэтому не изменилось.
          //
          // 34 → 35: задача 11 того же плана добавила
          // `/unfiscalized-receipts` с ключом `settings.fiscal`. Ключ
          // существующий, а не новый `op.fiscalRetry`, как называл план:
          // новый ключ требует шага миграции, иначе тихо не достаётся ни
          // одному существующему пользователю (докстринг `allPermissions`,
          // «Правило на будущее»), а миграции эта задача не делает.
          //
          // 35 → 36: задача 12 добавила `/discount-limits` с ключом
          // `op.editPrice`. Ключ существующий и тот же, что у `/promotions`,
          // по тому же доводу: и акция, и предел скидки решают, сколько
          // маржи разрешено отдать. Кассиру `op.editPrice` не достаётся — и
          // это здесь существенно: назначающий предел самому себе
          // обессмыслил бы предел в первый же день.
          // 36 → 37: задача 24 связала `/credit-contracts` с **новым**
          // ключом `op.creditRepay`. Новый ключ здесь законен ровно
          // потому, что задача делает и шаг миграции (v45,
          // `_grantNewPermissionKeys`) — без него ключ молча стал бы
          // отказом для каждого существующего не-владельца, и это тот
          // самый довод, по которому задача 11 переиспользовала
          // `settings.fiscal` вместо нового ключа.
          // 37 → 38: пункт 8 C (2026-09-15) связал `/qr-provider-settings` с
          // существующим `settings.accounts` — провайдер решает, куда уходят
          // деньги покупателя, периметр счетов кассы; нового ключа нет по
          // тому же доводу, что у `/unfiscalized-receipts`.
          // 38 → 40: решение заказчика 2026-09-18 связало
          // `/receipt-templates` с существующим `settings.printer` —
          // **двумя маршрутами сразу**, потому что `routeToPermissionKey`
          // сопоставляет по префиксу и `/receipt-templates/edit` получает
          // ключ той же записью. До этого дня оба значились в
          // [_routesWithoutPermissionKey] («нет ключа права ни для одной
          // роли»): шаблон правился только с кассы, и защищать было нечего.
          // С этого дня экран достижим с браузерного терминала, где право
          // маршрута проверяет `redirect` таблицы, — без ключа он открылся
          // бы любому вошедшему. Нового ключа нет по тому же доводу, что у
          // `/unfiscalized-receipts`: `settings.printer` задаёт ширину
          // ленты, без которой шаблон не имеет смысла.
          //
          // `/terminal-shift` (смена браузерного терминала, того же дня) в
          // этот счёт **не входит и не должен**: он объявлен только
          // браузерной таблицей, а [allRoutes] обходит `createRouter()` —
          // десктопную. Ключ `nav.shift` у него есть, и проверяет его
          // `redirect` браузерной таблицы.
          // 40 → 41: `/emulator-settings` связан с существующим
          // `settings.hardware` — тем же ключом, что и оборудование.
          // Эмулятор ничего не подменяет: он открывает сокет, на который
          // касса попадёт только через привязку прибора, а привязку правит
          // держатель ровно этого ключа. Нового ключа нет по тому же доводу,
          // что у `/unfiscalized-receipts`: он потребовал бы миграции и до
          // неё молча стал бы отказом для каждого не-владельца.
          // 41 → 42: `/diagnostics` связан с тем же `settings.hardware`:
          // экран показывает внутренности настройки оборудования, а не
          // операцию кассира.
          // 42 → 43: `/certificate-issue` связан с `op.issueCertificate` —
          // **своим** ключом, а не заимствованным: он написан ровно под эту
          // операцию (докстринг `PermissionKeys.opIssueCertificate`
          // разбирает, почему `nav.sale` мало) и до дыры 1 жил только на
          // проводе. Умолчаний роли у него нет намеренно — решение «этому
          // кассиру можно печатать обязательства магазина» принимает
          // владелец.
          // 43 → 44: `/prepayment-refund` связан с `op.creditRepay` — тем
          // же ключом, каким касса закрывает приём аванса на проводе
          // (`pay.prepaymentIntake`). Приём и выдача — одна работа двумя
          // сторонами: тот же счёт, то же движение, та же настройка
          // фискализации. Два ключа утверждали бы, что бывает кассир,
          // которому можно взять чужие деньги на счёт, но нельзя их
          // отдать, — ловушка, а не осторожность.
          expect(
            coveredCount,
            44,
            reason:
                'Число маршрутов, покрытых routeToPermissionKey(), '
                'изменилось. Обнови это число и докстринг файла поимённо — '
                'какой маршрут получил или потерял ключ права и почему.',
          );
        },
      );

      test(
        'каждый маршрут — либо с ключом права, либо публичный, либо явно '
        'назван намеренно открытым',
        () {
          final undecided = <String>[];
          for (final route in allRoutes) {
            final hasKey = PermissionKeys.routeToPermissionKey(route) != null;
            final isPublic = AppRoutes.publicRoutes.contains(route);
            final isIntentionallyOpen = _intentionallyOpenRoutes.containsKey(
              route,
            );
            if (!hasKey && !isPublic && !isIntentionallyOpen) {
              undecided.add(route);
            }
          }

          expect(
            undecided,
            isEmpty,
            reason:
                'Маршрут добавлен в _buildRoutes(), но не получил решения: '
                'ни ключа права в PermissionKeys.routeToPermissionKey(), ни '
                'записи в AppRoutes.publicRoutes, ни записи в '
                '_intentionallyOpenRoutes этого файла. Реши явно (свяжи с '
                'ключом или назови намеренно открытым с обоснованием), '
                'прежде чем маршрут останется молча незащищённым: '
                '$undecided',
          );
        },
      );

      test(
        'обоснование «нет ключа права ни для одной роли» не врёт: '
        'у маршрута действительно нет ключа с совпадающим именем в словаре '
        '(блокер 2 финальной волны закрытия долга безопасности, '
        '2026-08-22)',
        () {
          // Сторож выше требовал только *решения* (ключ/публичный/
          // намеренно открытый), но не проверял, что обоснование
          // «намеренно открытого» решения правдиво. `/telegram-setup` был
          // пойман именно так: значился «нет ключа права ни для одной
          // роли», хотя `settings.telegram` уже существовал и был связан с
          // соседним `/telegram-settings` — тот же периметр, тот же ключ
          // должен был подойти. Эта проверка обходит все записи с этим
          // обоснованием и требует, чтобы производное имя ключа
          // (`_settingsKeyGuessFor`, схема именования восьми уже связанных
          // `settings.*`-маршрутов) не встречалось в словаре
          // `PermissionKeys.allPermissions`.
          final lyingClaims = <String>[];
          for (final entry in _intentionallyOpenRoutes.entries) {
            if (entry.value != 'нет ключа права ни для одной роли') continue;
            final guess = _settingsKeyGuessFor(entry.key);
            if (guess == null) continue;
            if (PermissionKeys.allPermissions.contains(guess)) {
              lyingClaims.add('${entry.key} -> $guess уже существует');
            }
          }

          expect(
            lyingClaims,
            isEmpty,
            reason:
                'Обоснование «нет ключа права ни для одной роли» неверно '
                'для этих маршрутов — ключ с производным именем уже есть в '
                'словаре, маршрут обязан быть связан с ним, а не оставлен '
                'открытым: $lyingClaims',
          );
        },
      );

      test(
        '_intentionallyOpenRoutes не содержит устаревших записей '
        '(страховка от гниения списка в другую сторону)',
        () {
          final stale = _intentionallyOpenRoutes.keys
              .where((route) => !allRoutes.contains(route))
              .toList();

          expect(
            stale,
            isEmpty,
            reason:
                'Эти маршруты исключены из проверки, но больше не '
                'существуют в _buildRoutes() — запись устарела, удали её: '
                '$stale',
          );
        },
      );

      test(
        'ни один маршрут не значится и публичным, и намеренно открытым '
        'одновременно',
        () {
          final overlap = AppRoutes.publicRoutes.toSet().intersection(
            _intentionallyOpenRoutes.keys.toSet(),
          );

          expect(overlap, isEmpty);
        },
      );

      test(
        'восемь settings.*-маршрутов, связанных этой правкой, больше не '
        'значатся в _intentionallyOpenRoutes',
        () {
          const nowKeyed = [
            AppRoutes.printerSettings,
            AppRoutes.fiscalSettings,
            AppRoutes.hardwareSettings,
            AppRoutes.restaurantSettings,
            AppRoutes.transportSettings,
            AppRoutes.telegramSettings,
            AppRoutes.accountsSettings,
            AppRoutes.userManagement,
          ];

          for (final route in nowKeyed) {
            expect(
              PermissionKeys.routeToPermissionKey(route),
              isNotNull,
              reason: '$route обязан быть связан с ключом права этой правкой',
            );
            expect(_intentionallyOpenRoutes, isNot(contains(route)));
          }
        },
      );

      test(
        'три маршрута без ключа и без ownerOnlyScaffold (правка «второй '
        'порядок», пункт 1) — связаны с собственными ключами, а не '
        'оставлены открытыми',
        () {
          const nowKeyed = {
            AppRoutes.terminalServiceSettings:
                PermissionKeys.settingsTerminalService,
            AppRoutes.logJournal: PermissionKeys.settingsLogJournal,
            AppRoutes.applianceSettings: PermissionKeys.settingsAppliance,
          };

          for (final entry in nowKeyed.entries) {
            expect(
              PermissionKeys.routeToPermissionKey(entry.key),
              entry.value,
              reason:
                  '${entry.key} обязан требовать ${entry.value} — до этой '
                  'правки маршрут был достижим любому вошедшему с любой '
                  'ролью прямым переходом по адресу',
            );
            expect(_intentionallyOpenRoutes, isNot(contains(entry.key)));
          }
        },
      );

      test(
        '/terminal-service-settings — самый острый из трёх: открывает и '
        'закрывает порт кассы для браузерных терминалов',
        () {
          expect(
            PermissionKeys.routeToPermissionKey(
              AppRoutes.terminalServiceSettings,
            ),
            PermissionKeys.settingsTerminalService,
          );
        },
      );

      test(
        '/user-management — самый острый маршрут — связан с settings.users, '
        'а не оставлен открытым',
        () {
          expect(
            PermissionKeys.routeToPermissionKey(AppRoutes.userManagement),
            PermissionKeys.settingsUsers,
            reason:
                'settings.users — право раздавать права; администратор его '
                'не получает по умолчанию (roleDefaults) именно потому, что '
                'это путь самоповышения. Маршрут обязан требовать тот же '
                'ключ, иначе прямой переход по адресу обходил бы это '
                'решение целиком.',
          );
        },
      );

      test(
        'параметрические маршруты наследуют ключ родителя по префиксу',
        () {
          expect(
            PermissionKeys.routeToPermissionKey(AppRoutes.tableDetail),
            PermissionKeys.navTables,
          );
          expect(
            PermissionKeys.routeToPermissionKey(AppRoutes.orderDetail),
            PermissionKeys.navOrders,
          );
          expect(
            PermissionKeys.routeToPermissionKey(AppRoutes.serviceDetail),
            PermissionKeys.navServiceQueue,
          );
        },
      );

      test(
        'префикс сопоставляется по границе "/", а не по голому startsWith — '
        '/orders не начинает совпадать с чем-то посторонним',
        () {
          // Голый startsWith('/orders') совпал бы и с этими строками —
          // ни одна не является настоящим дочерним маршрутом /orders
          // (нет разделителя '/' сразу после совпавшего префикса).
          expect(
            PermissionKeys.routeToPermissionKey('/orders-archive'),
            isNull,
          );
          expect(PermissionKeys.routeToPermissionKey('/ordersx'), isNull);

          // Тот же брифом названный случай для соседей по словарю прав —
          // /settings не должен захватывать /settings-anything, а
          // /tables — /tablesuffix.
          expect(
            PermissionKeys.routeToPermissionKey('/settings-anything'),
            isNull,
          );
          expect(
            PermissionKeys.routeToPermissionKey('/tablesuffix'),
            isNull,
          );

          // А настоящий дочерний маршрут (граница '/' есть) — совпадает,
          // тем же ключом, что и родитель.
          expect(
            PermissionKeys.routeToPermissionKey('/orders/42'),
            PermissionKeys.navOrders,
          );
        },
      );
    },
  );
}
