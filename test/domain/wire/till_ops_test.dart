import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/network/network_status.dart';
import 'package:telepos/domain/network/wifi_network.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/startup/first_launch_repository.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/wire/auth_wire.dart';
import 'package:telepos/domain/wire/network_wire.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/setup_state.dart';
import 'package:telepos/domain/wire/terminal_wire.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_op.dart';

void main() {
  group('род операции', () {
    test('шестнадцать операций — подписки, и это цель всей смены транспорта', () {
      // Перестать спрашивать — единственная выгода, ради которой менялся
      // транспорт. Тест краснеет, если кто-то вернёт подписку в разряд
      // вопросов: состояние, которое приходится перезапрашивать, доезжает
      // не в момент события, а при следующем вопросе. auth.users и
      // auth.session — подписки по той же причине: заведённый кассир и
      // погашенный сеанс обязаны дойти в момент события, а не при
      // следующем вопросе экрана входа. auth.sessions (задача 19 закрытия
      // долга безопасности) — седьмая: чужой вход и чужой отзыв обязаны
      // дойти до экрана списка сеансов тем же путём.
      //
      // Восьмая и девятая — задача 9 плана «Продажа с браузерного
      // терминала» (2026-09-06). `sale.cart`: корзина меняется не только
      // своими командами (соседняя вкладка того же рабочего места, подъём
      // отложенного чека, завершение продажи на кассе), и каждое обязано
      // доехать в момент события, а не опросом по таймеру.
      // `sale.deferredList` — по причине сильнее: пул отложенных чеков
      // общий на кассу, и чек, поднятый соседом, обязан исчезнуть из
      // списка, а не отказать посреди работы.
      const watches = <WireOp<Object?, Object?>>[
        TillOps.setupState,
        TillOps.terminalsList,
        TillOps.terminalSelf,
        TillOps.deviceBindings,
        TillOps.authUsers,
        TillOps.authSession,
        TillOps.authSessions,
        SaleOps.cart,
        SaleOps.deferredList,
        // Восьмая — задача 19 плана «Продажа с браузерного терминала»:
        // черновик возврата живёт на кассе, и экран обязан увидеть его
        // изменение в момент изменения, а не при следующем вопросе.
        RefundOps.view,
        // Одиннадцатая — решение заказчика 2026-09-18: состояние смены.
        // Подписка, а не вопрос, и это **починка измеренного дефекта**, а не
        // предпочтение: дом браузерного терминала показывал «Смена открыта»
        // зелёным значком часами после того, как смену закрыли, потому что
        // состояние приезжало один раз в `AuthSession` при входе. Вопрос
        // чинил бы это только в миг постройки экрана, а вкладку держат
        // открытой всю смену.
        TillOps.shiftState,
        // Двенадцатая — пункт «Достижимость с браузерного терминала» плана
        // `2026-09-19-hardware-diagnostics.md`: задания печати. Подписка, а
        // не вопрос, и довод свой: наладчик держит вкладку диагностики
        // открытой и печатает пробный чек с соседнего экрана. Вопрос был бы
        // верен ровно в миг постройки экрана — пробный чек не появился бы на
        // нём вовсе, и вкладка отвечала бы «касса ничего не печатала» сразу
        // после печати.
        //
        // Соседняя `diagnostics.fiscal` — намеренно **вопрос**: сигнала
        // изменения у очереди фискализации касса не держит, а экран наладчик
        // обновляет потягиванием вниз.
        TillOps.diagnosticsPrinter,
        // Тринадцатая — пункт 12 ревизии 2026-09-19: ревизия остатков.
        // Подписка, а не вопрос, и по тому же доводу, что у корзины: каталог
        // держат открытым, а остаток меняет соседнее рабочее место. Вопрос был
        // бы верен в миг постройки экрана — то есть ровно тогда, когда сосед
        // ещё ничего не продал.
        TillOps.stockRevision,
        // Четырнадцатая и пятнадцатая — пункт 4 того же плана диагностики:
        // импульсы денежного ящика и строки дисплея покупателя. Довод
        // дословно принтерный, вплоть до сценария: наладчик держит вкладку
        // открытой и **жмёт кнопку на кассе** — импульс и строка обязаны
        // появиться в момент события. Вопрос отвечал бы «ящик не звали»
        // сразу после того, как его позвали.
        //
        // Сигнал у кассы уже есть (`CashDrawerJournal.watch`,
        // `CustomerDisplayJournal.watch`) — заводить под эти две подписки не
        // пришлось ничего. Тем они и отличаются от `diagnostics.fiscal`, где
        // сигнала нет и подписку строили бы ради экрана.
        TillOps.diagnosticsDrawer,
        TillOps.diagnosticsDisplay,
        // Шестнадцатая — весы, и довод у неё **сильнее прочих**: вопрос здесь
        // неверен по предмету. Вкладка весов существует затем, чтобы
        // наладчик положил груз на чашу и увидел, как число едет; вопрос
        // показал бы одно застывшее число, и «ещё раз» он жал бы вместо
        // того, чтобы смотреть на чашу.
        //
        // Единственная подписка, у которой данные — **поток**, а не события:
        // `ScalesService` опрашивает порт каждые 200 мс. Поэтому кадры
        // прореживает касса, до провода (докстринг
        // `HardwareDiagnosticsRepository.watchScales`): повторы сняты,
        // остаток режется окном, последний кадр досылается всегда.
        // Прореживание — свойство реализации, а не рода операции, и
        // подпиской она от этого быть не перестаёт.
        TillOps.diagnosticsScales,
      ];

      for (final op in watches) {
        expect(op, isA<Watch>(), reason: '${op.name} обязана быть подпиской');
      }

      expect(
        TillOps.all.whereType<Watch>().toSet(),
        watches.toSet(),
        reason:
            'подписок ровно шестнадцать и ровно эти: новая подписка '
            'добавляется сюда сознательно, а не проскакивает мимо счёта',
      );
    });

    test('две операции — длинная работа с ходом выполнения', () {
      // Восстановление из копии и загрузка данных организации идут минутами.
      // До провода канала для хода выполнения не было вовсе, и код честно
      // писал о себе, что придумывать промежуточные числа отказывается.
      expect(TillOps.setupRestore, isA<Run>());
      expect(TillOps.setupLoadGlobalData, isA<Run>());

      expect(TillOps.all.whereType<Run>().toSet(), {
        TillOps.setupRestore,
        TillOps.setupLoadGlobalData,
      }, reason: 'длинных работ ровно две');
    });

    test(
      'двенадцать операций из шестидесяти шести перестали быть вопросами',
      () {
        // Ровно это и просили от смены транспорта. Четыре подписки плюс две
        // длинных работы — те самые шесть из спеки; auth.users и auth.session
        // добавили ещё две подписки — те самые восемь. auth.sessions (задача
        // 19 закрытия долга безопасности) добавила девятую. Остальные
        // двадцать три остаются вопросами, потому что вопросами и являются:
        // заведение, возврат по секрету, переименование и удаление терминала,
        // поиск устройства и его проверка, вход/выход, отзыв чужого сеанса, а
        // теперь и шесть сетевых операций (задача «сетевые настройки по
        // проводу», спека 2026-08-24) — это действия, а не состояния, за
        // которыми следят: экран и так опрашивает сеть раз в четыре секунды.
        // `terminals.resume` (задача 5 плана «знакомство терминала с кассой»)
        // — вопрос, а не подписка: она отвечает один раз и закрывается, тем
        // же родом, что и `terminals.register`, рядом с которым заведена.
        // `sale.ping` (задача 1 плана «Продажа с браузерного терминала»,
        // 2026-09-06) — двадцать третий вопрос: наименьший обмен, штрихкод
        // туда, товар обратно, без подписки — состояния, за которым следят,
        // здесь и нет, есть разовый запрос.
        //
        // Задача 9 того же плана добавила ещё девятнадцать операций продажи
        // (`SaleOps`, `sale_ops.dart`): семнадцать вопросов — команды
        // корзины и поиск, действия, а не состояния, — и две подписки,
        // `sale.cart` и `sale.deferredList`, названные поимённо выше.
        // Отсюда 32 -> 51, вопросов 23 -> 40, не-вопросов 9 -> 11.
        //
        // Задача 14 добавила пять денежных операций оплаты (`PayOps`,
        // `pay_ops.dart`: `pay.accounts`, `pay.loyalty`, `pay.bonus`,
        // `pay.card`, `pay.complete`) — все пять вопросы, и это не
        // упущение: счета и клиент лояльности спрашиваются в момент, когда
        // экран открылся, эквайринг и завершение оплаты — действия, а не
        // состояния, за которыми следят. Подписки не прибавилось ни одной.
        // Отсюда 51 -> 56, вопросов 40 -> 45, не-вопросов 11 без изменений.
        //
        // **Счёт сведён при слиянии обходом, а не сложением двух ветвей.**
        // Задачи 9 и 14 правили эти три числа независимо и обе видели
        // только свою половину: цепочка продажи писала 51/40/11, ветвь
        // оплаты — 37/28/9 от той же базы 32. Ни одна пара не описывает
        // дерево после слияния, и «взять большее» было бы угадыванием.
        // Ветвь `paytypes` правила те же числа четвёртый раз (38/29/9),
        // ветвь `fiscal` — пятый, и ровно теми же (38/29/9) от той же
        // базы: два независимых счёта совпали значением и разошлись
        // составом. Ветвь `refund` — шестой (38/28/10). Обход при
        // слиянии — единственный способ узнать правду.
        //
        // Задача 15 добавила одну операцию — `terminals.setPaymentTypes`
        // (набор видов оплаты рабочего места). Тоже вопрос, тоже не
        // подписка: набор правится нажатием «Сохранить» на экране
        // настроек, а не наблюдается. Отсюда 56 -> 57, вопросов 45 -> 46,
        // не-вопросов 11 без изменений.
        //
        // Задача 16 добавила `pay.troubles` — беды железа спрашиваются
        // **после** успеха оплаты: печать и денежный ящик касса
        // отправляет, а не ждёт (правило «оплата не ждёт железа»), и их
        // исход не может ехать в ответе `pay.complete`. Тоже вопрос:
        // беда чека случается один раз, следить за ней нечем. Отсюда
        // 57 -> 58, вопросов 46 -> 47, не-вопросов 11 без изменений.
        //
        // Задача 19 добавила шесть операций возврата (`RefundOps`): пять
        // вопросов и **одну подписку** — `refund.view`. Черновик возврата
        // живёт на кассе, и экран обязан увидеть его изменение в момент
        // изменения, а не при следующем вопросе. Это первая прибавка к
        // числу не-вопросов за весь план. Отсюда 58 -> 64, вопросов
        // 47 -> 52, не-вопросов 11 -> 12.
        //
        // Задача 16 плана «Полнота продажи» добавила `pay.sellsInDebt` —
        // вопрос, а не подписку: тумблер кассы «продажа в кредит» меняют
        // в мастере настройки, а не посреди смены, и держать ради него
        // открытый поток QUIC на каждую вкладку было бы расходом без
        // выгоды. Отсюда 64 -> 65, вопросов 52 -> 53, не-вопросов 12 без
        // изменений.
        //
        // Задача 21 того же плана добавила `pay.certificateIssue` —
        // выпуск подарочного сертификата. Вопрос, а не подписка: выпуск
        // случается один раз и один раз отвечает; состояния, за которым
        // следят, у бумажки нет — её остаток спрашивают тогда, когда её
        // подали. Отсюда 65 -> 66, вопросов 53 -> 54, не-вопросов 12 без
        // изменений.
        //
        // Вход в аванс и сертификат добавил два вопроса: `pay.prepayment`
        // (сколько аванса внесено покупателем) и `pay.certificate` (что
        // касса знает о бумажке). Оба — вопросы, а не подписки: остаток
        // нужен кассиру в момент решения, и открытый поток ради числа,
        // которое меняет только оплата этого же чека, был бы расходом.
        // Отсюда 66 -> 68, вопросов 54 -> 56, не-вопросов 12 без изменений.
        //
        // Вход в оплату по QR добавил три вопроса: `pay.qrStart`,
        // `pay.qrPoll`, `pay.qrCancel`. **Опрос — вопрос, а не подписка**, и
        // это решение, а не упущение: ответ меняет не касса, а провайдер за
        // сетью, и узнать о нём касса может только спросив его сама. Подписка
        // держала бы поток QUIC открытым ради того, чтобы касса каждые две
        // секунды спрашивала провайдера за вкладку, — то есть вкладка
        // закрылась бы, а вопросы к провайдеру продолжились. Круг, заданный
        // вкладкой, кончается вместе с вкладкой; брошенные коды касса
        // отменяет сама (`QrPaymentDesk.sweepStale`). Отсюда 68 -> 71,
        // вопросов 56 -> 59, не-вопросов 12 без изменений.
        //
        // Задачи 44–45 добавили `sale.editTerms` — условия правки строки
        // (настройки кассы, предел скидки вошедшего, валюта) до ввода. Вопрос,
        // а не подписка: читается один раз на нажатие «Редактировать». Отсюда
        // 71 -> 72, вопросов 59 -> 60.
        //
        // Готовность QR (2026-09-15) добавила вопрос `pay.qrReadiness`:
        // панель оплаты узнаёт «не настроено / вид выключен» при открытии,
        // а не на первом «Показать QR». Вопрос, а не подписка — ответ
        // меняет настройка, а экран живёт один чек. Отсюда 72 -> 73,
        // вопросов 60 -> 61, не-вопросов 12 без изменений.
        //
        // Задача 45 добавила три вопроса: `sale.quickCategories`,
        // `sale.quickItems` (быстрые товары, касса владеет каталогом) и
        // `scanner.rules` (правила чтения штрихкода для продажи и возврата в
        // браузере). Вопросы, а не подписки: сетка и сканер читают их при
        // открытии экрана. Отсюда 73 -> 76, вопросов 61 -> 64.
        //
        // Приёмка 2026-09-17 добавила `refund.troubles` — близнец
        // `pay.troubles`: возврат с наличной частью теперь открывает ящик,
        // отправляя, а не ожидая, и его беда спрашивается после успеха.
        // Вопрос, а не подписка — тем же доводом, что у продажи. Отсюда
        // 76 -> 77, вопросов 64 -> 65.
        // Требование заказчика 2026-09-18 добавило `pay.prepaymentIntake` —
        // приём аванса покупателя с браузерного терминала. До него терминал
        // умел только **читать** остаток (`pay.prepayment`), а внести деньги
        // вперёд — нет: приём жил в одном кассовом диалоге. Вопрос, а не
        // подписка: кассир вносит взнос один раз и уходит. Отсюда
        // 77 -> 78, вопросов 65 -> 66, не-вопросов 12 без изменений.
        // Решение заказчика 2026-09-18 добавило четыре операции настройки
        // оплаты по QR — `qr.providerSettings`, `qr.providerSave`,
        // `qr.providerClear`, `qr.providerKind`: экран настройки был
        // достижим только с кассы, и владелец с планшетом вместо кассы
        // включить QR не мог ничем. По одной на метод порта
        // `QrProviderSetupRepository` — договор, у которого на проводе нет
        // одного метода, отказывает в одном месте из четырёх. Вопросы, а не
        // подписки: настройку правят и уходят. Отсюда 78 -> 82, вопросов
        // 66 -> 70, не-вопросов 12 без изменений.
        // Решение заказчика 2026-09-18 добавило шесть операций шаблона чека
        // — `receipt.templates`, `receipt.templateSave`,
        // `receipt.templateSelect`, `receipt.templateDelete`,
        // `receipt.templatePreview`, `receipt.templateTestPrint`: шапку и
        // подвал чека правили только с кассы, оба экрана шаблона ходили в
        // `AppDatabase` напрямую и в браузер не собирались вовсе. По одной
        // на метод порта `ReceiptTemplateSetupRepository`, тем же правилом,
        // что у `qr.*`. Вопросы, а не подписки: шаблон правят и уходят, а
        // предпросмотр спрашивают после каждой правки — это вопрос по
        // существу. Отсюда 82 -> 88, вопросов 70 -> 76.
        //
        // И того же дня — три операции смены. `shift.close` и `shift.open`
        // вопросы: смену закрывают один раз и уходят. `shift.state` —
        // **подписка**, и это единственная не-вопрос из трёх: значок
        // состояния смены на доме терминала был снимком, взятым при входе, и
        // оставался зелёным при просроченной смене. Отсюда 88 -> 91,
        // вопросов 76 -> 78, не-вопросов 12 -> 13.
        //
        // Пункт «Достижимость с браузерного терминала» плана
        // `2026-09-19-hardware-diagnostics.md` добавил две операции
        // диагностики — `diagnostics.printer` и `diagnostics.fiscal`. По
        // одной на метод порта `HardwareDiagnosticsRepository`, тем же
        // правилом, что у `qr.*`, `receipt.*` и `shift.*`. **Род у них
        // разный**, и это решение, а не оформление: принтер — подписка
        // (наладчик держит вкладку открытой и печатает пробный чек с
        // соседнего экрана; вопрос был бы верен ровно в миг постройки
        // экрана), оператор — вопрос (сигнала изменения у очереди
        // фискализации касса не держит, а экран обновляют потягиванием
        // вниз). Отсюда 91 -> 93, вопросов 78 -> 79, не-вопросов 13 -> 14.
        //
        // Пункт 11 ревизии 2026-09-19 добавил `scanner.saveRules` — запись
        // правил чтения штрихкода с планшета. Вопрос, а не подписка: правила
        // задают на форме и сохраняют кнопкой, следить тут не за чем. Отсюда
        // 93 -> 94, вопросов 79 -> 80, не-вопросов по-прежнему 14. Тот же
        // пункт добавил `sale.expiryWarning` — «партия этого товара
        // просрочена?». Тоже вопрос: спрашивается один раз на вставшую
        // строку, а не состояние, за которым следят. Отсюда 94 -> 95,
        // вопросов 80 -> 81. Пункт 12 добавил `stock.revision` — единственную
        // из трёх **подписку**: вкладку держат открытой всю смену, и продажа
        // соседнего рабочего места обязана доехать в момент события, а не
        // при следующем вопросе. Отсюда 95 -> 96, не-вопросов 14 -> 15.
        //
        // Пункт 4 того же плана диагностики добавил три оставшихся прибора —
        // `diagnostics.drawer`, `diagnostics.display`, `diagnostics.scales`,
        // по одной на метод того же порта. **Все три — подписки**, и это не
        // единообразие ради единообразия: у ящика и дисплея довод дословно
        // принтерный (наладчик держит вкладку открытой и жмёт кнопку на
        // кассе), а у весов сильнее — вопрос там неверен по предмету, потому
        // что смотрят не число, а то, как оно едет, пока груз ложится на
        // чашу. Отсюда 96 -> 99, вопросов по-прежнему 81, не-вопросов
        // 15 -> 18.
        // Решение заказчика 2026-09-18 «в браузере должно работать то же,
        // что в приложении» добавило две операции оплаты:
        // `pay.prepaymentRefund` — выдача аванса деньгами (приём ехал с
        // 2026-09-18, а вернуть внесённое было нечем: юзкейс заведён,
        // экран под ним только кассовый) и `pay.certificateSlip` — повтор
        // печати слипа (сам слип выпуска касса печатала и раньше, внутри
        // выпуска; недостижим был повтор). **Обе вопросы**, и ни одна не
        // подписка: деньги выдают один раз и уходят, слип перепечатывают
        // один раз и уходят — следить тут не за чем. Отсюда 96 -> 98,
        // вопросов 81 -> 83, не-вопросов по-прежнему 15.
        // Обе дорожки приехали одновременно и посчитали каждая от 96.
        // Сведено при слиянии: три подписки диагностики и два вопроса
        // оплаты складываются, а не заменяют друг друга.
        expect(TillOps.all, hasLength(101));
        expect(TillOps.all.whereType<Ask>(), hasLength(83));
        expect(TillOps.all.where((op) => op is! Ask), hasLength(18));
      },
    );
  });

  group('имена', () {
    test('имена операций уникальны', () {
      // Два описания под одним именем — молчаливая подмена обработчика:
      // касса ищет обработчик по имени и найдёт тот, что зарегистрирован
      // последним, ничего не сказав про первый.
      final names = TillOps.all.map((op) => op.name).toList();
      expect(names.toSet(), hasLength(names.length), reason: '$names');
    });

    test('в имени операции нет косой черты', () {
      // Маршрутов больше нет, есть операции. Косая черта означала бы, что
      // путь URL просочился обратно под видом имени, — а вместе с ним и
      // согласование концов по строке, которое стоило белого экрана
      // 2026-08-04.
      for (final op in TillOps.all) {
        expect(
          op.name.contains('/'),
          isFalse,
          reason: '${op.name} — это путь, а не имя операции',
        );
      }
    });

    test('каждая объявленная операция входит в TillOps.all', () {
      // Иначе проверки уникальности и косой черты доказывают что-то только
      // про подмножество, а операция, забытая в списке, тихо от них уходит.
      const declared = <WireOp<Object?, Object?>>[
        TillOps.startupBoot,
        TillOps.setupFirstLaunch,
        TillOps.setupState,
        TillOps.setupBackups,
        TillOps.setupRestore,
        TillOps.setupLoadGlobalData,
        TillOps.setupNewPos,
        TillOps.setupComplete,
        TillOps.terminalsList,
        TillOps.terminalSelf,
        TillOps.deviceBindings,
        TillOps.deviceBindingSave,
        TillOps.terminalRename,
        TillOps.terminalSetPaymentTypes,
        TillOps.terminalRegister,
        TillOps.terminalResume,
        TillOps.terminalDelete,
        TillOps.terminalSelfEnsure,
        TillOps.deviceDiscovery,
        TillOps.deviceCheck,
        // Задача 45: правила чтения штрихкода для продажи и возврата в браузере.
        TillOps.scannerRules,
        // Пункт 11 ревизии 2026-09-19: та же тройка правил, но на запись.
        TillOps.scannerRulesSave,
        // Тот же пункт: предупреждение о просроченной партии в браузере.
        TillOps.saleExpiryWarning,
        // Пункт 12 ревизии 2026-09-19: остатки соседнего рабочего места.
        TillOps.stockRevision,
        TillOps.authUsers,
        TillOps.authLogin,
        TillOps.authLogout,
        TillOps.authSession,
        TillOps.authSessions,
        TillOps.authSessionRevoke,
        TillOps.networkStatus,
        TillOps.networkWifiScan,
        TillOps.networkWifiConnect,
        TillOps.networkWifiDisconnect,
        TillOps.networkEthernetStatus,
        TillOps.networkEthernetConfigure,
        // Настройка оплаты по QR из браузера — решение заказчика 2026-09-18,
        // по одной на метод порта `QrProviderSetupRepository`.
        TillOps.qrProviderSettings,
        TillOps.qrProviderSave,
        TillOps.qrProviderClear,
        TillOps.qrProviderKind,
        // Шаблон чека с браузерного терминала — решение заказчика
        // 2026-09-18.
        TillOps.receiptTemplates,
        TillOps.receiptTemplateSave,
        TillOps.receiptTemplateSelect,
        TillOps.receiptTemplateDelete,
        TillOps.receiptTemplatePreview,
        TillOps.receiptTemplateTestPrint,
        // Смена с браузерного терминала — того же дня.
        TillOps.shiftState,
        TillOps.shiftClose,
        TillOps.shiftOpen,
        // Диагностика оборудования с планшета — план 2026-09-19.
        TillOps.diagnosticsPrinter,
        TillOps.diagnosticsFiscal,
        // Пункт 4 того же плана: ящик, дисплей покупателя, весы.
        TillOps.diagnosticsDrawer,
        TillOps.diagnosticsDisplay,
        TillOps.diagnosticsScales,
        // Двадцать операций продажи (`SaleOps`, задачи 1 и 9) и пять
        // денежных операций оплаты (`PayOps`, задача 14) объявлены в своих
        // каталогах и входят сюда через `...SaleOps.all` / `...PayOps.all`.
        // Поимённо оба списка закреплены там же, где и их права —
        // `test/domain/wire/sale_ops_access_test.dart` и
        // `test/domain/wire/pay_ops_access_test.dart`: переписывать те же
        // списки во второй раз значило бы завести второе место, которое
        // расходится с первым молча.
        ...SaleOps.all,
        ...PayOps.all,
        // Шесть операций возврата (`RefundOps`, задача 19) — тем же
        // приёмом: поимённо они закреплены в `refund_ops_test.dart`.
        ...RefundOps.all,
      ];

      expect(TillOps.all.toSet(), declared.toSet());
    });

    test('каждый метод каждого договора имеет свою операцию', () {
      // Договор, у которого на проводе нет одного метода, — это биндинг,
      // отказывающий в одном месте из четырёх, и узнать об этом можно только
      // нажав кнопку. Здесь перечислено то, что браузерные репозитории
      // обязаны уметь; забытая операция краснеет тут, а не в поле.
      final names = TillOps.all.map((op) => op.name).toSet();

      expect(
        names,
        containsAll(<String>[
          'terminals.list', // TerminalRepository.list / watchAll
          'terminals.self', // .watchSelf — наблюдение, строки не заводит
          'terminals.selfEnsure', // .self — заводит, если терминала ещё нет
          'terminals.register', // .register
          'terminals.resume', // .resume — задача 5, возврат по секрету
          'terminals.rename', // .rename
          'terminals.delete', // .delete
          'terminals.deviceBindings', // DeviceBindingRepository.forTerminal
          'terminals.deviceBindingSave', // .save
          'terminals.deviceDiscovery', // DeviceDiscovery.find
          'terminals.deviceCheck', // DeviceCheck.check
        ]),
      );
    });
  });

  group('разбор ответа', () {
    test('список терминалов разбирается той же парой, что его и пишет', () {
      // Операция не заводит третьего читателя формы: её `decode` зовёт
      // `terminalFromWireJson` — ту же половину пары, которой касса пишет
      // ответ. Иначе каталог операций стал бы ровно тем расхождением,
      // ради устранения которого пары и сводились.
      const terminal = Terminal(
        id: 3,
        name: 'Касса-3',
        pointMode: PointMode.kitchen,
      );

      final decoded = TillOps.terminalsList.decode({
        'terminals': [terminalToWireJson(terminal)],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.id, 3);
      expect(decoded.single.pointMode, PointMode.kitchen);
    });

    test('привязки устройств разбираются той же парой', () {
      const binding = DeviceBinding(
        deviceClass: DeviceClass.scale,
        profileId: 'cas_er_plus',
        parameters: {'comPort': 'COM3'},
        enabled: false,
      );

      final decoded = TillOps.deviceBindings.decode({
        'bindings': [deviceBindingToWireJson(binding)],
      });

      expect(decoded.single.deviceClass, DeviceClass.scale);
      expect(decoded.single.enabled, isFalse);
    });

    test('состояние установки разбирается той же парой', () {
      final decoded = TillOps.setupState.decode(
        setupStateToWireJson(
          const SetupState(configured: true, hasUsers: true),
        ),
      );

      expect(decoded.configured, isTrue);
      expect(decoded.hasUsers, isTrue);
    });

    test('отсутствие собственного терминала — null, а не выдуманный', () {
      // Свежая установка мастер настройки ещё не проходила, и настоящего
      // имени кассы нет. `TerminalRepository.self()` отказывается его
      // выдумывать; провод обязан отказываться так же.
      expect(TillOps.terminalSelf.decode(const {}), isNull);
    });

    test('нераспознанное имя состояния загрузки не угадывается', () {
      // Касса новее терминала — обычное состояние при обновлении по одной
      // машине. Худшее, что можно сделать, — выдать неизвестный отказ за
      // `success`.
      expect(
        TillOps.startupBoot.decode(const {'status': 'quantumFailure'}),
        AppInitStatus.databaseFailure,
      );
      expect(
        TillOps.startupBoot.decode(const {'status': 'success'}),
        AppInitStatus.success,
      );
    });

    test('нераспознанный итог первого запуска не угадывается', () {
      expect(
        TillOps.setupFirstLaunch.decode(const {'result': 'quantumMode'}),
        FirstLaunchResult.offlineMode,
      );
    });

    test('список сеансов разбирается той же парой, что его и пишет', () {
      // Задача 19 закрытия долга безопасности. Токена в форме нет — см.
      // докстринг `LiveSession`/`liveSessionToWireJson`.
      final decoded = TillOps.authSessions.decode({
        'sessions': [
          liveSessionToWireJson((
            terminalId: 5,
            userId: 7,
            name: 'Айгуль',
            role: 'cashier',
            issuedAt: DateTime.utc(2026, 8, 22, 10),
            expiresAt: DateTime.utc(2026, 8, 22, 10, 30),
          )),
        ],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.terminalId, 5);
      expect(decoded.single.userId, 7);
      expect(decoded.single.name, 'Айгуль');
      // Токена в записи нет структурно — `LiveSession` его не несёт полем,
      // а не полагается на то, что вызывающий код не прочитает то, что
      // забыл проверить. Отдельной проверки на рантайме это не требует:
      // код, обратившийся к `.token`, не скомпилировался бы вовсе.
    });
  });

  group('запрос', () {
    test('восстановление шлёт идентификатор сообщения, а не всю копию', () {
      // Копия у кассы уже есть — она её и нашла. Слать её обратно означало
      // бы гонять мегабайты по проводу ради одного числа.
      final body = TillOps.setupRestore.encode(
        FoundBackup(
          posKey: 'k',
          posName: 'p',
          organizationName: 'o',
          createdAt: DateTime.utc(2026, 8, 4),
          messageId: 77,
          checksum: 'c',
          sizeBytes: 1,
        ),
      );

      expect(body, {'messageId': 77});
    });

    test('сохранение привязки несёт терминал и саму привязку', () {
      const binding = DeviceBinding(
        deviceClass: DeviceClass.receiptPrinter,
        profileId: 'generic_escpos',
      );

      final body = TillOps.deviceBindingSave.encode((
        terminalId: 5,
        binding: binding,
      ));

      expect(body['terminalId'], 5);
      expect(
        body['binding'],
        deviceBindingToWireJson(binding),
        reason: 'форма привязки — общая пара, а не четвёртая рукописная копия',
      );
    });

    test('переименование несёт терминал и имя', () {
      final body = TillOps.terminalRename.encode((
        terminalId: 5,
        name: 'Касса у входа',
      ));

      expect(body, {'terminalId': 5, 'name': 'Касса у входа'});
    });

    test('привязки устройств спрашиваются про конкретный терминал', () {
      expect(TillOps.deviceBindings.encode(9), {'terminalId': 9});
    });

    test('отзыв сеанса называет терминал, не токен', () {
      // Задача 19 закрытия долга безопасности: тело отзыва пишет тот, кто
      // отзывает чужой сеанс, а токена у него на руках нет — экран списка
      // сеансов его и не показывает.
      expect(TillOps.authSessionRevoke.encode(5), {'terminalId': 5});
    });

    test('возврат по секрету несёт терминал и секрет — задача 5', () {
      final body = TillOps.terminalResume.encode((
        terminalId: 5,
        secret: 'секрет-предъявленный-вкладкой',
      ));

      expect(body, {
        'terminalId': 5,
        'secret': 'секрет-предъявленный-вкладкой',
      });
    });
  });

  group('сеть кассы — задача «сетевые настройки по проводу», 2026-08-24', () {
    test('состояние сети разбирается той же парой, что его и пишет', () {
      const status = NetworkStatus(
        wifiConnected: true,
        wifiSsid: 'Магазин-1',
        wifiSignal: 71,
        ethernetConnected: false,
        ethernetInterface: null,
        internet: true,
      );

      final decoded = TillOps.networkStatus.decode(
        networkStatusToWireJson(status),
      );

      expect(decoded.wifiConnected, isTrue);
      expect(decoded.wifiSsid, 'Магазин-1');
      expect(decoded.wifiSignal, 71);
      expect(decoded.ethernetConnected, isFalse);
      expect(decoded.internet, isTrue);
    });

    test('список сетей Wi-Fi разбирается той же парой', () {
      const network = WifiNetwork(ssid: 'Кафе', signal: 55, security: 'WPA2');

      final decoded = TillOps.networkWifiScan.decode({
        'networks': [wifiNetworkToWireJson(network)],
      });

      expect(decoded, hasLength(1));
      expect(decoded.single.ssid, 'Кафе');
      expect(decoded.single.isSecured, isTrue);
    });

    test('подключение к Wi-Fi несёт ssid и пароль, только если он есть', () {
      expect(
        TillOps.networkWifiConnect.encode((ssid: 'Кафе', password: 'секрет')),
        {'ssid': 'Кафе', 'password': 'секрет'},
      );
      expect(
        TillOps.networkWifiConnect.encode((ssid: 'Открытая', password: null)),
        {'ssid': 'Открытая'},
        reason:
            'открытая сеть — без ключа `password` вовсе, не с пустой строкой',
      );
    });

    test('исход подключения разбирается из success/message', () {
      final decoded = TillOps.networkWifiConnect.decode({
        'success': true,
        'message': 'подключено',
      });
      expect(decoded.success, isTrue);
      expect(decoded.message, 'подключено');
    });

    test('отключение Wi-Fi разбирается как ok', () {
      expect(TillOps.networkWifiDisconnect.decode(const {'ok': true}), isTrue);
      expect(TillOps.networkWifiDisconnect.decode(const {}), isFalse);
    });

    test(
      'настройка Ethernet едет одним методом на оба режима, DHCP без лишних полей',
      () {
        expect(
          TillOps.networkEthernetConfigure.encode((
            iface: 'eth0',
            mode: 'dhcp',
            ipCidr: null,
            gateway: null,
            dns: null,
          )),
          {'iface': 'eth0', 'mode': 'dhcp'},
        );
      },
    );

    test('настройка Ethernet статикой несёт адрес, шлюз и DNS', () {
      expect(
        TillOps.networkEthernetConfigure.encode((
          iface: 'eth0',
          mode: 'static',
          ipCidr: '192.168.1.50/24',
          gateway: '192.168.1.1',
          dns: '8.8.8.8',
        )),
        {
          'iface': 'eth0',
          'mode': 'static',
          'ipCidr': '192.168.1.50/24',
          'gateway': '192.168.1.1',
          'dns': '8.8.8.8',
        },
      );
    });

    test('исход настройки Ethernet разбирается из success/mode', () {
      final decoded = TillOps.networkEthernetConfigure.decode({
        'success': true,
        'mode': 'static',
      });
      expect(decoded.success, isTrue);
      expect(decoded.mode, 'static');
    });

    test('подробности проводного интерфейса едут как пришли, без собственной '
        'модели', () {
      // Форма варьируется по тому, что вернул `ip -j addr show` на кассе
      // (докстринг `NetworkRepository.ethernetStatus`) — разбор не сужает
      // её, только возвращает тело кадра как есть.
      final decoded = TillOps.networkEthernetStatus.decode({
        'interfaces': [
          {'ifname': 'eth0'},
        ],
      });
      expect(decoded['interfaces'], hasLength(1));
    });

    test('все шесть сетевых операций объявлены OpenAccess', () {
      // Экран публичный и на десктопе (доступен с экрана входа и из
      // мастера) — граница спеки 2026-08-24.
      for (final op in const [
        'network.status',
        'network.wifiScan',
        'network.wifiConnect',
        'network.wifiDisconnect',
        'network.ethernetStatus',
        'network.ethernetConfigure',
      ]) {
        final found = TillOps.all.firstWhere((o) => o.name == op);
        expect(found.access, isA<OpenAccess>(), reason: op);
        expect(
          found,
          isA<Ask>(),
          reason: '$op обязана быть вопросом, не подпиской',
        );
      }
    });
  });

  group('разбор ответа: возврат по секрету — задача 5', () {
    test('терминал разбирается той же парой, что и terminals.list/self', () {
      final decoded = TillOps.terminalResume.decode({
        'terminal': {'id': 5, 'name': 'Касса у входа', 'pointMode': 'cashier'},
      });

      expect(decoded.id, 5);
      expect(decoded.name, 'Касса у входа');
      expect(decoded.pointMode, PointMode.cashier);
    });

    test('отсутствующий терминал в ответе — StateError, не null', () {
      // В отличие от `terminals.self`: заведение либо состоялось (терминал
      // в ответе), либо касса отказала кадром отказа раньше, чем разбор
      // сюда дошёл — третьего исхода «завёлся, но неизвестно как» нет.
      expect(
        () => TillOps.terminalResume.decode(const {}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
