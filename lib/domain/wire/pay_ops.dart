/// Шесть операций оплаты — пять денежных задачи 14 плана «Продажа с
/// браузерного терминала» (фаза 5) и `pay.troubles` задачи 16: беды
/// железа, случившиеся **после** того, как деньги записаны.
///
/// # Почему шесть, а не двадцать
///
/// У `PaymentNotifier` двадцать операций; правило отбора одно и записано
/// инвариантом I163: **по проводу едет то, что меняет правду о деньгах или
/// трогает железо**. Цифровая клавиатура, активное поле ввода, «без
/// сдачи», раскладка номиналов, выбор вида оплаты — состояние экрана: они
/// ничего не пишут, ничего не двигают и ни с каким устройством не
/// разговаривают. Круг по сети за нажатие цифры — это не осторожность, а
/// расход.
///
/// # Деньги — строкой, через единственную дверь
///
/// Каждое денежное поле кадра кладётся [wireMoney] и читается
/// `Decimal.parse` (I159). Сторож `test/architecture/money_over_wire_test
/// .dart` требует под денежным ключом **буквально** вызов этой функции —
/// не выражение, не обёртку, не склейку. Имена `change`, `cashReceived` и
/// `claimedChange` попали в его список ещё кругом правки 1 задачи 6,
/// из брифа **этой** задачи, — то есть правило было заведено до того, как
/// появилось что проверять, и здесь оно впервые действует по существу.
///
/// # Ответы кодируются здесь, а не в `till_operations.dart`
///
/// Тем же приёмом и по той же причине, что `cart_codec.dart`: сторож денег
/// читает только `lib/domain/wire/`. Собери касса ответ у себя — денежные
/// поля уехали бы мимо единственной двери и мимо сторожа, и правило I159
/// держалось бы на внимательности, а не на проверке.
library;

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/cart_codec.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_money.dart';
import 'package:telepos/domain/wire/wire_op.dart';

/// Довод [PaymentService.reserveBonus] на проводе.
typedef BonusAsk = ({int customerId, Decimal amount});

/// Довод [PaymentService.chargeCard] на проводе. `terminalId` здесь нет
/// намеренно — его берёт из **сеанса** тот, кто разбирает кадр (правило
/// задачи 10): имя рабочего места, названное телом кадра, — это «назови
/// чужое место и получи его эквайринг».
typedef CardAsk = ({Decimal amount, CartCommandMeta meta});

/// Довод [PaymentService.complete] на проводе. `terminalId` — из сеанса,
/// по той же причине, что и у [CardAsk].
typedef CompleteAsk = ({PaymentRequest request, CartCommandMeta meta});

class PayOps {
  const PayOps._();

  /// Счета, на которые касса принимает деньги.
  static const accounts = Ask<void, List<PaymentAccount>>(
    'pay.accounts',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: accountsFromWireJson,
  );

  /// Торгует ли эта касса в долг — задача 16.
  ///
  /// # Почему это операция, а не поле `setup.state`
  ///
  /// `setup.state` — [OpenAccess]: его читают до входа, с пустого экрана
  /// заставки. Настройка «здесь торгуют в кредит» — свойство торговой
  /// точки, и отдавать её всякому, кто открыл страницу, незачем: у неё
  /// есть свой законный читатель — экран оплаты, а он за сеансом.
  /// Поэтому право то же, что у остальных операций оплаты: `navSale`.
  ///
  /// # Почему это не «раскладка экрана» (I163)
  ///
  /// Правило отбора пропускает то, что **меняет правду о деньгах или
  /// трогает железо**, и держит за проводом состояние экрана. Это ни то
  /// ни другое по форме, но и не состояние экрана по существу: ответ
  /// живёт в базе кассы, у вкладки его нет и быть не может, а
  /// придуманный вкладкой он был бы вторым источником правды о том, что
  /// касса разрешает. Тот же довод, по которому по проводу едет
  /// [accounts]: список счетов сам по себе денег не двигает.
  ///
  /// **Ответом запрет не держится.** Касса отвечает
  /// [payDebtNotSoldHereCode] на `pay.complete` независимо от того,
  /// спрашивал ли кто-нибудь эту операцию.
  static const sellsInDebt = Ask<void, bool>(
    'pay.sellsInDebt',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: sellsInDebtFromWireJson,
  );

  /// Клиент лояльности по телефону.
  static const loyalty = Ask<String, LoyaltyCustomer?>(
    'pay.loyalty',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodePhone,
    decode: loyaltyFromWireJson,
  );

  /// Сколько бонуса касса согласна засчитать.
  static const bonus = Ask<BonusAsk, Decimal>(
    'pay.bonus',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeBonus,
    decode: _decodeBonus,
  );

  /// Провести карту через эквайринг рабочего места.
  ///
  /// Единственная операция каталога, трогающая железо, — и единственная
  /// причина, по которой она вообще едет по проводу: устройство стоит у
  /// кассы, а нажимает кнопку вкладка.
  static const card = Ask<CardAsk, CardCharge>(
    'pay.card',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeCard,
    decode: cardChargeFromWireJson,
  );

  /// Завершить оплату.
  ///
  /// **Право зависит от тела запроса, и это единственная такая операция в
  /// дереве.** `navSale` — постоянное требование; сверх него сторож
  /// спрашивает [payExtraPermissions]: продажа в долг требует
  /// `op.sellDebt`.
  ///
  /// Почему не две операции с постоянным правом: обе ветки — это **одна
  /// и та же** работа кассы над одним и тем же чеком, отличающаяся полем
  /// заявки. Развести их на `pay.complete`/`pay.completeDebt` значило бы
  /// завести две операции, которые обязаны вести себя одинаково во всём,
  /// кроме одного `if`, — и первый же расход (повтор, версия) пришлось бы
  /// чинить дважды. Развести право, а не работу, дешевле и честнее:
  /// сторож остаётся единственным местом, где право проверяется.
  static const complete = Ask<CompleteAsk, SaleOutcome>(
    'pay.complete',
    access: SessionAccess(
      needs: PermissionKeys.navSale,
      alsoNeeds: payExtraPermissions,
    ),
    encode: _encodeComplete,
    decode: saleOutcomeFromWireJson,
  );

  /// Чем кончились отправленные действия железа чека.
  ///
  /// Печать и ящик уходят с кассы `unawaited` (правило «оплата не ждёт
  /// железа»), поэтому их исход не может ехать в ответе `pay.complete`:
  /// к моменту ответа они ещё идут. Терминал спрашивает о них **после**
  /// того, как сказал кассиру об успехе оплаты, — и потому эта операция
  /// не удлиняет ни одного круга, за который платит покупатель.
  ///
  /// Право то же, что у остальных: `navSale`. Своего права не заведено —
  /// операция не двигает денег и не трогает железа, она только называет
  /// то, что уже случилось с чеком этого же рабочего места.
  static const troubles = Ask<int, List<CompletionTrouble>>(
    'pay.troubles',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeTroubles,
    decode: troublesFromWireJson,
  );

