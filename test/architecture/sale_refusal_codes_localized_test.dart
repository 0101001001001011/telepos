/// Сторож переводов кодов отказа продажи — задача 23.
///
/// # Что он ловит и почему именно так
///
/// Он ловит **новый код отказа без перевода**, а не «нынешние коды
/// переведены». Разница существенная: список, переписанный в тест руками,
/// зеленеет навсегда в день, когда его написали, и следующий забытый код
/// проезжает мимо него молча — ровно так и появилась дыра, которую чинит
/// задача 23.
///
/// Поэтому коды **читаются из исходника** — обходом каталогов узла продажи,
/// — а не перечисляются здесь.
///
/// # Что именно обещано, и что нет (круг правки 1)
///
/// Обещано: код, **брошенный** из узла продажи строкой или именованной
/// константой, без перевода не пройдёт. Сюда входят обе формы объявления
/// (`const x = '…';` и `static const x = '…';` внутри класса), любой файл
/// под [saleRefusalCodeRoots] — в том числе созданный завтра, — и всё, что
/// объявлено в двух контрактах, брошено оно уже или ещё нет.
///
/// Первая редакция обещала это же, а делала меньше, и обе дыры были найдены
/// диверсией:
/// - выражение требовало имени вида `\w*Code` — конвенция, не закреплённая
///   нигде, и `CartCodes.frozen` проходил молча;
/// - файлы были перечислены руками — пять из двадцати восьми, и отказ из
///   `sale_use_case_impl.dart` был невидим.
///
/// **Не обещано** и названо вслух — одна вещь, и она измерена:
///
/// - **Код, собранный выражением** (`WireRefusal(_codeFor(x), …)`), сторожу
///   не по зубам. Но он и не проходит молча: такая форма красит проверку
///   «каждый довод сторож сумел прочитать». То же с именем, которое не
///   привязалось ни к одному объявлению, — кроме именованных мест проброса
///   ([saleRefusalPassThroughFiles]), где код приходит с провода в
///   исполнении и привязать его нельзя ничем. Разница между «не умею» и «не
///   заметил» здесь и есть весь смысл: первое видно, второе — нет.
///
/// Два прежних предела **сняты кругом правки 3**, а не переписаны:
/// - слой провода теперь в разведке (`till_operations.dart` и `lib/web`), а
///   четыре продажных кода — `forbidden`, `no_sale_module`,
///   `terminal_in_body`, `wholesale_in_start` — переведены;
/// - проверка «фраза взята из ARB» ходит и по собственным ключам
///   контроллера, а не только по карте: докстринг обещал это кругом 2, а
///   цикл был один.
///
/// Остаётся один настоящий: **расхождение ARB ↔ `lib/l10n/` сторожится
/// только для ключей продажи** — тех, что в карте, и тех, что нашла
/// [discoverSaleOwnErrorKeys]. Для прочих трёх с половиной тысяч ключей
/// словаря пару не сторожит никто.
///
/// # Что он намерил на дереве до правки (2026-09-06)
///
/// Кодов, достижимых кассиру через контракт корзины, оказалось **17**, а не
/// десять, как говорил разбор. Десять объявлены реестром корзины
/// (`cart_service.dart`), четыре — подготовкой чека к оплате
/// (`sale_checkout_service.dart`), и ещё три брошены **строковым литералом
/// мимо всякого реестра**: `till_not_configured`, `sale_not_started`
/// (`LocalCartService.start`, когда начало чека отказало, не назвав
/// причины) и `shift_not_open` (`SaleInitiationUseCaseImpl` — отказ
/// проезжает через `start` наружу как свой). Литералы важны отдельно:
/// сторож, читающий один только реестр, их бы не увидел.
///
/// Переведены были восемь из семнадцати. Девять уезжали на экран как
/// `error.save_failed:<русский текст>` — семь названных разбором плюс
/// `sale_not_started` и `shift_not_open`, которых разбор не нашёл.
///
/// # Проверки, и каждая нужна отдельно
///
///  1. **Сторож что-то нашёл.** Якоря против собственной слепоты.
///  2. **Каждый довод прочитан.** «Не умею разобрать» обязано быть видимым.
///  3. **У кода есть строка в карте.** Иначе он уходит запасным выходом.
///  4. **Белый список провода не гниёт и не спорит с картой.** Исключение
///     без срока годности превращается в мусор; код и в карте, и в списке
///     оставляет неясным, что с ним делают; пустой довод — это «руки не
///     дошли», записанное как решение.
///  5. **В карте нет строк под коды, которых в дереве нет.** Обратная
///     сторона: разведка, ставшая слишком широкой, тоже дефект.
///  6. **Ключ карты знает `ErrorLocalizer`.** Строка в карте, которую
///     словарь не разбирает, — это ключ на экране вместо фразы.
///  7. **Код, объявленный «с текстом», доносит текст.** Иначе кассир теряет
///     имя товара — ровно то слово, ради которого отказ назван.
///  8. **Фраза на экране взята из ARB** — и для карты, и для собственных
///     ключей контроллера. `ErrorLocalizer` читает порождённый `lib/l10n/`,
///     а `flutter test` его не перегенерирует: снятая строка ARB оставляла
///     сторожа зелёным до следующего `flutter gen-l10n`.
///  9. **Ключи, придуманные самим контроллером, тоже переведены.** Карта
///     сторожит коды, пришедшие от кассы; но `SaleController` кладёт в
///     состояние и собственные ключи, и `shift_over_age` — тот, что уезжает
///     на экран оплаты, — лежал в трёх словарях дословно по-русски.
/// 10. **Перевод свой в каждой из пяти локалей.** Генератор Flutter
///     подставляет строку шаблона (`intl_ru.arb`) вместо недостающей, и
///     проверка «локализовалось» такой подстановки **не видит**: казахский
///     интерфейс вернёт русскую фразу и будет выглядеть переведённым.
///     Поэтому сравнение идёт с русским текстом: он обязан отличаться.
@Tags(['architecture'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

import 'support/refusal_code_scan.dart';

/// Каталоги узла продажи целиком — обходом, а не списком файлов.
///
/// # Круг правки 1: список файлов был вторым дном той же дыры
///
/// До круга правки сторож читал **пять названных файлов**. В одном только
/// `lib/data/usecases/sale/` их шестнадцать, и отказ, брошенный из
/// шестнадцатого (`sale_use_case_impl.dart`), был для сторожа невидим —
/// то есть сторож, заведённый против забытого кода, сам забывал файлы.
/// Диверсия это подтвердила: `WireRefusal('drawer_stuck', …)` там прошёл
/// молча.
///
/// Обход каталога закрывает вопрос по построению: новый файл узла попадает
/// под сторожа в день, когда его создали, и делать для этого не надо
/// ничего.
///
/// # Круг правки 3: слой провода, и почему у исключения был срок
///
/// Круг правки 3 добавил сюда слой провода — и это не расширение ради
/// красоты, а срок, который иначе наступил бы молча.
///
/// В соседней живой ветви `feat/browser-sale-wt-cart` лежит
/// `wt_cart_service.dart`, превращающий **любой** код провода в отказ
/// контроллера. В день её слияния `forbidden`, `no_sale_module`,
/// `terminal_in_body` и `wholesale_in_start` пошли бы через карту продажи,
/// вывалились запасным выходом `error.save_failed:<русский текст>` — тот
/// самый дефект, ради которого задача существует, — и сторож промолчал бы.
/// Все четыре переведены сейчас, файл и каталог браузера в разведке, срока
/// больше нет.
///
/// Цена включения названа честно: `till_operations.dart` держит и служебный
/// словарь провода, к продаже отношения не имеющий. Он не переводится, а
/// перечислен поимённо в [saleWireCodesNotForCashier] — значит новый код в
/// этом файле краснеет, и автору придётся либо перевести его, либо вписать
/// с доводом. Это шумно для соседних задач и выбрано сознательно: громкий
/// отказ лучше тихого пропуска.
/// Задача 21 добавила `lib/domain/payment`, и добавила **корнем, а не
/// одним файлом**: подарочный сертификат объявляет коды там
/// (`gift_certificate.dart`), а бросает их отсюда — из `lib/data/sale`
/// и `lib/data/usecases/sale`. Без корня три довода читались бы как
/// «имя, которое не удалось привязать», то есть сторож краснел бы, не
/// умея сказать, что именно не так.
///
/// **`lib/data/payment` корнем НЕ стал, и это названо, а не забыто.**
/// Там лежит `PaymentKindCatalogImpl`, который бросает
/// `WireRefusal(refusal, …)` с кодом, известным только в исполнении, —
/// законный проброс, которого выражение сторожа разобрать не может.
/// Включить каталог значило бы либо завести ему исключение по файлу,
/// либо покрасить сторожа формой, а не дефектом. Цена включения названа:
/// шесть кодов сертификата, брошенных из `LocalCertificateIssuer`,
/// сторож **не видит** — и потому они объявлены реестром ниже, где
/// объявление само по себе считается кодом.
const saleRefusalCodeRoots = <String>[
  'lib/domain/sale',
  'lib/domain/usecases/sale',
  'lib/domain/payment',
  // Шаблон чека и смена с браузерного терминала — решение заказчика
  // 2026-09-18. Корнями, а не только реестрами: реестр объявляет коды
  // кодами, но **привязка имени к значению** собирается только с корней, и
  // без этих двух строк `WireRefusal(receiptTemplatesUnavailableCode, …)` в
  // `till_operations.dart` оставался бы именем, которого сторож не знает,
  // — то есть кодом без потребованного перевода. Найдено самим сторожем в
  // день правки, а не вычитано.
  'lib/domain/receipt',
  'lib/domain/shift',
  // Диагностика оборудования с планшета (план 2026-09-19) — корнем по тому
  // же доводу, что `lib/domain/receipt` строкой выше: без него
  // `WireRefusal(diagnosticsUnavailableCode, …)` в `till_operations.dart`
  // остался бы именем, которого сторож не знает, то есть кодом без
  // потребованного перевода. Найдено самим сторожем в день правки.
  'lib/domain/diagnostics',
  'lib/data/sale',
  'lib/data/usecases/sale',
  'lib/presentation/controllers/sale',
  'lib/backend/till_operations.dart',
  'lib/web',
];

/// Коды провода, которые кассиру не адресованы и потому не переводятся.
///
/// Каждый — с доводом, и довод обязан быть про **адресата**, а не про
/// «руки не дошли». Список проверяется на гниль: код, исчезнувший из
/// дерева, красит сторожа так же, как непереведённый.
///
/// # Пуст с 2026-09-13, и это решение, а не уборка
///
/// Девять кодов лежали здесь с доводом про **происхождение** («вопрос
/// сборки», «экран привязки»), а живая приёмка показала, что довод про
/// происхождение ничего не говорит о **пути**: `no_session`, соседний по
/// роду, доехал до кассира «неизвестной причиной» с экрана поиска. Все
/// девять переведены, а сторож `named_refusal_reaches_cashier_test.dart`
/// требует перевода каждому коду из всего `lib/` без исключений. Новая
/// запись сюда покраснит «и в карте, и в списке» — или, без строки в карте,
/// тот сторож.
const saleWireCodesNotForCashier = <String, String>{};

/// Места, где код отказа приходит **с провода**, а не объявляется здесь.
///
/// `throw WireRefusal(error.code, error.detail)` — законный проброс:
/// значение известно только в исполнении, и привязать его к объявлению
/// нельзя ничем. Разрешение именное, по файлу: молчать обо всех
/// непривязанных именах значило бы вернуть слепоту.
///
/// **`wt_cart_service.dart` вписан в день слияния (2026-09-07), и запись
/// закрывает меньше, чем кажется.** `WtCartService._named` объявляет
/// отказом кассы **любой** код провода, которого нет в его собственном
/// списке бед (`_wireCodes`): значение известно только в исполнении, и
/// разобрать довод сторож не может по построению — это и есть законный
/// проброс. Но у правила есть следствие, которого запись НЕ лечит и
/// которого не видит ни одна проверка этого сторожа:
///
/// - через продажу теперь достижимы `handler_failed`, `guard_failed`,
///   `not_a_request` (падение обработчика, падение сторожа, неразобранный
///   кадр) — их нет ни в карте [saleRefusalErrorKeys], ни в
///   [saleWireCodesNotForCashier], и они уедут на экран запасным выходом
///   `error.save_failed:<русский текст>`;
/// - `bad_request` и `unknown_terminal` лежат в
///   [saleWireCodesNotForCashier] с доводом про **происхождение** кода, а
///   не про **путь**: происхождение прежнее, а путь через продажу у них
///   появился, и по нему они доедут до кассира тем же запасным выходом.
///
/// Сторож этой разницы не отличает: он спрашивает «код переведён или
/// назван неадресованным», а не «каким путём код доходит до человека».
/// Остаток назван вслух, а не закрыт молча — переводы и пересмотр белого
/// списка идут отдельной работой после слияния.
const saleRefusalPassThroughFiles = <String>[
  'lib/web/wt_terminal_repository.dart',
  'lib/web/wt_cart_service.dart',
  // `WtRefundService._named` — тот же приём, что у корзины, и та же цена:
  // коды провода, не названные в карте, доедут до кассира запасным выходом.
  'lib/web/wt_refund_service.dart',
  // Задача 44: `WtSaleEditTerms.read` — отказ кассы на `sale.editTerms`
  // становится `WireRefusal` с тем же кодом, тем же приёмом.
  'lib/web/wt_sale_edit_terms.dart',
  // Задача 45: быстрые товары и правила сканера — тот же проброс кода кассы.
  'lib/web/wt_quick_product_catalog.dart',
  'lib/web/wt_scanner_rules.dart',
  // Пункт 11 ревизии 2026-09-19: `WtExpiryWarning.isPickedBatchExpired` —
  // тот же проброс кода кассы. Цена та же и здесь **мала**: единственный
  // читатель отказа — `SaleNotifier._warnIfExpired`, и он гасит его
  // строкой журнала. Кассиру этот код не показывается вовсе, потому что
  // предупреждение — не запрет: «спросить не удалось» и «не просрочено»
  // на экране продажи одинаковы.
  'lib/web/wt_expiry_warning.dart',
  // Пункт 12 ревизии 2026-09-19: `WtStockChanges.watch` — тот же проброс
  // кода кассы. Единственный читатель отказа — `StockRevision`, и он гасит
  // его пустым обработчиком: счётчик отвечает «изменилось», а не «почему
  // не смог», и кассиру этот код не показывается вовсе.
  'lib/web/wt_stock_changes.dart',
  // Приём аванса (2026-09-18): `WtPrepaymentIntakeService` переводит отказ
  // провода в `WireRefusal` с тем же кодом — тем же приёмом и с той же
  // ценой, что у соседей выше.
  'lib/web/wt_payment_service.dart',
  // Настройка оплаты по QR из браузера (2026-09-18): `WtQrProviderSetup._named`
  // переводит отказ провода в `WireRefusal` с тем же кодом — тем же приёмом
  // и с той же ценой, что у соседей выше.
  'lib/web/wt_qr_provider_setup.dart',
  // Шаблон чека и смена с браузерного терминала (решение заказчика
  // 2026-09-18): `WtReceiptTemplateSetup._named` и `WtShiftDesk._named` —
  // тот же приём и та же цена, что у соседей выше.
  'lib/web/wt_receipt_template_setup.dart',
  'lib/web/wt_shift_desk.dart',
  // Диагностика оборудования с планшета (план 2026-09-19):
  // `WtHardwareDiagnostics._named` — тот же приём и та же цена.
  'lib/web/wt_hardware_diagnostics.dart',
  // Выпуск сертификата с планшета (дыра 1 ревизии 2026-09-19):
  // `WtCertificateIssuer` — тот же приём и та же цена. Коды, которые касса
  // отдаёт по `pay.certificateIssue` и `pay.certificate`, объявлены
  // реестром `gift_certificate.dart` и переведены все до одного; сюда они
  // приезжают кадром, и привязать их к объявлению сторож не может по
  // построению.
  'lib/web/wt_certificate_issuer.dart',
  // Повтор печати слипа с планшета (решение заказчика 2026-09-18):
  // `WtCertificateSlipReprinter` — тот же приём и та же цена. Коды, которыми
  // касса отвечает на `pay.certificateSlip`, — те же самые коды
  // `gift_certificate.dart`, что и у `pay.certificate`: внутри стоит один и
  // тот же `lookup`, и второго слова на ту же беду не заводится.
  'lib/web/wt_certificate_slip_reprinter.dart',
];

/// Оба контракта: всё, что здесь объявлено строковой константой, —
/// код отказа по определению, брошен он сегодня или ещё нет.
///
/// Это единственное место, где объявление считается кодом **само по себе**.
/// Везде остальном код обязан быть брошен: иначе всякая строковая
/// константа узла (имя колонки, ключ настройки) требовала бы перевода.
const saleRefusalRegistries = <String>[
  'lib/domain/sale/cart_service.dart',
  'lib/domain/sale/sale_checkout_service.dart',
  // Задача 21: девять кодов сертификата. Реестром, а не «что брошено»,
  // по той же причине, что у двух контрактов выше — и по одной своей:
  // шесть из девяти бросает `LocalCertificateIssuer`, который живёт в
  // `lib/data/payment`, а тот корнем не стал (разбор — у
  // [saleRefusalCodeRoots]). Считать кодом только брошенное значило бы
  // оставить шесть кодов, доходящих до кассира через `pay.complete`, без
  // перевода — ровно тот дефект, ради которого сторож заведён.
  'lib/domain/payment/gift_certificate.dart',
  // Вход в оплату по QR: восемь кодов провайдера. Реестром, потому что
  // бросает их не касса, а `HttpQrPaymentProvider` в `lib/data/payment`
  // (не корень), и до кассира они доезжают полем `QrTender.refusalCode`,
  // а не брошенным отказом, — «что брошено» их бы не нашло.
  'lib/domain/payment/qr_payment_provider.dart',
  // Приём аванса покупателя — требование заказчика 2026-09-18. Реестром, и
  // по той же причине, что у сертификата выше: три кода из четырёх бросает
  // `CustomerPaymentUseCaseImpl` из `lib/data/usecases/payment`, а этот
  // каталог корнем не стал — там же лежит проброс кода, известного только в
  // исполнении (`WireRefusal(result.refusalCode, …)`), и включение корня
  // покрасило бы сторожа формой, а не дефектом. Считать кодом только
  // брошенное значило бы оставить три кода, доходящих до кассира с
  // браузерного терминала, без перевода.
  'lib/domain/payment/prepayment_intake.dart',
  // Шаблон чека с браузерного терминала — решение заказчика 2026-09-18.
  // Реестром, а не корнем: оба кода бросает `TillOperations`
  // (`lib/backend/`), который корнем узла продажи не является и становиться
  // им не должен — там же живут коды входа, устройств и сети, к продаже
  // отношения не имеющие. Считать кодом только брошенное значило бы
  // оставить оба без перевода ровно там, где владелец их и увидит.
  'lib/domain/receipt/receipt_template_setup.dart',
  // Смена с браузерного терминала — того же дня. Реестром по той же
  // причине: три кода бросает `LocalShiftDesk` из `lib/data/shift`, а этот
  // каталог корнем не стал.
  'lib/domain/shift/shift_desk.dart',
];

/// `const x = '…';` и `static const x = '…';` — обе формы.
///
/// Круг правки 1 снял требование `\w*Code`: имя конвенцией нигде не
/// закреплено, и диверсия с `abstract final class CartCodes { static const
/// frozen = 'cart_frozen'; }` проходила мимо сторожа целиком.
final _constStringPattern = RegExp(
  r"(?:^|\s)(?:static\s+)?const\s+([A-Za-z_$][\w$]*)\s*=\s*'([^']*)'\s*;",
  multiLine: true,
);

/// Первый довод `WireRefusal`: строка, имя (в том числе `Класс.имя`) — или
/// нечто третье, чего сторож разобрать не умеет и обязан назвать вслух.
///
/// **Пустые скобки исключены в день слияния (2026-09-07), и это не
/// послабление.** `WtCartService._worthRepeating` разбирает беду образцом
/// `WireRefusal() => false` — это **образец типа**, а не создание отказа:
/// у `WireRefusal` конструктор `const WireRefusal(this.code, this.message)`
/// с двумя обязательными позиционными доводами, и вызов без доводов не
/// собрался бы вовсе. Сторож же читал текст, а не дерево разбора, и
/// объявлял образец «формой, которая мне не по зубам» — красный цвет без
/// дефекта. Всякая непустая форма (`WireRefusal(x + y, …)`,
/// `WireRefusal(:final code)`) по-прежнему краснеет.
final _refusalArgPattern = RegExp(
  r"WireRefusal\(\s*(?:'([^']*)'|([A-Za-z_$][\w$.]*)\s*,|([^)\s]))",
  dotAll: true,
);

/// Что сторож вычитал из дерева.
///
/// [unresolved] и [unparsed] — не «прочее», а **отдельные виды красноты**:
/// имя, которое не удалось привязать к объявлению, и форма довода, которую
/// выражение не разбирает. Молча пропустить их значило бы вернуть ровно ту
/// слепоту, ради которой сторож переписан: он выглядел бы знающим все коды,
/// не зная части из них.
typedef SaleRefusalScan = ({
  Set<String> codes,
  List<String> unresolved,
  List<String> unparsed,
});

/// Корень — каталог целиком **или** один названный файл: слой провода
/// включён одним файлом, а не всем `lib/backend/`.
Iterable<File> _dartFilesUnder(Iterable<String> roots) sync* {
  for (final root in roots) {
    final asFile = File(root);
    if (asFile.existsSync()) {
      yield asFile;
      continue;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) fail('сторож смотрит в несуществующий корень $root');
    yield* dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
  }
}

String _display(File f) => f.path.replaceAll(r'\', '/');

/// Коды отказа, известные дереву, — собраны чтением, а не памятью.
SaleRefusalScan scanSaleRefusalCodes() {
  final codes = <String>{};
  final unresolved = <String>[];
  final unparsed = <String>[];

  // Объявления собираются со всего узла: имя, названное в одном файле,
  // бросается обычно в другом.
  final declared = <String, Set<String>>{};
  final sources = <File, String>{};
  for (final file in _dartFilesUnder(saleRefusalCodeRoots)) {
    final text = file.readAsStringSync();
    sources[file] = text;
    for (final m in _constStringPattern.allMatches(text)) {
      declared.putIfAbsent(m.group(1)!, () => <String>{}).add(m.group(2)!);
    }
  }

  for (final path in saleRefusalRegistries) {
    final file = File(path);
    if (!file.existsSync()) fail('сторож смотрит в несуществующий файл $path');
    for (final m in _constStringPattern.allMatches(file.readAsStringSync())) {
      codes.add(m.group(2)!);
    }
  }

  for (final entry in sources.entries) {
    for (final m in _refusalArgPattern.allMatches(entry.value)) {
      final line =
          '\n'.allMatches(entry.value.substring(0, m.start)).length + 1;
      final where = '${_display(entry.key)}:$line';
      final literal = m.group(1);
      final name = m.group(2);
      if (literal != null) {
        codes.add(literal);
      } else if (name != null) {
        // `Класс.имя` привязывается по последнему звену: разбирать области
        // видимости Dart выражением нельзя, а одноимённых кодовых констант
        // в узле не бывает — если заведутся, красноту даст сама привязка
        // (значение придёт не одно).
        final values = declared[name.split('.').last];
        if (values == null || values.isEmpty) {
          if (!saleRefusalPassThroughFiles.contains(_display(entry.key))) {
            unresolved.add('$where: WireRefusal($name, …)');
          }
        } else {
          codes.addAll(values);
        }
      } else {
        unparsed.add('$where: WireRefusal(${m.group(3)}…');
      }
    }
  }

  return (codes: codes, unresolved: unresolved, unparsed: unparsed);
}

/// Короткая форма для проверок, которым нужны только коды.
Set<String> discoverSaleRefusalCodes() => scanSaleRefusalCodes().codes;

/// Ключи, которые контроллеры продажи придумывают **сами**, минуя карту
/// кодов отказа.
///
/// # Круг правки 2: та же дыра, другой вход
///
/// `saleRefusalErrorKeys` сторожит коды, пришедшие от кассы. Но
/// `SaleController` кладёт в состояние и собственные ключи —
/// `order_not_found`, `shift_over_age`, `search_failed` и другие, —
/// и первая редакция сторожа на них не смотрела вовсе. Дефект нашёлся сразу:
/// `shift_over_age` — **блокирующий модальный диалог на экране продажи**, и
/// его заголовок с текстом лежали в казахском, киргизском и узбекском
/// словарях дословно по-русски. Ключ в ARB был, поэтому в 38 недостающих
/// генератор его не считал, и не смотрел на него никто.
final _ownKeyPattern = RegExp(r"'(error\.[a-z_]+)");

Set<String> discoverSaleOwnErrorKeys() {
  final keys = <String>{};
  for (final file in _dartFilesUnder(const [
    'lib/presentation/controllers/sale',
  ])) {
    for (final m in _ownKeyPattern.allMatches(file.readAsStringSync())) {
      keys.add(m.group(1)!);
    }
  }
  return keys;
}

/// Локали дерева. Русская — шаблон, с ней сравниваются остальные.
const _templateLocale = 'ru';
const _otherLocales = <String>['kk', 'ky', 'uz', 'en'];

Future<BuildContext> _pumpLocale(WidgetTester tester, String code) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ctx;
}

void main() {
  test('сторож действительно что-то нашёл — иначе он смотрит не туда', () {
    final codes = discoverSaleRefusalCodes();
    // Якоря: если выражение сломается, набор кодов станет пустым или
    // куцым, и все прочие проверки позеленеют, ничего не проверив. В
    // якорях есть код из каждой половины — объявленный константой и
    // брошенный литералом, — иначе слепота на одну из них не видна.
    expect(
      codes,
      containsAll(<String>[
        'cart_stale',
        'invalid_amount',
        'line_not_found',
        'receipt_empty',
        'shift_not_open',
      ]),
      reason:
          'выражения поиска кодов перестали находить известные коды — '
          'сторож ослеп, найдено: ${(codes.toList()..sort()).join(', ')}',
    );
    // Порог, а не точное число: коды заводят и снимают, и сторож,
    // считающий их поимённо, краснел бы на всякой законной уборке. Смысл
    // порога — «выражения нашли дерево, а не пустоту»; на 2026-09-06
    // найдено 17.
    expect(codes.length, greaterThanOrEqualTo(12));
  });

  test('каждый довод WireRefusal сторож сумел прочитать', () {
    final scan = scanSaleRefusalCodes();
    expect(
      scan.unresolved,
      isEmpty,
      reason:
          'Имя, названное доводом отказа, не привязалось ни к одному '
          'объявлению `const … = \'…\';` в узле продажи. Сторож не знает '
          'значения этого кода, а значит не может потребовать перевода — '
          'это дыра, а не мелочь. Объявите код константой в узле или '
          'бросьте его строкой:\n${scan.unresolved.join('\n')}',
    );
    expect(
      scan.unparsed,
      isEmpty,
      reason:
          'Форма первого довода `WireRefusal` сторожу не по зубам — код '
          'собирается выражением. Пока она такая, сторож про этот отказ '
          'ничего не знает:\n${scan.unparsed.join('\n')}',
    );
  });

  test('у каждого кода отказа продажи есть строка в карте ключей', () {
    final codes = discoverSaleRefusalCodes();
    final missing =
        codes
            .where(
              (c) =>
                  !saleRefusalErrorKeys.containsKey(c) &&
                  !saleWireCodesNotForCashier.containsKey(c),
            )
            .toList()
          ..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'Коды без строки в `saleRefusalErrorKeys` уезжают на экран как '
          '`error.save_failed:<русский текст>` — кассир с казахским или '
          'узбекским интерфейсом читает русскую фразу, пришитую к коду '
          'ошибки. Заведите строку в '
          '`lib/presentation/controllers/sale/sale_refusal_keys.dart` и '
          'перевод во всех пяти `assets/i18n/intl_*.arb`. Без перевода: '
          '${missing.join(', ')}',
    );
  });

  test('белый список провода не гниёт и не спорит с картой', () {
    final codes = discoverSaleRefusalCodes();

    final gone =
        saleWireCodesNotForCashier.keys
            .where((c) => !codes.contains(c))
            .toList()
          ..sort();
    final doubleBooked =
        saleWireCodesNotForCashier.keys
            .where(saleRefusalErrorKeys.containsKey)
            .toList()
          ..sort();
    final mute =
        saleWireCodesNotForCashier.entries
            .where((e) => e.value.trim().isEmpty)
            .map((e) => e.key)
            .toList()
          ..sort();

    // Три случая проверяются одним `expect` намеренно: два подряд прячут
    // второй за первым, и разбор видит половину картины (замечание круга
    // правки 3).
    expect(
      {
        'исчезли из дерева': gone,
        'и в карте, и в списке': doubleBooked,
        'без довода': mute,
      },
      {
        'исчезли из дерева': <String>[],
        'и в карте, и в списке': <String>[],
        'без довода': <String>[],
      },
      reason:
          'Белый список — обещание «этот код кассиру не адресован», и оно '
          'обязано оставаться правдой: исчезнувший код превращает список в '
          'мусор, код и в списке и в карте оставляет неясным, что с ним '
          'делают, а пустой довод — это «руки не дошли», написанное как '
          'решение.',
    );
  });

  test('в карте нет строк под коды, которых в дереве больше нет', () {
    // С 2026-09-13 карта переводит не только коды узла продажи, а всё, что
    // провод и касса могут отдать: гниль мерится по объединению обеих
    // разведок, иначе строки под `no_session` или `refund_busy` читались бы
    // лишними.
    final codes = {...discoverSaleRefusalCodes(), ...scanRefusalCodes().codes};
    final stale =
        saleRefusalErrorKeys.keys.where((c) => !codes.contains(c)).toList()
          ..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'карта переводит коды, которых дерево уже не бросает: '
          '${stale.join(', ')}',
    );
  });

  testWidgets('каждый ключ карты разбирается словарём во всех пяти локалях', (
    tester,
  ) async {
    final keys = <String>{
      for (final e in saleRefusalErrorKeys.entries)
        saleRefusalErrorKeyOf(WireRefusal(e.key, 'Молоко')),
    };

    final broken = <String>[];
    for (final locale in <String>[_templateLocale, ..._otherLocales]) {
      final ctx = await _pumpLocale(tester, locale);
      for (final key in keys) {
        final shown = ErrorLocalizer.localize(ctx, key);
        if (shown.isEmpty || shown.startsWith('error.')) {
          broken.add('$locale: "$key" → "$shown"');
        }
      }
    }
    expect(
      broken,
      isEmpty,
      reason:
          'ключ не разобрался `ErrorLocalizer._resolve` — на экран уедет '
          'сам ключ вместо фразы:\n${broken.join('\n')}',
    );
  });

  testWidgets('код, объявленный «с текстом», действительно доносит текст', (
    tester,
  ) async {
    // `withMessage: true` — обещание, что текст отказа доедет до человека
    // внутри фразы: имя товара в «нет на остатке», имя товара без марки.
    // Обещание можно дать и не сдержать — привязать код к ключу, чей
    // перевод довода не принимает, — и кассир потеряет ровно то слово,
    // ради которого отказ вообще назван.
    const sample = 'Кымыз Дүкен №2';
    final withMessage = saleRefusalErrorKeys.entries
        .where((e) => e.value.withMessage)
        .toList();
    expect(
      withMessage,
      isNotEmpty,
      reason:
          'проверка смотрит в пустоту — «с текстом» не объявлен ни один код',
    );

    final lost = <String>[];
    for (final locale in <String>[_templateLocale, ..._otherLocales]) {
      final ctx = await _pumpLocale(tester, locale);
      for (final e in withMessage) {
        final shown = ErrorLocalizer.localize(
          ctx,
          saleRefusalErrorKeyOf(WireRefusal(e.key, sample)),
        );
        if (!shown.contains(sample)) {
          lost.add('$locale: код "${e.key}" → "$shown"');
        }
      }
    }
    expect(
      lost,
      isEmpty,
      reason:
          'код объявлен «с текстом», но перевод довода не принимает — '
          'кассир не узнает, о каком товаре речь:\n${lost.join('\n')}',
    );
  });

  testWidgets('фраза на экране взята из ARB, а не из устаревшей генерации', (
    tester,
  ) async {
    // # Круг правки 1, П3: сторож мерил не тот словарь
    //
    // `ErrorLocalizer` читает `lib/l10n/app_localizations_*.dart` — **код,
    // порождённый** из `assets/i18n/intl_*.arb`, и лежащий в дереве
    // отдельно. `flutter test` его не перегенерирует. Значит снятая строка
    // ARB оставляла сторожа зелёным до тех пор, пока кто-нибудь не позовёт
    // `flutter gen-l10n` — а разошедшуюся пару не сторожил никто.
    //
    // Проверка сверяет то, что увидит кассир, с тем, что написано в ARB:
    // расхождение любой природы (снятая строка, правка мимо генерации,
    // забытый `gen-l10n`) краснеет здесь и сразу, без пересборки.
    const sample = 'Кымыз Дүкен №2';
    final placeholder = RegExp(r'\{[A-Za-z_][\w]*\}');

    final drift = <String>[];
    for (final locale in <String>[_templateLocale, ..._otherLocales]) {
      final arb =
          jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final renderable = <String>{};
      for (final value in arb.values) {
        if (value is! String) continue;
        renderable.add(value);
        renderable.add(value.replaceAll(placeholder, sample));
      }

      final ctx = await _pumpLocale(tester, locale);
      for (final e in saleRefusalErrorKeys.entries) {
        final shown = ErrorLocalizer.localize(
          ctx,
          saleRefusalErrorKeyOf(WireRefusal(e.key, sample)),
        );
        if (!renderable.contains(shown)) {
          drift.add(
            '$locale: код "${e.key}" → "$shown" — такой строки в '
            'intl_$locale.arb нет',
          );
        }
      }
      // Круг правки 3: докстринг обещал сверку и для собственных ключей
      // контроллера, а цикл был один — по карте. То есть дыра круга 1
      // оставалась открытой ровно для тех ключей, которые круг 2 добавил,
      // включая переведённый им же `error.shift_over_age`.
      for (final key in discoverSaleOwnErrorKeys()) {
        final shown = ErrorLocalizer.localize(ctx, '$key:$sample');
        if (!renderable.contains(shown)) {
          drift.add(
            '$locale: ключ "$key" → "$shown" — такой строки в '
            'intl_$locale.arb нет',
          );
        }
      }
    }
    expect(
      drift,
      isEmpty,
      reason:
          'Словарь на экране разошёлся с `assets/i18n/`: либо строку сняли '
          'из ARB и `lib/l10n/` про это ещё не знает, либо правили ARB и не '
          'звали `flutter gen-l10n`.\n${drift.join('\n')}',
    );
  });

  testWidgets('ключи, придуманные самим контроллером, тоже переведены', (
    tester,
  ) async {
    const sample = 'Кымыз Дүкен №2';
    final keys = discoverSaleOwnErrorKeys();
    expect(
      keys,
      containsAll(<String>[
        'error.shift_over_age',
        // Якорем был `error.sale_not_initialized`, и он **исчез из
        // продукта** вместе с `SaleNotifier.completeSale` (задача 9):
        // единственный, кто его клал, был мёртвым вторым путём к
        // деньгам. Замена — `error.order_not_found`, ключ той же
        // породы: контроллер придумывает его сам, мимо карты кодов
        // отказа. Сам якорь нужен по-прежнему — он ловит слепоту
        // выражения разведки, а не наличие конкретного ключа.
        'error.order_not_found',
      ]),
      reason: 'выражение перестало находить собственные ключи контроллера',
    );

    final ru = <String, String>{};
    final broken = <String>[];
    for (final locale in <String>[_templateLocale, ..._otherLocales]) {
      final ctx = await _pumpLocale(tester, locale);
      for (final key in keys) {
        final shown = ErrorLocalizer.localize(ctx, '$key:$sample');
        if (shown.isEmpty || shown.startsWith('error.')) {
          broken.add('$locale: "$key" → "$shown"');
          continue;
        }
        if (locale == _templateLocale) {
          ru[key] = shown;
        } else if (shown == ru[key]) {
          broken.add('$locale: "$key" → русское "$shown"');
        }
      }
    }
    expect(
      broken,
      isEmpty,
      reason:
          'Ключ, который контроллер продажи придумывает сам, не переведён '
          'или отдаёт русскую строку в национальной локали. Это тот же '
          'класс, что и забытый код отказа, только вход другой:\n'
          '${broken.join('\n')}',
    );
  });

  testWidgets('перевод у каждого кода свой в каждой локали, а не русский', (
    tester,
  ) async {
    final keys = <String, String>{
      for (final e in saleRefusalErrorKeys.entries)
        e.key: saleRefusalErrorKeyOf(WireRefusal(e.key, 'Молоко')),
    };

    final ruCtx = await _pumpLocale(tester, _templateLocale);
    final ru = <String, String>{
      for (final e in keys.entries)
        e.key: ErrorLocalizer.localize(ruCtx, e.value),
    };

    final untranslated = <String>[];
    for (final locale in _otherLocales) {
      final ctx = await _pumpLocale(tester, locale);
      for (final e in keys.entries) {
        final shown = ErrorLocalizer.localize(ctx, e.value);
        if (shown == ru[e.key]) {
          untranslated.add('$locale: код "${e.key}" → русское "$shown"');
        }
      }
    }
    expect(
      untranslated,
      isEmpty,
      reason:
          'Генератор Flutter подставляет строку из `intl_ru.arb` вместо '
          'недостающей, и экран выглядит переведённым, оставаясь русским. '
          'Заведите строку в соответствующем `assets/i18n/intl_*.arb`:\n'
          '${untranslated.join('\n')}',
    );
  });
}
