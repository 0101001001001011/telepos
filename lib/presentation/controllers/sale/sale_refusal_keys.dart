import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Ключ `ErrorLocalizer` под один код отказа кассы.
///
/// [withMessage] значит «перевод принимает текст отказа доводом»: ключ
/// уезжает на экран как `<key>:<message>`, и словарь подставляет текст
/// внутрь фразы (имя товара в «нет на остатке», например). Без довода
/// текст отказа на экран не попадает вовсе — и это правильно для кодов,
/// чей текст написан по-русски внутри кассы.
typedef SaleRefusalKey = ({String key, bool withMessage});

/// Код отказа кассы → ключ, который умеет показать `ErrorLocalizer`.
///
/// # Почему эта карта живёт отдельным файлом, а не приватным `switch`
///
/// Она сторожимая. Добавить код отказа в контракт корзины
/// (`lib/domain/sale/cart_service.dart`) можно, не добавив сюда строку, и
/// узнать об этом неоткуда: неизвестный код уезжает на экран запасным
/// выходом `error.save_failed:<текст>`, и экран не пуст — он просто
/// говорит по-русски в казахском интерфейсе. Сторож
/// `test/architecture/sale_refusal_codes_localized_test.dart` читает
/// **исходник** контракта, собирает коды оттуда и требует строку здесь.
/// Приватный `switch` внутри контроллера сторожу не виден — отсюда
/// отдельный публичный файл.
const Map<String, SaleRefusalKey> saleRefusalErrorKeys = {
  // ── касса, смена, начало чека ─────────────────────────────────────────
  //
  // Три кода, брошенные **строковым литералом мимо реестра корзины**:
  // `till_not_configured` и `sale_not_started` — из `LocalCartService`,
  // `shift_not_open` — из `SaleInitiationUseCaseImpl`, чей отказ
  // `LocalCartService.start` пробрасывает наружу как свой. Разбор,
  // читавший один реестр, их не нашёл; сторож карты читает и реализацию.
  'till_not_configured': (
    key: 'error.till_not_configured_sale',
    withMessage: false,
  ),
  'shift_not_open': (key: 'error.shift_not_open', withMessage: false),
  'sale_not_started': (key: 'error.sale_not_started', withMessage: false),

  // ── корзина ───────────────────────────────────────────────────────────
  //
  // `cart_stale` и `cart_wrong_receipt` разведены не для красоты: первое
  // лечится повтором команды, второе — не лечится вовсе, и фразы у них
  // разные именно поэтому (докстринг `cartWrongReceiptCode`).
  cartStaleCode: (key: 'error.cart_stale', withMessage: false),
  cartWrongReceiptCode: (key: 'error.cart_wrong_receipt', withMessage: false),
  cartNotStartedCode: (key: 'error.cart_not_started', withMessage: false),
  cartLineNotFoundCode: (key: 'error.line_not_found', withMessage: false),
  cartInvalidAmountCode: (key: 'error.invalid_amount', withMessage: false),
  cartDeferredTakenCode: (key: 'error.deferred_taken', withMessage: false),
  cartNotEmptyCode: (key: 'error.cart_not_empty', withMessage: false),
  cartProductNotFoundCode: (key: 'error.product_not_found', withMessage: true),
  // Довод — имя товара: без него кассир не поймёт, какой из чека.
  cartProductHasNoPriceCode: (
    key: 'error.product_has_no_price',
    withMessage: true,
  ),
  cartSellingHoursBannedCode: (
    key: 'error.selling_hours_banned',
    withMessage: true,
  ),
  cartDeferredNotFoundCode: (
    key: 'error.deferred_not_found',
    withMessage: false,
  ),
  cartEmptyCode: (key: 'error.receipt_empty', withMessage: false),

  // ── уступка: право, политика, предел, подтверждение (задача 12) ───────
  //
  // Все три — **с текстом**, и это единственный случай в карте, где текст
  // обязателен по существу, а не по вкусу. Отказ «скидка больше предела» без
  // числа не говорит кассиру, до скольки ему можно; отказ «запрещено
  // настройками» без указания, какой именно настройкой, отправляет искать её
  // по всем экранам; порог подтверждения без числа не отличим от предела.
  // Русский текст внутри национальной фразы — та же цена, что у
  // `error.insufficient_stock`, и заплачена она за то же: без довода отказ
  // перестаёт быть действием и становится сообщением.
  cartDeniedPolicyCode: (key: 'error.denied_policy', withMessage: true),
  cartDeniedLimitCode: (key: 'error.denied_limit', withMessage: true),
  cartApprovalRequiredCode: (key: 'error.approval_required', withMessage: true),

  // ── слой провода: коды, доезжающие до кассира через продажу ───────────
  //
  // Круг правки 3. Ветвь `feat/browser-sale-wt-cart` превращает любой код
  // провода в отказ контроллера, и в день её слияния эти четыре пошли бы
  // сюда. Без строки здесь они вывалились бы запасным выходом — русским
  // текстом, написанным внутри кассы.
  'forbidden': (key: 'error.not_allowed', withMessage: false),
  'no_sale_module': (key: 'error.no_sale_module', withMessage: false),
  'terminal_in_body': (key: 'error.terminal_in_body', withMessage: false),
  'wholesale_in_start': (key: 'error.wholesale_in_start', withMessage: false),

  // ── оплата и возврат: заведено слиянием (2026-09-07) ──────────────────
  //
  // Девятнадцать кодов, каждый из которых доезжает до кассира через экран
  // оплаты или возврата, и ни одного не было в карте. Дефект не внесён ни
  // одной ветвью: сторож словаря — задача 23, коды — задачи 14, 16 и 19, и
  // порознь ни одна ветвь его увидеть не могла. Тексты — без довода
  // (`withMessage: false`): русская фраза, написанная внутри кассы, кассиру
  // с казахским интерфейсом не нужна, а всё, что ему нужно знать, сказано
  // самим переводом.
  'pay_receipt_not_found': (
    key: 'error.pay_receipt_not_found',
    withMessage: false,
  ),
  'pay_not_owner': (key: 'error.pay_not_owner', withMessage: false),
  'payment_already_taken': (
    key: 'error.payment_already_taken',
    withMessage: false,
  ),
  'payment_insufficient': (
    key: 'error.payment_insufficient',
    withMessage: false,
  ),
  'payment_account_missing': (
    key: 'error.payment_account_missing',
    withMessage: false,
  ),
  'payment_account_not_allowed': (
    key: 'error.payment_account_not_allowed',
    withMessage: false,
  ),
  // Задача 14: сумма строк оплаты не сошлась с суммой чека. Заменил
  // `payment_account_conflict`, который существовал только ради старого
  // уникального ключа `Payments` и вместе с ним снят.
  'payment_unbalanced': (key: 'error.payment_unbalanced', withMessage: false),
  // Задача 14: вид выключен в настройках кассы (про кассу целиком),
  // и вида нет в справочнике (чек приехал с чужой кассы). Отдельные
  // ключи от `payment_type_not_allowed` — та беда про рабочее
  // место и лечится на другом терминале, эти две — только в
  // настройках.
  'payment_kind_inactive': (
    key: 'error.payment_kind_inactive',
    withMessage: false,
  ),
  'payment_kind_unknown': (
    key: 'error.payment_kind_unknown',
    withMessage: false,
  ),
  // Задача 22: три беды намерения QR, и они лечатся РАЗНЫМ — потому три
  // ключа, а не один. «Намерения нет» — кадр назвал чужой ключ, лечится
  // перечитыванием; «не оплачено» — покупатель ещё не подтвердил,
  // лечится ожиданием; «уже в чеке» — деньги разобраны, лечится поиском
  // того чека. Одно слово на три беды отправило бы кассира не туда.
  //
  // `withMessage: true` у последнего: в тексте едет НОМЕР чека, которым
  // деньги уже закрыты, и без него кассиру нечего искать.
  'qr_intent_unknown': (key: 'error.qr_intent_unknown', withMessage: false),
  'qr_intent_not_paid': (key: 'error.qr_intent_not_paid', withMessage: false),
  'qr_intent_already_settled': (
    key: 'error.qr_intent_already_settled',
    withMessage: true,
  ),
  // Вход в оплату по QR. `qr_intent_live` — отказ кассы: на чеке уже ждёт
  // другой код, и лечится он отменой прежнего, а не повтором. Восемь кодов
  // провайдера (`kQrRefusalCodes`) — без текста: слова провайдера написаны
  // по-русски внутри кассы (`HttpQrPaymentProvider`), а кассиру нужно
  // различить «нет связи» (ждать, касса повторит) и «отклонил» (другой
  // способ оплаты).
  'qr_intent_live': (key: 'error.qr_intent_live', withMessage: false),
  'qr_not_configured': (key: 'error.qr_not_configured', withMessage: false),
  'qr_network': (key: 'error.qr_network', withMessage: false),
  'qr_timeout': (key: 'error.qr_timeout', withMessage: false),
  'qr_provider_busy': (key: 'error.qr_provider_busy', withMessage: false),
  'qr_malformed_reply': (key: 'error.qr_malformed_reply', withMessage: false),
  'qr_unknown_intent': (key: 'error.qr_unknown_intent', withMessage: false),
  'qr_rejected': (key: 'error.qr_rejected', withMessage: false),
  'qr_reverse_unsupported': (
    key: 'error.qr_reverse_unsupported',
    withMessage: false,
  ),
  // Задача 21: девять бед подарочного сертификата. Каждая названа своим
  // кодом, потому что каждая лечится **по-своему**, и кассир обязан
  // услышать, что именно делать: перенабрать номер, перенабрать ПИН,
  // позвать владельца, взять другую бумажку, убрать повтор, повторить
  // оплату, позвать администратора.
  //
  // `withMessage: false` — как и у всей семьи оплаты: русская фраза,
  // написанная внутри кассы, кассиру с казахским интерфейсом не нужна.
  // **Номер сертификата при этом теряется**, и это осознанная цена:
  // бумажка у кассира в руках, а вкладывать номер в перевод значило бы
  // заводить довод каждому из девяти ключей ради строки, которую и так
  // видно.
  'certificate_unknown': (key: 'error.certificate_unknown', withMessage: false),
  'certificate_pin_wrong': (
    key: 'error.certificate_pin_wrong',
    withMessage: false,
  ),
  // ПИН не набран (2026-09-15): лечится вводом ПИНа, а не перенабором —
  // своё слово рядом с «не подошёл».
  'certificate_pin_required': (
    key: 'error.certificate_pin_required',
    withMessage: false,
  ),
  // Замок перебора (2026-09-13): лечится ожиданием, а не перенабором, и
  // потому своё слово. Без текста — число минут в русской фразе кассы
  // кассиру с казахским интерфейсом не нужно; «подождите» сказано самим
  // переводом.
  'certificate_rate_limited': (
    key: 'error.certificate_rate_limited',
    withMessage: false,
  ),
  'certificate_expired': (key: 'error.certificate_expired', withMessage: false),
  'certificate_exhausted': (
    key: 'error.certificate_exhausted',
    withMessage: false,
  ),
  'certificate_duplicate': (
    key: 'error.certificate_duplicate',
    withMessage: false,
  ),
  'certificate_race': (key: 'error.certificate_race', withMessage: false),
  'certificate_account_missing': (
    key: 'error.certificate_account_missing',
    withMessage: false,
  ),
  'certificate_number_taken': (
    key: 'error.certificate_number_taken',
    withMessage: false,
  ),
  'certificate_nominal_invalid': (
    key: 'error.certificate_nominal_invalid',
    withMessage: false,
  ),
  'debt_customer_required': (
    key: 'error.debt_customer_required',
    withMessage: false,
  ),
  // Задача 16: на этой кассе в долг не торгуют — тумблер мастера
  // настройки выключен. Отдельный ключ от `debt_customer_required`:
  // первая беда лечится выбором покупателя на кассе, вторая — в
  // настройках кассы, и одно слово на две отправило бы кассира не туда.
  'debt_not_sold_here': (key: 'error.debt_not_sold_here', withMessage: false),
  'debt_account_missing': (
    key: 'error.debt_account_missing',
    withMessage: false,
  ),
  'bonus_account_missing': (
    key: 'error.bonus_account_missing',
    withMessage: false,
  ),
  // Задача 23: три беды зачёта аванса, и лечатся они тремя разными
  // действиями — выбрать покупателя, завести ему расчётный счёт,
  // разобраться, куда делся аванс. Один ключ на три отправил бы
  // кассира не туда в двух случаях из трёх.
  'prepayment_customer_required': (
    key: 'error.prepayment_customer_required',
    withMessage: false,
  ),
  'prepayment_account_missing': (
    key: 'error.prepayment_account_missing',
    withMessage: false,
  ),
  'prepayment_insufficient': (
    key: 'error.prepayment_insufficient',
    withMessage: false,
  ),
  // Задача 24: рассрочка. Отказов шесть, и каждый лечится своим
  // действием — назвать другой срок, взять меньший первый взнос, выбрать
  // схему из списка, разобраться с прошлым договором покупателя. Один
  // ключ на все шесть отправил бы кассира не туда в пяти случаях.
  //
  // `withMessage: false` у всех: текст кассы несёт числа для журнала
  // (какой срок назван, сколько осталось), а кассиру нужно действие, а
  // не арифметика. Исключений здесь нет — в отличие от
  // `qr_intent_already_settled`, где номер чужого чека и есть то, что
  // кассир пойдёт искать.
  //
  // Кодов **погашения** (`credit_overpayment`, `credit_contract_unknown`
  // и родня) здесь нет намеренно: они не достижимы из узла продажи —
  // их бросает экран договоров, который показывает фразу кассы целиком,
  // вместе с названным остатком. Сторож их и не требует; вписать их сюда
  // значило бы завести строки под коды, которых на этом пути не бывает,
  // и проверка 5 того же сторожа («в карте нет лишнего») покраснела бы
  // по делу.
  'credit_term_invalid': (key: 'error.credit_term_invalid', withMessage: false),
  'credit_principal_invalid': (
    key: 'error.credit_principal_invalid',
    withMessage: false,
  ),
  'credit_fee_invalid': (key: 'error.credit_fee_invalid', withMessage: false),
  'credit_scheme_unknown': (
    key: 'error.credit_scheme_unknown',
    withMessage: false,
  ),
  'credit_overdue': (key: 'error.credit_overdue', withMessage: false),
  'credit_contract_duplicate': (
    key: 'error.credit_contract_duplicate',
    withMessage: false,
  ),
  'loyalty_customer_unknown': (
    key: 'error.loyalty_customer_unknown',
    withMessage: false,
  ),
  'amount_exceeds_receipt': (
    key: 'error.amount_exceeds_receipt',
    withMessage: false,
  ),
  'card_charge_unproven': (
    key: 'error.card_charge_unproven',
    withMessage: false,
  ),
  // Задача 41: сломанная привязка платёжного терминала. Текст кассы — для
  // журнала; кассиру нужно действие.
  'card_terminal_misconfigured': (
    key: 'error.card_terminal_misconfigured',
    withMessage: false,
  ),
  'payment_type_not_allowed': (
    key: 'error.payment_type_not_allowed',
    withMessage: false,
  ),
  'payments_unavailable': (
    key: 'error.payments_unavailable',
    withMessage: false,
  ),
  'no_refund_service': (key: 'error.no_refund_service', withMessage: false),
  'refund_abandon_is_till_side': (
    key: 'error.refund_abandon_is_till_side',
    withMessage: false,
  ),
  'no_answer': (key: 'error.no_answer', withMessage: false),
  // Перевод у этого кода был и до слияния — его показывает диалог
  // просроченной смены (`kShiftOverAgeError`, `sale_screen.dart`), — а
  // строки в карте не было: путь через оплату сторож увидел только теперь.
  'shift_over_age': (key: 'error.shift_over_age', withMessage: false),

  // ── всё остальное, что провод и касса могут отдать (2026-09-13) ───────
  //
  // Живая приёмка: `no_session` на поиске доехал до кассира «неизвестной
  // причиной (код no_session)». Сторож
  // `named_refusal_reaches_cashier_test.dart` с того дня собирает коды из
  // всего `lib/` и требует строку здесь каждому — 50 кодов из 127 её не
  // имели. Прежний белый список «кассиру не адресовано» снят: он угадывал
  // путь кода до экрана, а путь угадывался неверно.
  //
  // Все — без текста: текст этих отказов написан кассой по-русски для
  // журнала, а кассиру нужно действие.

  // Связь. Три кода одной беды — поток не поднялся, оборвался, подписка
  // кончилась, — и лечатся они одним: связь.
  'no_session': (key: 'error.connection_lost', withMessage: false),
  'stream_failed': (key: 'error.connection_lost', withMessage: false),
  'stream_ended': (key: 'error.connection_lost', withMessage: false),
  // Не «связь потеряна»: касса могла успеть сделать работу, и повтор без
  // взгляда на кассу — двойная работа.
  'run_incomplete': (key: 'error.run_incomplete', withMessage: false),
  // Кадр не той формы с любой стороны — разошлись версии.
  'bad_request': (key: 'error.wire_mismatch', withMessage: false),
  'bad_body': (key: 'error.wire_mismatch', withMessage: false),
  'not_a_frame': (key: 'error.wire_mismatch', withMessage: false),
  'not_a_request': (key: 'error.wire_mismatch', withMessage: false),
  'unknown_op': (key: 'error.wire_mismatch', withMessage: false),
  // Касса упала на операции — не по данным кассира.
  'handler_failed': (key: 'error.till_failed', withMessage: false),
  'guard_failed': (key: 'error.till_failed', withMessage: false),
  'run_failed': (key: 'error.till_failed', withMessage: false),

  // Сеанс и рабочее место.
  'unauthorized': (key: 'error.session_expired', withMessage: false),
  'terminal_changed': (key: 'error.terminal_changed', withMessage: false),
  'unknown_terminal': (key: 'error.unknown_terminal', withMessage: false),
  'already_configured': (key: 'error.already_configured', withMessage: false),
  'cannot_delete_self': (key: 'error.cannot_delete_self', withMessage: false),
  'pairing_code_invalid': (
    key: 'error.pairing_code_invalid',
    withMessage: false,
  ),
  'terminal_limit_reached': (
    key: 'error.terminal_limit_reached',
    withMessage: false,
  ),
  'terminal_secret_invalid': (
    key: 'error.terminal_secret_invalid',
    withMessage: false,
  ),

  // Касса, собранная не полностью. Раньше — белый список «вопрос сборки»;
  // вопрос сборки, но видит его человек у терминала, и ему надо сказать,
  // к кому идти.
  'no_drivers': (key: 'error.no_drivers', withMessage: false),
  'no_network_module': (key: 'error.no_network_module', withMessage: false),
  'no_session_registry': (key: 'error.no_session_registry', withMessage: false),
  'no_backup_transport': (key: 'error.no_backup_transport', withMessage: false),
  'backup_not_found': (key: 'error.backup_not_found', withMessage: false),
  'certificates_unavailable': (
    key: 'error.certificates_unavailable',
    withMessage: false,
  ),
  'prepayment_intake_unavailable': (
    key: 'error.prepayment_intake_unavailable',
    withMessage: false,
  ),

  // Приём аванса покупателя — требование заказчика 2026-09-18. Тексты у
  // всех трёх написаны по-русски внутри кассы
  // (`CustomerPaymentUseCaseImpl`), поэтому `withMessage: false`: довод
  // уходит в журнал, а кассир получает фразу своего языка.
  'prepayment_amount_invalid': (
    key: 'error.prepayment_amount_invalid',
    withMessage: false,
  ),
  'prepayment_tender_invalid': (
    key: 'error.prepayment_tender_invalid',
    withMessage: false,
  ),
  'prepayment_till_account_missing': (
    key: 'error.prepayment_till_account_missing',
    withMessage: false,
  ),
  'prepayment_intake_failed': (
    key: 'error.prepayment_intake_failed',
    withMessage: false,
  ),
  'prepayment_intake_key_missing': (
    key: 'error.prepayment_intake_key_missing',
    withMessage: false,
  ),

  // Выдача аванса деньгами — дыра ревизии 2026-09-19. Текст написан
  // по-русски внутри кассы (`CustomerPaymentUseCaseImpl.refundPrepayment`),
  // поэтому `withMessage: false`: довод уходит в журнал, кассир получает
  // фразу своего языка. Прочие отказы выдачи названы теми же кодами, что
  // у приёма, — одна беда не должна получать двух разных фраз в
  // зависимости от того, вносят деньги или выдают.
  'prepayment_refund_exceeds_balance': (
    key: 'error.prepayment_refund_exceeds_balance',
    withMessage: false,
  ),

  // Выдача аванса **по проводу** — решение заказчика 2026-09-18. Три кода
  // своих, и это не симметрия ради симметрии: фраза кассиру обязана
  // называть, что именно не поехало. «Заявка приёма без ключа» на экране
  // выдачи отправила бы его искать беду не там.
  'prepayment_refund_key_missing': (
    key: 'error.prepayment_refund_key_missing',
    withMessage: false,
  ),
  'prepayment_refund_failed': (
    key: 'error.prepayment_refund_failed',
    withMessage: false,
  ),
  'prepayment_refund_unavailable': (
    key: 'error.prepayment_refund_unavailable',
    withMessage: false,
  ),

  // Настройка оплаты по QR из браузера — решение заказчика 2026-09-18.
  // Текст отказа написан по-русски внутри кассы, поэтому
  // `withMessage: false`: довод уходит в журнал, владелец получает фразу
  // своего языка. Адресат — именно владелец кассы, а не «служебный код
  // сборки»: он стоит перед экраном настройки и обязан прочесть, почему
  // касса не берёт настройку, — иначе решит, что сохранил.
  'qr_setup_unavailable': (
    key: 'error.qr_setup_unavailable',
    withMessage: false,
  ),

  // Шаблон чека из браузера — решение заказчика 2026-09-18. Оба отказа
  // написаны по-русски внутри кассы, поэтому `withMessage: false`: довод
  // уходит в журнал, владелец получает фразу своего языка. Адресат —
  // владелец кассы, стоящий перед экраном шаблона: он обязан прочесть,
  // почему касса не взяла правку, — иначе решит, что сохранил.
  'receipt_templates_unavailable': (
    key: 'error.receipt_templates_unavailable',
    withMessage: false,
  ),
  'receipt_template_nameless': (
    key: 'error.receipt_template_nameless',
    withMessage: false,
  ),

  // Диагностика оборудования с планшета — план 2026-09-19. Отказ написан
  // по-русски внутри кассы, поэтому `withMessage: false`: довод уходит в
  // журнал, наладчик получает фразу своего языка.
  //
  // Адресат — наладчик, стоящий с планшетом у кассы, и путь до него
  // короткий: обе вкладки показывают отказ там же, где показали бы данные.
  // Без перевода он прочёл бы «неизвестная причина (код
  // diagnostics_unavailable)» — то есть ровно ту беду, ради которой сторож
  // `named_refusal_reaches_cashier_test` и заведён.
  'diagnostics_unavailable': (
    key: 'error.diagnostics_unavailable',
    withMessage: false,
  ),

  // Смена с браузерного терминала — решение заказчика 2026-09-18. Все четыре
  // написаны по-русски внутри кассы, поэтому `withMessage: false`.
  //
  // Не путать с соседним `shift_over_age` выше: тот запирает **продажу** и
  // говорит кассиру, что смену пора закрыть; эти четыре отвечают самому
  // закрытию и открытию.
  'shift_desk_not_open': (key: 'error.shift_desk_not_open', withMessage: false),
  'shift_desk_already_open': (
    key: 'error.shift_desk_already_open',
    withMessage: false,
  ),
  'shift_desk_actor_unknown': (
    key: 'error.shift_desk_actor_unknown',
    withMessage: false,
  ),

  // Возврат. Контроллер возврата показывает текст кассы сам
  // (`error.refund_refused:<текст>`); строки здесь — для пути через
  // `safeErrorText`, которым отказ доезжает до любого другого экрана.
  'refund_stale': (key: 'error.refund_stale', withMessage: false),
  'refund_wrong_draft': (key: 'error.refund_wrong_draft', withMessage: false),
  'refund_not_started': (key: 'error.refund_not_started', withMessage: false),
  'refund_empty': (key: 'error.refund_empty', withMessage: false),
  'receipt_not_found': (key: 'error.receipt_not_found', withMessage: false),
  'receipt_already_refunded': (
    key: 'error.receipt_already_refunded',
    withMessage: false,
  ),
  'receipt_not_refundable': (
    key: 'error.receipt_not_refundable',
    withMessage: false,
  ),
  'line_not_in_receipt': (key: 'error.line_not_in_receipt', withMessage: false),
  'sale_not_completed': (key: 'error.sale_not_completed', withMessage: false),
  'refund_busy': (key: 'error.refund_busy', withMessage: false),
  'refund_cannot_start': (key: 'error.refund_cannot_start', withMessage: false),
  'refund_installment_refused': (
    key: 'error.refund_installment_refused',
    withMessage: false,
  ),
  // Задача 26: безнал возвращается безналом. Причина внешней стороны —
  // в тексте кассы, поэтому экран возврата показывает его сам.
  'refund_cashless_unavailable': (
    key: 'error.refund_cashless_unavailable',
    withMessage: false,
  ),
  'refund_cashless_refused': (
    key: 'error.refund_cashless_refused',
    withMessage: false,
  ),
  'refund_kind_not_refundable': (
    key: 'error.refund_kind_not_refundable',
    withMessage: false,
  ),
  // Вид оплаты чека неизвестен этой кассе — ревизия 2026-09-19, дыра 2.
  // Фраза говорит словами, а не «повторите»: повтор не поможет, лечится
  // это заведением того же вида в справочнике (или возвратом на той
  // кассе, где он заведён).
  'refund_kind_unknown': (key: 'error.refund_kind_unknown', withMessage: false),

  // Сертификаты при возврате — решения заказчика 2026-09-16. Оба кода
  // лечатся действием кассира, а не повтором, и потому говорят словами:
  // первый — «возьмите реквизиты», второй — «возьмите живые деньги».
  'certificate_cash_refund_refused': (
    key: 'error.certificate_cash_refund_refused',
    withMessage: false,
  ),
  // Строка уходит на бумажку, а номера бумажки нет — ревизия 2026-09-19.
  // Повтор не поможет: лечится разбором строки чека, — поэтому фраза
  // говорит словами, как и два соседних кода.
  'certificate_refund_no_source': (
    key: 'error.certificate_refund_no_source',
    withMessage: false,
  ),
  'certificate_pays_certificate': (
    key: 'error.certificate_pays_certificate',
    withMessage: false,
  ),

  // Погашение рассрочки — экран договоров показывает фразу кассы целиком;
  // строки здесь — для пути через `safeErrorText`.
  'credit_contract_unknown': (
    key: 'error.credit_contract_unknown',
    withMessage: false,
  ),
  'credit_contract_not_active': (
    key: 'error.credit_contract_not_active',
    withMessage: false,
  ),
  'credit_overpayment': (key: 'error.credit_overpayment', withMessage: false),
  'credit_repayment_invalid': (
    key: 'error.credit_repayment_invalid',
    withMessage: false,
  ),
  'credit_allocation_race': (
    key: 'error.credit_allocation_race',
    withMessage: false,
  ),

  // Справочник видов оплаты (`PaymentKindRules`).
  'kind_tender_cannot_discount': (
    key: 'error.kind_tender_cannot_discount',
    withMessage: false,
  ),
  'kind_account_missing': (
    key: 'error.kind_account_missing',
    withMessage: false,
  ),
  'kind_counterparty_required': (
    key: 'error.kind_counterparty_required',
    withMessage: false,
  ),
  'kind_provider_required': (
    key: 'error.kind_provider_required',
    withMessage: false,
  ),
  'kind_fiscal_kind_required': (
    key: 'error.kind_fiscal_kind_required',
    withMessage: false,
  ),
  'kind_change_not_a_tender': (
    key: 'error.kind_change_not_a_tender',
    withMessage: false,
  ),
  'kind_system_immutable': (
    key: 'error.kind_system_immutable',
    withMessage: false,
  ),

  // ── подготовка чека к оплате ──────────────────────────────────────────
  checkoutEmptyCode: (key: 'error.receipt_empty', withMessage: false),
  checkoutMarkRequiredCode: (key: 'error.mark_required', withMessage: true),
  checkoutInsufficientStockCode: (
    key: 'error.insufficient_stock',
    withMessage: true,
  ),
  // Сообщение отказа — сам потолок кассы: экран называет его человеку.
  checkoutBigAmountCode: (key: 'error.big_amount_blocked', withMessage: true),
};

/// Отказ кассы → ключ для `ErrorLocalizer`.
///
/// Неизвестный код уходит как `error.save_failed:refusal(<код>): …`
/// (`namedRefusalText`), и `ErrorLocalizer` показывает «неизвестная причина
/// (код …)» — **без** текста кассы. Это запасной выход, а не путь: сторож
/// карты существует ровно затем, чтобы сюда не приходили коды `lib/`; сюда
/// попадает код кассы новее терминала.
///
/// До 2026-09-15 здесь уходил `WireRefusal.message` — русская фраза кассы
/// буквами в любом интерфейсе (проба `sale_refusal_fallback_text_test.dart`).
String saleRefusalErrorKeyOf(WireRefusal refusal) {
  final mapped = saleRefusalErrorKeys[refusal.code];
  if (mapped == null) return 'error.save_failed:${namedRefusalText(refusal)}';
  return mapped.withMessage ? '${mapped.key}:${refusal.message}' : mapped.key;
}