  /// Выпустить подарочный сертификат — задача 21.
  ///
  /// # Почему это отдельная операция, а не поле `pay.complete`
  ///
  /// Потому что выпуск — **не оплата товара**. Когда покупатель платит
  /// 5000 за сертификат, деньги в кассу приходят обычной строкой оплаты и
  /// обычной выручкой смены; сертификат в этом чеке — то, что покупают, а
  /// не то, чем платят. Полем заявки на оплату он стал бы утверждением
  /// «чек оплачен сертификатом», то есть «денег не приходило».
  ///
  /// # Право своё, и это не осторожность
  ///
  /// Выпуск создаёт обязательство из ничего, и `nav.sale` его не
  /// сторожит: кассир выписал бы себе бумажку на сто тысяч и отоварил её
  /// в соседнюю смену, а гашение такой бумажки **законно** — ни одна
  /// проверка оплаты не заметила бы. Разбор — докстринг
  /// [PermissionKeys.opIssueCertificate].
  ///
  /// **Сторож здесь — не единственная проверка, с ревизии второго фронта
  /// 2026-09-19.** `CertificateIssuer.issue` читает тот же ключ из
  /// обязательного довода полномочий, а `TillOperations` строит довод из
  /// сеанса тем же `_authorityOf`, что и команды корзины. Два места, каждое
  /// достаточно; второе — единственное для кассового экрана, у которого
  /// провода нет вовсе.
  static const certificateIssue = Ask<CertificateIssueAsk, GiftCertificate>(
    'pay.certificateIssue',
    // Два права: постоянное `nav.sale` каталога и своё
    // `op.issueCertificate` сверх него.
    //
    // Второе едет через [SessionAccess.alsoNeeds], потому что другого
    // места под второй ключ в описании нет ([needs] — один ключ). Но
    // читается оно **иначе, чем у `pay.complete`**, и разницу сторожит
    // проба: там множество прав **зависит от тела** (долг требует
    // `op.sellDebt`, наличные — нет), здесь оно постоянно. Тела, при
    // котором выпуск обязательства был бы безобиден, не существует.
    access: SessionAccess(
      needs: PermissionKeys.navSale,
      alsoNeeds: _issueCertificatePermission,
    ),
    encode: _encodeCertificateIssue,
    decode: certificateFromWireJson,
  );

  /// Сколько аванса внесено покупателем — **вход в зачёт аванса**.
  ///
  /// # Почему операция, а не поле ответа `pay.loyalty`
  ///
  /// Покупатель для аванса находится тем же поиском по телефону, и
  /// положить остаток в ответ лояльности было бы на один круг дешевле.
  /// Не положен по двум измеримым причинам:
  ///
  /// 1. **Отказ у аванса свой, а у поиска его нет.** Вид «аванс» заводится
  ///    выключенным (спека, ярус 6), и касса обязана сказать об этом
  ///    словами. Поле ответа лояльности отказать не может — выключенный
  ///    вид либо уронил бы сам поиск покупателя (а с ним и бонусы), либо
  ///    промолчал бы нулём, неотличимым от «внесённого нет».
  /// 2. **Спрашивается не один раз.** Остаток читается при выборе
  ///    покупателя, а решение кассир принимает позже; операция позволяет
  ///    спросить снова, не перезапуская поиск.
  ///
  /// # Право — `nav.sale`, как у соседей
  ///
  /// Тот же довод, что у `pay.loyalty`, отдающей бонусный остаток: чтение
  /// остатка покупателя, стоящего у кассы, денег не двигает. Двигает их
  /// `pay.complete`, и потолок с условной записью стоят там.
  ///
  /// Рабочего места операция не читает: сальдо покупателя одно на кассу.
  static const prepayment = Ask<int, Decimal>(
    'pay.prepayment',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeCustomer,
    decode: _decodePrepayment,
  );

  /// Принять аванс покупателя — требование заказчика 2026-09-18.
  ///
  /// # Почему это вообще появилось
  ///
  /// [prepayment] строкой выше — **чтение** остатка, вход в зачёт. Внести
  /// деньги вперёд браузерный терминал не умел вовсе: приём жил в одном
  /// кассовом диалоге, который зовёт `CustomerPaymentUseCase` из `GetIt`
  /// напрямую. Живая приёмка 2026-09-17 намерила это как дыру, а не как
  /// границу.
  ///
  /// # Почему это операция оплаты, а не «кассовая операция»
  ///
  /// Деньги приходят **живые** — наличными, картой, по QR — и ложатся в
  /// кассу той же строкой счёта, что выручка; разница только в том, что
  /// встречной строкой растёт не выручка, а сальдо покупателя. Это
  /// денежная работа кассира у кассы, и место ей рядом с остальными
  /// такими же.
  ///
  /// # Право: `nav.sale` плюс `op.creditRepay`, **постоянно**
  ///
  /// `nav.sale` — требование каталога целиком (сторож
  /// `pay_ops_access_test` проверяет его у каждой операции), и по существу
  /// оно верно: приём аванса делает кассир, стоящий за кассой.
  ///
  /// Своего ключа **не заводится**, и это не экономия: новый ключ без шага
  /// миграции тихо не достаётся ни одному существующему пользователю
  /// (докстринг `PermissionKeys.allPermissions`, «Правило на будущее»), а
  /// миграции у этой работы нет. Взят существующий
  /// [PermissionKeys.opCreditRepay], и он подходит по смыслу, а не по
  /// доступности: его докстринг описывает право как «кому можно принять
  /// деньги по чужому договору и уменьшить долг» — движение по счёту
  /// расчётов, которого не сторнирует никакой чек и которое не видно ни в
  /// инвентаризации, ни в выручке смены. Приём аванса — **та же самая**
  /// работа, повёрнутая другой стороной: тот же счёт, то же движение, и
  /// взнос покупателя с долгом сначала гасит долг, а авансом становится
  /// только остаток (докстринг `CustomerPaymentUseCaseImpl
  /// ._fiscalizeAdvance`). Кассиру ключ полагается по умолчанию
  /// (`roleDefaults`) и роздан существующим миграцией v45 — значит приём
  /// работает с первой минуты, а не «после того, как владелец вспомнит».
  ///
  /// `nav.cashOperation` рядом не ставится: два ключа уже есть, а третий
  /// отвечал бы на тот же вопрос четвёртым словом.
  ///
  /// Право **постоянно**, как у [certificateIssue], а не зависит от тела,
  /// как у [complete]: тела, при котором приём чужих денег на чужой счёт
  /// был бы безобиден, не существует.
  ///
  /// Рабочего места операция не читает и не называет: сальдо покупателя
  /// одно на кассу.
  static const prepaymentIntake =
      Ask<PrepaymentIntakeRequest, PrepaymentIntakeOutcome>(
        'pay.prepaymentIntake',
        access: SessionAccess(
          needs: PermissionKeys.navSale,
          alsoNeeds: _prepaymentIntakePermission,
        ),
        encode: _encodePrepaymentIntake,
        decode: prepaymentIntakeOutcomeFromWireJson,
      );

  /// Выдать аванс покупателя деньгами — решение заказчика 2026-09-18.
  ///
  /// # Почему это появилось только сейчас
  ///
  /// [prepaymentIntake] строкой выше научила терминал **вносить** деньги
  /// вперёд. Вернуть внесённое было нельзя ничем: `refundPrepayment`
  /// заведён ревизией 2026-09-19 (`63426a0f`), экран под ним — только на
  /// кассе, операции провода не существовало. Кассир с планшетом мог взять
  /// у покупателя аванс и не мог его отдать.
  ///
  /// # Почему отдельная операция, а не знак суммы у приёма
  ///
  /// Потому что это **другая работа с другими отказами**. Приём кладёт
  /// деньги на счёт покупателя и в кассу, выдача снимает их условной
  /// записью и может не состояться («аванса меньше, чем просят» —
  /// [prepaymentRefundExceedsBalanceCode], кода которого у приёма нет).
  /// Фискально это не чек аванса, а **документ возврата**, и основанием ему
  /// служит проводка приёма, которой у приёма быть не может. Минус в поле
  /// суммы заставил бы один обработчик разветвляться на две операции по
  /// знаку числа — и первый же кадр с `-0` спросил бы, какая из них.
  ///
  /// # Право — `nav.sale` плюс `op.creditRepay`, **постоянно**
  ///
  /// Тот же ключ и тот же разбор, что у [prepaymentIntake]: движение по
  /// счёту расчётов, которого не сторнирует никакой чек. Им же закрыт
  /// кассовый маршрут выдачи (`AppRoutes.prepaymentRefund`), и второй ключ
  /// здесь означал бы, что одно и то же действие закрыто на кассе одним
  /// словом, а с планшета — другим.
  ///
  /// Право **постоянно**: тела, при котором выдача чужих денег с чужого
  /// счёта была бы безобидна, не существует.
  ///
  /// # Идемпотентность — **до** того, как операция поехала
  ///
  /// У заявки обязателен ключ повтора, и это не копирование приёма из
  /// симметрии: обрыв провода после выдачи денег выглядит на экране
  /// отказом, и кассир выдаёт их второй раз — уже живыми, из ящика. Разбор
  /// в докстринге `PrepaymentRefundRequest.key`; кадр без ключа отказывается
  /// [prepaymentRefundKeyMissingCode] до первой записи.
  ///
  /// Рабочего места операция не читает и не называет: сальдо покупателя одно
  /// на кассу.
  static const prepaymentRefund =
      Ask<PrepaymentRefundRequest, PrepaymentRefundOutcome>(
        'pay.prepaymentRefund',
        access: SessionAccess(
          needs: PermissionKeys.navSale,
          alsoNeeds: _prepaymentRefundPermission,
        ),
        encode: _encodePrepaymentRefund,
        decode: prepaymentRefundOutcomeFromWireJson,
      );

  /// Что касса знает о подарочном сертификате — **вход в гашение**.
  ///
  /// # Право — `nav.sale`, и цена этого названа
  ///
  /// Гашение сертификата идёт под `nav.sale` (`pay.complete`), и вопрос
  /// «сколько на бумажке» — его первая половина: отдельное право на вопрос
  /// при общем праве на ответ ничего не запирало бы.
  ///
  /// **Предел и его замок:** ответ отличает «нет такого номера» от «ПИН не
  /// подошёл» (`certificatePinWrongCode` — уступка, принятая задачей 21), и
  /// до 2026-09-13 операция делала этот вопрос дешёвым для скрипта с сеансом
  /// кассира. С того дня касса пропускает вопрос через `CertificateThrottle`
  /// (`lib/backend/certificate_throttle.dart`) — по кассиру, по рабочему
  /// месту и по номеру, — и N+1-я неудача за окно получает
  /// `certificate_rate_limited`. Тот же замок стоит на `pay.complete` с
  /// сертификатами: иначе он был бы дверью в соседнюю операцию. Остаток
  /// бумажки с ПИНом без ПИНа не отдаётся (ПИН проверяется до разговора об
  /// остатке).
  ///
  /// Рабочего места операция не читает: тираж сертификатов один на кассу.
  static const certificate = Ask<CertificateAsk, GiftCertificate>(
    'pay.certificate',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeCertificateAsk,
    decode: certificateFromWireJson,
  );

  /// Перепечатать слип подарочного сертификата — решение заказчика
  /// 2026-09-18.
  ///
  /// # Что здесь чинилось, а что нет
  ///
  /// Слип при **выпуске** с планшета печатался и до этой операции: выпуск
  /// исполняет касса (`pay.certificateIssue` → `LocalCertificateIssuer`), а
  /// она печатает слип сама, внутри выпуска. Комментарий браузерной таблицы
  /// маршрутов утверждал обратное («печати слипа у вкладки не будет»), и это
  /// было неверно уже в день, когда он написан.
  ///
  /// Недостижим с планшета был **повтор** — то, ради чего кассир и приходит:
  /// бумажка не вышла, покупатель стоит у прилавка. Его и закрывает эта
  /// операция.
  ///
  /// # Почему вкладка называет номер, а не присылает бумажку
  ///
  /// Потому что слип — обязательство кассы на бумаге, и номинал на нём
  /// обязан быть кассиным. Кадр с полями сертификата дал бы вкладке
  /// напечатать любую сумму. Касса находит бумажку сама, тем же `lookup`,
  /// каким отвечает `pay.certificate`.
  ///
  /// # Право — `op.issueCertificate`, **постоянно**
  ///
  /// Тот же ключ, что у [certificateIssue], и по той же причине: слип
  /// печатает обязательство магазина. Тела, при котором это было бы
  /// безобидно, не существует.
  ///
  /// # Замок перебора — тот же, что у `pay.certificate`
  ///
  /// Ответ отличает «нет такого номера» от «ПИН не подошёл», как и у
  /// соседа, и без замка операция была бы **дверью** в него: перебирать ПИН
  /// можно было бы здесь, а пользоваться результатом — там. Разбор замка —
  /// `certificate_throttle.dart`.
  ///
  /// Рабочего места операция не читает: тираж сертификатов один на кассу, а
  /// печатает та касса, к которой подключён принтер.
  static const certificateSlip = Ask<CertificateAsk, GiftCertificate>(
    'pay.certificateSlip',
    access: SessionAccess(
      needs: PermissionKeys.navSale,
      alsoNeeds: _issueCertificatePermission,
    ),
    encode: _encodeCertificateAsk,
    decode: certificateFromWireJson,
  );

  // ── оплата по QR/СБП: вход ─────────────────────────────────────────────
  //
  // # Три операции, а не одна с режимом
  //
  // Разбор — у методов `PaymentService.startQr`: у трёх разные ответы на
  // «что будет при повторе». Режим в теле сделал бы право зависящим от
  // поля кадра, а такая операция в дереве одна (`pay.complete`) и названа
  // исключением.
  //
  // # Право — `nav.sale` у всех трёх
  //
  // Код QR — это та же оплата товара, что карта (`pay.card`, `nav.sale`):
  // деньги приходят **за этот чек** и ложатся в него строкой. Своё право
  // запирало бы кассира, которому оплата разрешена, от одного её способа —
  // а запрет способа у кассы уже есть и живёт в справочнике видов
  // (`payment_kind_inactive`). Отмена своего права не требует тем более:
  // она ничего не берёт и не отдаёт.
  //
  // # Правила опроса
  //
  // Спрашивает **вкладка**, кругом раз в две секунды, пока фаза `waiting`;
  // перестаёт на любой другой фазе, на закрытии экрана и на отмене. Каждый
  // вопрос — ровно один круг на кассе и не больше одного обращения к
  // провайдеру. **Сдаётся касса**, а не вкладка: терпение — настройка
  // кассы, и круг, пришедший после срока, отменяет код сам. Вкладка,
  // закрытая посреди ожидания, не оставляет код живым навсегда: касса
  // отменяет брошенные перед каждым новым кодом и при подъёме
  // (`QrPaymentDesk.sweepStale`).
  //
  // Рабочее место у всех трёх — из сеанса (запрет на имя в теле навешен
  // на карту продажи целиком).

  /// Показать покупателю код на сумму — завести намерение у провайдера.
  static const qrStart = Ask<QrStartAsk, QrTender>(
    'pay.qrStart',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeQrStart,
    decode: qrTenderFromWireJson,
  );

  /// Один круг ожидания.
  static const qrPoll = Ask<String, QrTender>(
    'pay.qrPoll',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeQrKey,
    decode: qrTenderFromWireJson,
  );

  /// Кассир прервал ожидание.
  static const qrCancel = Ask<String, QrTender>(
    'pay.qrCancel',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _encodeQrKey,
    decode: qrTenderFromWireJson,
  );

  /// Можно ли показать код QR — при открытии экрана оплаты (пункт 9 C,
  /// 2026-09-15). Ответ — код беды настройки или `null`; разбор в докстринге
  /// `PaymentService.qrUnavailableReason`. Адреса, кода и ключа провайдера в
  /// ответе нет — только код отказа.
  static const qrReadiness = Ask<void, String?>(
    'pay.qrReadiness',
    access: SessionAccess(needs: PermissionKeys.navSale),
    encode: _nothing,
    decode: qrReadinessFromWireJson,
  );

  /// Все операции оплаты. Список ведётся руками — тем же приёмом и по той
  /// же причине, что `TillOps.all` и `SaleOps.all`: перечислить константы
  /// класса без зеркал в Dart нечем, а зеркала под браузер запрещены.
  static const all = <WireOp<Object?, Object?>>[
    qrReadiness,
    accounts,
    sellsInDebt,
    loyalty,
    bonus,
    prepayment,
    prepaymentIntake,
    prepaymentRefund,
    certificate,
    card,
    certificateIssue,
    certificateSlip,
    complete,
    troubles,
    qrStart,
    qrPoll,
    qrCancel,
  ];
}

/// Права, которых тело запроса требует **сверх** постоянного `navSale`.
///
/// Читается сторожем (`WireGuard.check`) до вызова обработчика — I44,
/// I162. Функция чистая и объявлена на верхнем уровне затем, чтобы её
/// ссылку можно было положить в `const SessionAccess`: требование остаётся
/// частью **описания операции**, а не строкой внутри обработчика, которую
/// можно забыть написать.
///
/// Сегодня ключ здесь один — **`op.sellDebt`**, продажа в долг: остаток
/// чека ложится на баланс покупателя, то есть касса отдаёт товар за
/// запись в базе. До этой задачи у ключа не было ни одного читателя во
/// всём `lib/` (докстринг `PermissionKeys`: «ни одна из этих восьми строк
/// не читается ни одним вызовом `hasPermission`»).
///
/// **Множество, а не одно право, хотя ключ один — это не задел, а
/// починка.** Первая версия отдавала одно право, и круг правки 1 нашёл на
/// ней дыру: тело, требовавшее двух прав, проверялось по первому
/// применимому, второе не проверялось вовсе, и кадр проходил под правом,
/// которое у роли есть. Разбор — в докстринге `SessionAccess.alsoNeeds`.
///
/// **`op.cancelPayment` здесь больше нет, и это решение заказчика, а не
/// упущение.** Отмена уже проведённой оплаты приезжала сюда полем заявки
/// `cancelPrevious`; вместе с ней приезжали дыра выше, невозвращаемые
/// склад WMS, серийные номера и ингредиенты, двойное списание при
/// переоплате и отсутствие проверки владельца и срока смены. Отмена —
/// это отдельная работа со своим экраном, подтверждением и возвратом
/// всего, что тронуто, а не флаг в кадре. `op.cancelPayment` остаётся
/// **плацебо** — объявленным и никем не спрашиваемым, как `op.cashInOut`,
/// — и так сказано прямо, а не скрыто механизмом, который право читает и
/// обходит.
Set<String> payExtraPermissions(Map<String, Object?> body) => {
  // Рассрочка требует **того же** права, что и долг, — задача 24. Вопрос
  // один: «кому можно отдать товар за запись в базе». Второе право рядом
  // дало бы кассира, которому долг запрещён, а рассрочка разрешена, — то
  // есть запрет, снимаемый выбором кнопки. Разбор — в докстринге
  // `PermissionKeys.opCreditRepay`, где названо и обратное: у **погашения**
  // право своё, потому что вопрос там другой.
  if (body['type'] == PaymentType.debt.name ||
      body['type'] == PaymentType.installment.name)
    PermissionKeys.opSellDebt,
};

// --- Кодирование запросов ------------------------------------------------

Map<String, Object?> _nothing(void _) => const {};

Map<String, Object?> _encodePhone(String phone) => {'phone': phone};

Map<String, Object?> _encodeBonus(BonusAsk ask) => {
  'customerId': ask.customerId,
  'amount': wireMoney(ask.amount),
};

Map<String, Object?> _encodeCard(CardAsk ask) => {
  'amount': wireMoney(ask.amount),
  ...cartCommandMetaToWireJson(ask.meta),
};

Map<String, Object?> _encodeComplete(CompleteAsk ask) => {
  ...paymentRequestToWireJson(ask.request),
  ...cartCommandMetaToWireJson(ask.meta),
};

// --- Метка команды -------------------------------------------------------

// Пары здесь нет, и это решено при слиянии по подсказке задачи 9. Задача
// 14 завела **вторую** пару кодеков `CartCommandMeta` рядом со своей, и в
// одном дереве с `cart_codec.dart` они отличались не именем, а смыслом:
// здесь стояло `json['key']! as String`, то есть отсутствие ключа роняло
// разбор `TypeError`, и на провод уехало бы имя типа вместо названного
// отказа (I144). Пара из `cart_codec.dart` читает пропущенные ключи
// снисходительно и объясняет, почему именно так; берётся она, а эта
// снята. Форма кадра от этого не меняется: обе кладут `key`,
// `baseVersion` и `receiptNo` плоско в корень тела, как того требуют
// [payExtraPermission] и сторож владения.

// --- Заявка на оплату ----------------------------------------------------

Map<String, Object?> paymentRequestToWireJson(PaymentRequest request) => {
  'type': request.type.name,
  'cashReceived': wireMoney(request.cashReceived),
  'cardAmount': wireMoney(request.cardAmount),
  'bonusUsed': wireMoney(request.bonusUsed),
  // Зачёт аванса — задача 23. Деньгами по проводу он не едет: едет
  // **просьба** зачесть столько-то, а потолок ставит касса по своему
  // остатку. Тот же довод, что у `bonusUsed`, и он не про экономию
  // байтов: остаток аванса живёт в базе кассы, и позволить терминалу
  // назвать его значило бы позволить ему назначить себе денег.
  'prepaymentUsed': wireMoney(request.prepaymentUsed),
  if (request.prepaymentReference != null)
    'prepaymentReference': request.prepaymentReference,
  // Сдача, посчитанная терминалом. Едет **не для того, чтобы касса ею
  // пользовалась** — касса считает свою, — а для того, чтобы она
  // заметила расхождение и записала его в журнал (докстринг
  // `PaymentRequest.claimedChange`). Отсутствие поля — законный случай:
  // терминал вправе не считать сдачу вовсе.
  if (request.claimedChange != null)
    'claimedChange': wireMoney(request.claimedChange!),
  'accountId': request.accountId,
  'customerId': request.customerId,
  'customerBin': request.customerBin,
  'approvalCode': request.approvalCode,
  'cardMask': request.cardMask,
  'transactionId': request.transactionId,
  // Ключ намерения QR/СБП — задача 22. Едет **ключ**, а не сумма: сколько
  // денег в намерении, касса читает у себя в `payment_intents`
  // (докстринг `PaymentRequest.qrIntentKey`).
  //
  // **Этой строки не было до 2026-09-08.** Задача 22 написала поле,
  // читателя (`LocalPaymentService`) и три названных отказа — и не внесла
  // поле в кодек ни одной половиной. Оплата телефоном с браузерного
  // терминала не доезжала до кассы вовсе: кадр её не нёс, а покраснеть
  // было нечему — сторож кодека перечислял поля рукой и о новом не знал.
  // Теперь перечисляет их не рука: `pay_ops_request_roundtrip_test`
  // читает объявления класса из исходника и требует ключ на каждое.
  //
  // Ключ кладётся только когда намерение названо — по тому же доводу, что
  // у сертификатов и рассрочки: лишний `null` в самом частом кадре
  // провода ничего не значит, а разбор читает его отсутствие как «QR не
  // предъявлен».
  if (request.qrIntentKey != null) 'qrIntentKey': request.qrIntentKey,
  // Сертификаты — задача 21. Список, а не одно поле: два по тысяче за
  // чек на две тысячи — обычный день (докстринг
  // `PaymentRequest.certificates`).
  //
  // **Ключ кладётся только когда бумажки есть.** Пустой список в каждом
  // кадре оплаты — лишние байты на самом частом кадре провода, и они
  // ничего не значат: разбор ниже читает отсутствие ключа как «нет
  // сертификатов», а не как ошибку.
  if (request.certificates.isNotEmpty)
    'certificates': [
      for (final c in request.certificates)
        <String, Object?>{'number': c.number, if (c.pin != null) 'pin': c.pin},
    ],
  // Рассрочка — задача 24. Едут **срок и схема**, и ни одного денежного
  // поля: сумма договора это остаток чека, который касса считает сама, а
  // надбавки у договора, заключённого кассой, нет вовсе (разбор — в
  // докстринге `PaymentRequest`, раздел «Чего здесь НЕТ»).
  //
  // **Ключи кладутся только когда рассрочка выбрана.** Два лишних `null`
  // в каждом кадре оплаты ничего не значат: разбор ниже читает их
  // отсутствие как «рассрочки нет», а касса на `installment` без срока
  // отвечает названным отказом.
  //
  // Задача 24 заметила здесь образец, который копировать было нельзя:
  // `qrIntentKey` (задача 22) в кодек не попал вовсе, и завела на себя
  // `pay_ops_installment_wire_test`. Сам `qrIntentKey` внесён выше
  // 2026-09-08, а частный сторож заменён общим
  // (`pay_ops_request_roundtrip_test`): частный молчит ровно о том поле,
  // которого в нём не назвали.
  if (request.installmentTermMonths != null)
    'installmentTermMonths': request.installmentTermMonths,
  if (request.installmentScheme != null)
    'installmentScheme': request.installmentScheme,
};

/// Сертификаты из тела кадра.
///
/// **Читает снисходительно и молча выбрасывает мусор.** Строка без
/// `number` — не отказ разбора: `TypeError` из кодека уехал бы на провод
/// именем типа вместо названной причины (I144), а настоящий ответ на
/// «бумажки не назвали» даёт касса — она просто не найдёт, что гасить, и
/// потребует денег на всю сумму чека.
List<CertificateTender> _certificatesFromWireJson(Object? raw) {
  if (raw is! List) return const <CertificateTender>[];
  final out = <CertificateTender>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final number = item['number'];
    if (number is! String || number.trim().isEmpty) continue;
    final pin = item['pin'];
    out.add(CertificateTender(number: number, pin: pin is String ? pin : null));
  }
  return out;
}

PaymentRequest paymentRequestFromWireJson(Map<String, Object?> json) =>
    PaymentRequest(
      // Неизвестный или отсутствующий вид оплаты — наличные: то же
      // умолчание, с которым заводится `PaymentState` на экране. Отказом
      // это не делается намеренно — вид оплаты проверяет `payExtraPermission`
      // по строке, и чужая строка не должна давать долг.
      type: PaymentType.byWireName(json['type'] as String?) ?? PaymentType.cash,
      cashReceived: _money(json['cashReceived']),
      cardAmount: _money(json['cardAmount']),
      bonusUsed: _money(json['bonusUsed']),
      prepaymentUsed: _money(json['prepaymentUsed']),
      prepaymentReference: json['prepaymentReference'] as String?,
      claimedChange: _money(json['claimedChange']),
      accountId: json['accountId'] as int?,
      customerId: json['customerId'] as int?,
      customerBin: json['customerBin'] as String?,
      approvalCode: json['approvalCode'] as String?,
      cardMask: json['cardMask'] as String?,
      transactionId: json['transactionId'] as String?,
      // Ключ намерения QR/СБП — задача 22. Читается снисходительно, как
      // и срок рассрочки ниже: не-строка это кадр, собранный мимо
      // экрана, и `null` доедет до кассы как «QR не предъявлен», а не
      // уронит разбор `TypeError` — тот уехал бы на провод именем типа
      // вместо названной причины (I144). Пустая строка — тоже «не
      // предъявлен»: ключа `''` в `payment_intents` нет и быть не может,
      // а отказ `pay_qr_intent_unknown` на пустое имя лечит не ту беду.
      qrIntentKey: switch (json['qrIntentKey']) {
        final String key when key.trim().isNotEmpty => key,
        _ => null,
      },
      certificates: _certificatesFromWireJson(json['certificates']),
      // Число, а не «что приехало»: строка «12» в поле срока — это кадр,
      // собранный мимо экрана, и разбирать её снисходительно значило бы
      // подписывать договор по догадке. `null` доедет до кассы и получит
      // названный отказ `credit_term_invalid`.
      installmentTermMonths: json['installmentTermMonths'] is int
          ? json['installmentTermMonths']! as int
          : null,
      installmentScheme: json['installmentScheme'] as String?,
    );

// --- Ответы --------------------------------------------------------------

Map<String, Object?> accountsToWireJson(List<PaymentAccount> accounts) => {
  'accounts': accounts
      .map(
        (a) => <String, Object?>{
          'id': a.id,
          'name': a.name,
          'isDefault': a.isDefault,
        },
      )
      .toList(),
};

List<PaymentAccount> accountsFromWireJson(Map<String, Object?> json) =>
    (json['accounts']! as List)
        .cast<Map<String, Object?>>()
        .map(
          (a) => PaymentAccount(
            id: a['id']! as int,
            name: a['name']! as String,
            isDefault: a['isDefault'] == true,
          ),
        )
        .toList();

Map<String, Object?> loyaltyToWireJson(LoyaltyCustomer? customer) => {
  'found': customer != null,
  if (customer != null) ...{
    'id': customer.id,
    'phone': customer.phone,
    'name': customer.name,
    'bonusBalance': wireMoney(customer.bonusBalance),
  },
};

LoyaltyCustomer? loyaltyFromWireJson(Map<String, Object?> json) {
  if (json['found'] != true) return null;
  return LoyaltyCustomer(
    id: json['id']! as int,
    phone: json['phone']! as String,
    name: json['name']! as String,
    bonusBalance: Decimal.parse(json['bonusBalance']! as String),
  );
}

Map<String, Object?> sellsInDebtToWireJson(bool sells) => {'sellInDebt': sells};

/// Читает ответ `pay.sellsInDebt`.
///
/// Отсутствующее или незнакомое значение — `false`, а не `true`: умолчание
/// обязано быть тем, которое ничего не предлагает. Старая касса, не знающая
/// этой операции, до сюда не доходит вовсе (она отвечает `unknown_op`), а
/// вот усечённый ответ дошёл бы, и «поле потерялось» не должно читаться
/// как «здесь торгуют в кредит».
bool sellsInDebtFromWireJson(Map<String, Object?> json) =>
    json['sellInDebt'] == true;

/// Ответ `pay.qrReadiness`: код беды настройки QR или `null` — «можно».
Map<String, Object?> qrReadinessToWireJson(String? refusal) => {
  'refusal': refusal,
};

/// Читает ответ `pay.qrReadiness`.
///
/// Не строка — `null`, то есть «можно»: запрет всё равно держит
/// `pay.qrStart`, и кассир, увидевший живую панель на старой кассе, получит
/// тот же названный отказ на нажатии, что получал до этой операции.
String? qrReadinessFromWireJson(Map<String, Object?> json) {
  final refusal = json['refusal'];
  return refusal is String && refusal.isNotEmpty ? refusal : null;
}

Map<String, Object?> bonusToWireJson(Decimal allowed) => {
  'amount': wireMoney(allowed),
};

Decimal _decodeBonus(Map<String, Object?> json) =>
    Decimal.parse(json['amount']! as String);

Map<String, Object?> cardChargeToWireJson(CardCharge charge) => {
  'outcome': charge.outcome.name,
  if (charge.amount != null) 'amount': wireMoney(charge.amount!),
  'approvalCode': charge.approvalCode,
  'cardMask': charge.cardMask,
  'transactionId': charge.transactionId,
  'message': charge.message,
};

CardCharge cardChargeFromWireJson(Map<String, Object?> json) {
  final name = json['outcome'] as String?;
  return CardCharge(
    outcome: CardChargeOutcome.values.firstWhere(
      (o) => o.name == name,
      // Незнакомое слово значит «мы не знаем, провелась ли карта».
      // Считать такой ответ одобрением было бы худшим из трёх исходов;
      // `notConfigured` увёл бы кассира на ручной путь, будто устройства
      // нет. `declined` — единственный, который не двигает деньги и не
      // врёт про оборудование.
      orElse: () => CardChargeOutcome.declined,
    ),
    amount: _money(json['amount']),
    approvalCode: json['approvalCode'] as String?,
    cardMask: json['cardMask'] as String?,
    transactionId: json['transactionId'] as String?,
    message: json['message'] as String?,
  );
}

Map<String, Object?> saleOutcomeToWireJson(SaleOutcome outcome) => {
  'receiptNo': outcome.receiptNo,
  'posId': outcome.posId,
  'amount': wireMoney(outcome.amount),
  'change': wireMoney(outcome.change),
  'paid': wireMoney(outcome.paid),
  'debt': wireMoney(outcome.debt),
  'repeat': outcome.repeat,
  // Исход фискализации — задача 16. Едет **словом состояния**, а не
  // признаком «получилось»: терминалу надо различать «не требуется»,
  // «в очереди» и «не удалось», и три этих ответа не сводятся к булеву.
  'fiscal': outcome.fiscal.state.name,
  if (outcome.fiscal.sign != null) 'fiscalSign': outcome.fiscal.sign,
  if (outcome.fiscal.message != null) 'fiscalMessage': outcome.fiscal.message,
};

SaleOutcome saleOutcomeFromWireJson(Map<String, Object?> json) => SaleOutcome(
  receiptNo: json['receiptNo']! as int,
  posId: json['posId']! as int,
  amount: Decimal.parse(json['amount']! as String),
  change: Decimal.parse(json['change']! as String),
  paid: Decimal.parse(json['paid']! as String),
  debt: Decimal.parse(json['debt']! as String),
  repeat: json['repeat'] == true,
  fiscal: _fiscal(json),
);

/// Исход фискализации из кадра.
///
/// Незнакомое или отсутствующее слово — [FiscalState.notRequired], а не
/// отказ: старая касса без задачи 16 поля не пришлёт вовсе, и объявлять
/// её чеки нефискальными по молчанию значило бы врать в другую сторону.
SaleFiscalization _fiscal(Map<String, Object?> json) {
  final name = json['fiscal'] as String?;
  for (final state in FiscalState.values) {
    if (state.name == name) {
      return SaleFiscalization(
        state,
        sign: json['fiscalSign'] as String?,
        message: json['fiscalMessage'] as String?,
      );
    }
  }
  return SaleFiscalization.notRequired;
}

/// Денежное поле, которого могло не быть. `null` — поля нет; пустая
/// строка тоже `null`, а не ноль: ноль — это сумма, а «нечего сказать» —
/// не сумма.
Decimal? _money(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return Decimal.parse(raw);
}

// --- Вход в зачёты: аванс и сертификат ----------------------------------

/// Довод [PayOps.certificate] на проводе: номер бумажки и, если кассир его
/// набрал, ПИН.
typedef CertificateAsk = ({String number, String? pin});

Map<String, Object?> _encodeCustomer(int customerId) => {
  'customerId': customerId,
};

/// Остаток аванса — деньги, значит строкой и через единственную дверь
/// (I159).
Map<String, Object?> prepaymentToWireJson(Decimal balance) => {
  'amount': wireMoney(balance),
};

Decimal _decodePrepayment(Map<String, Object?> json) =>
    Decimal.parse(json['amount']! as String);

// --- Приём аванса: требование заказчика 2026-09-18 ----------------------

/// Право сверх `nav.sale` — **постоянное**, как у выпуска сертификата.
///
/// Разбор, почему взят существующий ключ, — в докстринге
/// [PayOps.prepaymentIntake]. Функция объявлена на верхнем уровне по той же
/// причине, что [_issueCertificatePermission]: её ссылку кладут в `const
/// SessionAccess`, и требование остаётся частью **описания операции**.
Set<String> _prepaymentIntakePermission(Map<String, Object?> body) => const {
  PermissionKeys.opCreditRepay,
};

Map<String, Object?> _encodePrepaymentIntake(PrepaymentIntakeRequest ask) => {
  // Ключ повтора — **первым полем и всегда**, в отличие от примечания ниже.
  // Условного `if` у него нет и быть не может: кадр без ключа это кадр, на
  // повтор которого касса ответит вторым приёмом денег (разбор — в
  // докстринге `PrepaymentIntakeRequest.key`).
  'key': ask.key,
  'customerId': ask.customerId,
  // Деньги по проводу — **строкой** и через единственную дверь (I159).
  // Сумма здесь — то, что кассир набрал: касса её не пересчитывает, ей
  // нечем — это не доля чека, а взнос.
  'amount': wireMoney(ask.amount),
  'tenderKindId': ask.tenderKindId,
  // Ключ кладётся только когда примечание есть — по тому же доводу, что у
  // ПИНа сертификата: пустая строка в кадре и «не писали» различаются, и
  // второе честнее.
  if (ask.note != null) 'note': ask.note,
};

/// Денежное поле **заявки**, прочитанное снисходительно.
///
/// Отдельно от [_money], и разница измерена пробой, а не предположена:
/// `_money` зовёт `Decimal.parse`, и строка «много» роняет разбор
/// `FormatException`. Для ответов кассы это правильно — их пишет сама касса,
/// и мусор там означал бы сломанный кодек, который лучше уронить громко. Для
/// **заявки** — нет: её пишет вкладка, вкладка не наша, и кадр, собранный
/// мимо экрана, обязан получить названный отказ
/// ([prepaymentAmountInvalidCode]), а не имя типа исключения, уехавшее на
/// провод (I144).
///
/// Ноль, а не `null`: ноль не положителен, и касса откажет тем же словом,
/// каким ответила бы на набранный кассиром ноль.
Decimal _tolerantMoney(Object? raw) {
  if (raw is! String) return Decimal.zero;
  return Decimal.tryParse(raw) ?? Decimal.zero;
}

/// Заявка из тела кадра.
///
/// Читает **снисходительно**, и это не небрежность: не-число в `customerId`
/// или мусор в сумме — кадр, собранный мимо экрана, и честный ответ ему
/// даёт касса названным отказом (`loyalty_customer_unknown`,
/// `prepayment_amount_invalid`), а не `TypeError`, уехавший на провод
/// именем типа (I144).
///
/// Отсутствующая сумма читается нулём, а не выдумывается: ноль не
/// положителен, и касса откажет [prepaymentAmountInvalidCode] — тем же
/// словом, каким ответила бы на набранный ноль.
PrepaymentIntakeRequest prepaymentIntakeFromWireJson(
  Map<String, Object?> json,
) => PrepaymentIntakeRequest(
  // Ключ **пустой строкой**, а не выдуманный здесь, и не `null`.
  //
  // Выдумать его тут было бы худшим из возможного: у каждого кадра ключ
  // получился бы свой, повторы перестали бы опознаваться все до одного, и
  // защита выглядела бы работающей, ничего не защищая. Пустая строка —
  // «ключа не было», и касса отвечает названным отказом
  // (`prepayment_intake_key_missing`) до первой записи.
  key: switch (json['key']) {
    final String key when key.trim().isNotEmpty => key,
    _ => '',
  },
  customerId: switch (json['customerId']) {
    final num id => id.toInt(),
    _ => 0,
  },
  amount: _tolerantMoney(json['amount']),
  // Вид оплаты нулём — вида с номером 0 в справочнике нет и быть не может
  // (`SystemPaymentKindIds` начинается с единицы), и касса ответит
  // `prepayment_tender_invalid`. Подставлять наличные было бы хуже всего:
  // кадр без вида уехал бы оператору наличными — ровно тот дефект, ради
  // снятия которого вид приёма вообще хранится (v47).
  tenderKindId: switch (json['tenderKindId']) {
    final num id => id.toInt(),
    _ => 0,
  },
  note: switch (json['note']) {
    final String note when note.trim().isNotEmpty => note,
    _ => null,
  },
);

/// Исход приёма в кадре ответа.
///
/// Сальдо покупателя — деньги, значит строкой (I159). Фискальные поля
/// кладутся только когда есть что сказать: их отсутствие читается как «чека
/// не было», и это законный случай (настройка выключена, весь взнос ушёл на
/// погашение долга).
Map<String, Object?> prepaymentIntakeOutcomeToWireJson(
  PrepaymentIntakeOutcome outcome,
) => {
  'operationId': outcome.operationId,
  'balance': wireMoney(outcome.balance),
  if (outcome.fiscalSign != null) 'fiscalSign': outcome.fiscalSign,
  if (outcome.fiscalError != null) 'fiscalError': outcome.fiscalError,
};

/// Разбор ответа.
///
/// Усечённый ответ не роняет вкладку: номер проводки без него — ноль,
/// сальдо — ноль. Это **не** «деньги не приняты» — сюда разбор доходит
/// только после успешного ответа кассы; отказ приезжает кадром отказа и
/// становится исключением раньше (`WtDispatcher`).
PrepaymentIntakeOutcome prepaymentIntakeOutcomeFromWireJson(
  Map<String, Object?> json,
) => PrepaymentIntakeOutcome(
  operationId: (json['operationId'] as num?)?.toInt() ?? 0,
  balance: _money(json['balance']) ?? Decimal.zero,
  fiscalSign: json['fiscalSign'] as String?,
  fiscalError: json['fiscalError'] as String?,
);

// --- Выдача аванса: решение заказчика 2026-09-18 ------------------------

/// Право сверх `nav.sale` — **постоянное**, тот же ключ, что у приёма.
///
/// Разбор, почему взят существующий [PermissionKeys.opCreditRepay], — в
/// докстринге [PayOps.prepaymentIntake]; почему тот же самый и у выдачи — в
/// докстринге [PayOps.prepaymentRefund]. Функция на верхнем уровне по той же
/// причине, что [_prepaymentIntakePermission]: её ссылку кладут в `const
/// SessionAccess`, и требование остаётся частью **описания операции**.
Set<String> _prepaymentRefundPermission(Map<String, Object?> body) => const {
  PermissionKeys.opCreditRepay,
};

Map<String, Object?> _encodePrepaymentRefund(PrepaymentRefundRequest ask) => {
  // Ключ повтора — **первым полем и всегда**, тем же правилом, что у приёма.
  // Условного `if` у него нет и быть не может: кадр без ключа это кадр, на
  // повтор которого касса ответит второй выдачей живых денег.
  'key': ask.key,
  'customerId': ask.customerId,
  // Деньги по проводу — **строкой** и через единственную дверь (I159).
  'amount': wireMoney(ask.amount),
  'tenderKindId': ask.tenderKindId,
  // Оба поля ниже кладутся только когда названы: «не называли» и «пустое»
  // различаются, и второе честнее — тот же довод, что у примечания приёма.
  if (ask.intakeOperationId != null)
    'intakeOperationId': ask.intakeOperationId,
  if (ask.note != null) 'note': ask.note,
};

/// Заявка выдачи из тела кадра.
///
/// Читает **снисходительно**, тем же правилом и с тем же доводом, что
/// [prepaymentIntakeFromWireJson]: кадр, собранный мимо экрана, обязан
/// получить названный отказ кассы, а не `TypeError`, уехавший на провод
/// именем типа (I144).
///
/// Ключ **пустой строкой**, а не выдуманный здесь: выдуманный получился бы
/// у каждого кадра свой, повторы перестали бы опознаваться все до одного, и
/// защита выглядела бы работающей, ничего не защищая.
///
/// Основание (`intakeOperationId`) читается только числом: строка там —
/// кадр мимо экрана, и сослаться на документ по мусору нельзя. `null`
/// значит «не назван», и касса выпишет возврат без основания — законный
/// случай (докстринг `CustomerPaymentUseCase.refundPrepayment`).
PrepaymentRefundRequest prepaymentRefundFromWireJson(
  Map<String, Object?> json,
) => PrepaymentRefundRequest(
  key: switch (json['key']) {
    final String key when key.trim().isNotEmpty => key,
    _ => '',
  },
  customerId: switch (json['customerId']) {
    final num id => id.toInt(),
    _ => 0,
  },
  amount: _tolerantMoney(json['amount']),
  // Вид оплаты нулём — вида с номером 0 в справочнике нет и быть не может, и
  // касса ответит `prepayment_tender_invalid`. Подставлять наличные было бы
  // худшим из возможного: кадр без вида выдал бы деньги из ящика.
  tenderKindId: switch (json['tenderKindId']) {
    final num id => id.toInt(),
    _ => 0,
  },
  intakeOperationId: switch (json['intakeOperationId']) {
    final num id => id.toInt(),
    _ => null,
  },
  note: switch (json['note']) {
    final String note when note.trim().isNotEmpty => note,
    _ => null,
  },
);

/// Исход выдачи в кадре ответа.
///
/// Сальдо покупателя — деньги, значит строкой (I159). Фискальные поля
/// кладутся только когда есть что сказать: их отсутствие читается как
/// «документа не было», и это законный случай (настройка выключена, узла
/// нет).
Map<String, Object?> prepaymentRefundOutcomeToWireJson(
  PrepaymentRefundOutcome outcome,
) => {
  'operationId': outcome.operationId,
  'balance': wireMoney(outcome.balance),
  if (outcome.fiscalSign != null) 'fiscalSign': outcome.fiscalSign,
  if (outcome.fiscalError != null) 'fiscalError': outcome.fiscalError,
};

/// Разбор ответа.
///
/// Усечённый ответ не роняет вкладку: номер проводки без него — ноль,
/// сальдо — ноль. Это **не** «деньги не выданы» — сюда разбор доходит только
/// после успешного ответа кассы; отказ приезжает кадром отказа и становится
/// исключением раньше (`WtDispatcher`).
PrepaymentRefundOutcome prepaymentRefundOutcomeFromWireJson(
  Map<String, Object?> json,
) => PrepaymentRefundOutcome(
  operationId: (json['operationId'] as num?)?.toInt() ?? 0,
  balance: _money(json['balance']) ?? Decimal.zero,
  fiscalSign: json['fiscalSign'] as String?,
  fiscalError: json['fiscalError'] as String?,
);

Map<String, Object?> _encodeCertificateAsk(CertificateAsk ask) => {
  'number': ask.number,
  // Ключ кладётся только когда ПИН набран: пустой ПИН и отсутствующий —
  // разные ответы кассы на бумажку без ПИНа не дают, но «не набирали»
  // честнее, чем пустая строка в кадре.
  if (ask.pin != null) 'pin': ask.pin,
};

/// Разбор снисходительный: не-строка в номере или ПИНе — кадр, собранный
/// мимо экрана, и честный ответ ему даёт касса (`certificate_unknown`,
/// `certificate_pin_wrong`), а не `TypeError`, уехавший на провод именем
/// типа (I144).
CertificateAsk certificateAskFromWireJson(Map<String, Object?> json) => (
  number: switch (json['number']) {
    final String number => number,
    _ => '',
  },
  pin: switch (json['pin']) {
    final String pin => pin,
    _ => null,
  },
);

// --- Оплата по QR/СБП ----------------------------------------------------

/// Довод [PayOps.qrStart]: сумма и метка попытки. `terminalId` — из сеанса.
typedef QrStartAsk = ({Decimal amount, CartCommandMeta meta});

Map<String, Object?> _encodeQrStart(QrStartAsk ask) => {
  'amount': wireMoney(ask.amount),
  ...cartCommandMetaToWireJson(ask.meta),
};

Map<String, Object?> _encodeQrKey(String intentKey) => {
  'intentKey': intentKey,
};

/// Ключ намерения из тела. Не-строка — пустая строка, и касса ответит
/// названным `qr_intent_unknown`, а не `TypeError` именем типа (I144).
String qrIntentKeyFromWireJson(Map<String, Object?> json) =>
    switch (json['intentKey']) {
      final String key => key,
      _ => '',
    };

/// Оплата по QR в кадре ответа.
///
/// **Здесь нет и не будет ни адреса провайдера, ни его ключа, ни его
/// имени, ни ид намерения на той стороне** — у [QrTender] этих полей нет
/// вовсе, и кодек не может положить то, чего у значения нет. Сторож —
/// проба `qr_secret_never_reaches_terminal_test`, которая ищет ключ во
/// всех ответах настоящего графа кассы.
Map<String, Object?> qrTenderToWireJson(QrTender t) => {
  'intentKey': t.intentKey,
  'phase': t.phase.name,
  'amount': wireMoney(t.amount),
  if (t.paidAmount != null) 'paidAmount': wireMoney(t.paidAmount!),
  if (t.qrPayload != null) 'qrPayload': t.qrPayload,
  if (t.receiptNo != null) 'receiptNo': t.receiptNo,
  if (t.secondsLeft != null) 'secondsLeft': t.secondsLeft,
  if (t.settledReceiptNo != null) 'settledReceiptNo': t.settledReceiptNo,
  if (t.refusalCode != null) 'refusalCode': t.refusalCode,
};

/// Разбор ответа.
///
/// Незнакомая фаза — [QrTenderPhase.cancelUnconfirmed], а не `waiting` и
/// не `failed`: «не знаем, что с оплатой» — ровно её смысл. `waiting`
/// показал бы покупателю код, по которому касса, может быть, уже не ждёт;
/// `failed` разрешил бы кассиру принять наличные поверх денег, которые ещё
/// могут прийти. Кнопка «проверить снова» у этой фазы спросит кассу ещё
/// раз.
QrTender qrTenderFromWireJson(Map<String, Object?> json) => QrTender(
  intentKey: json['intentKey'] as String? ?? '',
  phase:
      QrTenderPhase.byName(json['phase'] as String?) ??
      QrTenderPhase.cancelUnconfirmed,
  amount: _money(json['amount']) ?? Decimal.zero,
  paidAmount: _money(json['paidAmount']),
  qrPayload: json['qrPayload'] as String?,
  receiptNo: (json['receiptNo'] as num?)?.toInt(),
  secondsLeft: (json['secondsLeft'] as num?)?.toInt(),
  settledReceiptNo: (json['settledReceiptNo'] as num?)?.toInt(),
  refusalCode: json['refusalCode'] as String?,
);

Map<String, Object?> _encodeTroubles(int receiptNo) => {'receiptNo': receiptNo};

Map<String, Object?> troublesToWireJson(List<CompletionTrouble> troubles) => {
  'troubles': [
    for (final t in troubles)
      {'kind': t.kind.name, 'receiptNo': t.receiptNo, 'message': t.message},
  ],
};

/// Беды железа из кадра.
///
/// Незнакомый вид беды **пропускается**, а не читается как печать: врать
/// про то, что именно не сработало, хуже, чем промолчать о новом виде,
/// которого эта сборка терминала ещё не знает.
List<CompletionTrouble> troublesFromWireJson(Map<String, Object?> json) {
  final raw = json['troubles'];
  if (raw is! List) return const [];
  final out = <CompletionTrouble>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = item['kind'];
    final receiptNo = item['receiptNo'];
    if (receiptNo is! int) continue;
    for (final kind in CompletionTroubleKind.values) {
      if (kind.name != name) continue;
      out.add(
        CompletionTrouble(
          kind: kind,
          receiptNo: receiptNo,
          message: item['message'] as String? ?? '',
        ),
      );
    }
  }
  return out;
}

// --- Выпуск сертификата: задача 21 ---------------------------------------

/// Право сверх `nav.sale` — **постоянное**, а не по телу запроса.
///
/// Разница с [payExtraPermissions] названа здесь, чтобы их не спутали: у
/// `pay.complete` множество прав зависит от вида оплаты в теле, а выпуск
/// сертификата требует своего права **всегда**. Сторож меряет именно эту
/// разницу — вызовом функции двумя разными телами
/// (`pay_ops_access_test`), а не тем, объявлена ли она вовсе.
Set<String> _issueCertificatePermission(Map<String, Object?> body) => const {
  PermissionKeys.opIssueCertificate,
};

/// Что кассир просит выпустить.
@immutable
class CertificateIssueAsk {
  const CertificateIssueAsk({
    required this.number,
    required this.nominal,
    this.pin,
    this.expiresAt,
    this.receiptNo,
  });

  final String number;

  final Decimal nominal;

  /// ПИН в открытом виде. Касса тут же превращает его в хэш и текста не
  /// хранит.
  ///
  /// Прежняя редакция называла это «единственным местом, где ПИН вообще
  /// едет», и это было неверно уже при слиянии: набранный кассиром ПИН
  /// едет и в заявке оплаты (`PaymentRequest.certificates`), и в вопросе
  /// об остатке (`pay.certificate`). Обратно — ни в одном ответе.
  final String? pin;

  /// Когда истекает, секундами эпохи. `null` — бессрочный.
  final int? expiresAt;

  /// Чек, которым сертификат продан. `null` — тираж заведён не продажей.
  final int? receiptNo;
}

Map<String, Object?> _encodeCertificateIssue(CertificateIssueAsk ask) => {
  'number': ask.number,
  // Деньги по проводу — **строкой** (I159).
  'nominal': wireMoney(ask.nominal),
  if (ask.pin != null) 'pin': ask.pin,
  if (ask.expiresAt != null) 'expiresAt': ask.expiresAt,
  if (ask.receiptNo != null) 'receiptNo': ask.receiptNo,
};

CertificateIssueAsk certificateIssueFromWireJson(Map<String, Object?> json) =>
    CertificateIssueAsk(
      number: json['number'] as String? ?? '',
      nominal: _money(json['nominal']) ?? Decimal.zero,
      pin: json['pin'] as String?,
      expiresAt: (json['expiresAt'] as num?)?.toInt(),
      receiptNo: (json['receiptNo'] as num?)?.toInt(),
    );

/// Сертификат в кадре ответа.
///
/// **`pinHash` не едет ни одной веткой.** Он не нужен ни одному читателю
/// вкладки, а вкладка — не наша: отдать хэш значит отдать материал для
/// перебора всему, что видит кадр.
Map<String, Object?> certificateToWireJson(GiftCertificate c) => {
  'number': c.number,
  'nominal': wireMoney(c.nominal),
  'balance': wireMoney(c.balance),
  'status': c.status.code,
  'issuedAt': c.issuedAt,
  'expiresAt': c.expiresAt,
  'issuedReceiptNo': c.issuedReceiptNo,
};

GiftCertificate certificateFromWireJson(Map<String, Object?> json) =>
    GiftCertificate(
      // Ид кассе принадлежит, а вкладке не нужен: она обращается к
      // сертификату **номером**, и номер напечатан на бумажке.
      id: 0,
      number: json['number'] as String? ?? '',
      nominal: _money(json['nominal']) ?? Decimal.zero,
      balance: _money(json['balance']) ?? Decimal.zero,
      // Незнакомое состояние читается как «отозван», а не как «годен»:
      // тот же довод, что у `CertificateDao.toDomain`.
      status:
          CertificateStatus.byCode(json['status'] as String?) ??
          CertificateStatus.cancelled,
      issuedAt: (json['issuedAt'] as num?)?.toInt() ?? 0,
      expiresAt: (json['expiresAt'] as num?)?.toInt(),
      issuedReceiptNo: (json['issuedReceiptNo'] as num?)?.toInt(),
    );
