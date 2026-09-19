/// Разведка кодов отказа по всему `lib/` — что провод и касса могут
/// отдать терминалу.
///
/// # Чем отличается от разведки сторожа продажи
///
/// `sale_refusal_codes_localized_test.dart` обходит **узел продажи**, и у
/// него был белый список «кассиру не адресовано». Живая приёмка 2026-09-13
/// показала цену такой границы: `no_session` на поиске доехал до кассира
/// «неизвестной причиной», хотя адресован ему больше любого другого кода —
/// связь потеряна, и делать что-то надо именно человеку. Путь кода до экрана
/// сторож не видит; «кассиру не адресован» оказался догадкой про путь.
///
/// Здесь граница другая и проверяемая: **всякий** код, который создаётся в
/// `lib/` отказом провода (`WireRefusal`, `WtProtocolError`, `ErrorFrame`,
/// `WireDenied`), обязан иметь фразу словаря. Путь не угадывается — любой
/// код может доехать до `safeErrorText`, и там он либо фраза, либо
/// «неизвестная причина (код …)».
///
/// # Три вида красноты, и каждый виден
///
/// - [RefusalCodeScan.unresolved] — имя, которое не привязалось ни к одному
///   `const … = '…';` в `lib/`;
/// - [RefusalCodeScan.unparsed] — форма первого довода, которую выражение не
///   разбирает;
/// - [RefusalCodeScan.unusedPassThrough] — исключение из списка проброса,
///   которое больше ничего не пропускает (гниль).
///
/// Код, приходящий в исполнении (проброс кода с провода дальше), не
/// разбирается, а **называется поимённо** в [refusalPassThrough] — файл и
/// выражение, с доводом, откуда настоящий код берётся.
library;

import 'dart:io';

/// Типы, чей первый довод — код провода.
const refusalCodeCarriers = <String>[
  'WireRefusal',
  'WtProtocolError',
  'ErrorFrame',
  'WireDenied',
];

/// Файлы, где **объявление** строковой константы уже есть код — брошен он
/// сегодня или ещё нет. Везде остальном код обязан быть создан отказом.
const refusalCodeRegistries = <String>[
  'lib/domain/sale/cart_service.dart',
  'lib/domain/sale/sale_checkout_service.dart',
  'lib/domain/payment/gift_certificate.dart',
  // Коды провайдера QR доезжают полем `QrTender.refusalCode`, а не
  // отказом, — «что создано отказом» их не нашло бы.
  'lib/domain/payment/qr_payment_provider.dart',
  // `PaymentKindRules.validate` возвращает код, а бросает его
  // `PaymentKindCatalogImpl.upsert` переменной — см. [refusalPassThrough].
  'lib/domain/payment/payment_kind_catalog.dart',
];

/// Места, где первый довод — **не origin** кода, а его проброс.
///
/// Ключ — `файл|выражение`; значение — откуда настоящий код, и почему он уже
/// учтён в другом месте разведки.
const refusalPassThrough = <String, String>{
  'lib/data/transport/till_wire.dart|refusal.code':
      'отказ обработчика (`WireRefusal`) едет кадром — код учтён там, где '
      'отказ создан',
  'lib/data/transport/till_wire.dart|verdict.code':
      'вердикт сторожа (`WireDenied`) едет кадром — коды учтены '
      'константами `WireDenied`',
  'lib/data/transport/till_wire.dart|error.code':
      'отказ подписки/работы едет кадром — код учтён там, где создан',
  'lib/web/wt_dispatcher.dart|code':
      '`_errorFor`: код пришёл кадром кассы — учтён там, где касса его создала',
  'lib/web/wt_sale_edit_terms.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Задача 45: быстрые товары и правила сканера — тот же проброс.
  'lib/web/wt_quick_product_catalog.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  'lib/web/wt_scanner_rules.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Пункт 11 ревизии 2026-09-19: предупреждение о просроченной партии —
  // тот же проброс. Единственный читатель отказа гасит его журналом:
  // предупреждение не запрет, и кассиру этот код не показывается.
  'lib/web/wt_expiry_warning.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Пункт 12 ревизии 2026-09-19: подписка на изменения остатков — тот же
  // проброс, только у потока, а не у вопроса.
  'lib/web/wt_stock_changes.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Приём аванса: `WtPrepaymentIntakeService.acceptPrepayment` — тот же
  // проброс, чтобы экран знал один тип отказа на обе реализации контракта.
  'lib/web/wt_payment_service.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Настройка оплаты по QR из браузера (2026-09-18): `WtQrProviderSetup._named`
  // — тот же проброс, чтобы у контроллера был один тип отказа на обе
  // реализации порта.
  'lib/web/wt_qr_provider_setup.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Шаблон чека и смена с браузерного терминала (решение заказчика
  // 2026-09-18): `WtReceiptTemplateSetup._named` и `WtShiftDesk._named` — тот
  // же проброс и тот же довод, что у настройки QR строкой выше: экрану
  // положен один тип отказа на обе реализации порта.
  'lib/web/wt_receipt_template_setup.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  'lib/web/wt_shift_desk.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Диагностика оборудования с планшета (план 2026-09-19):
  // `WtHardwareDiagnostics._named` — тот же проброс и тот же довод, что у
  // шаблона чека и смены выше: вкладке положен один тип отказа на обе
  // реализации порта.
  'lib/web/wt_hardware_diagnostics.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Выпуск сертификата с планшета (дыра 1 ревизии 2026-09-19):
  // `WtCertificateIssuer` — тот же проброс и тот же довод, что у соседей.
  // Экрану выпуска положен один тип отказа на обе реализации порта: на кассе
  // под ним `LocalCertificateIssuer`, бросающий `WireRefusal` с кодами
  // реестра `gift_certificate.dart`, и они же приезжают сюда кадром.
  'lib/web/wt_certificate_issuer.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  // Повтор печати слипа с планшета (решение заказчика 2026-09-18):
  // `WtCertificateSlipReprinter` — тот же проброс и тот же довод. Коды те
  // же самые, что у выпуска: внутри обеих операций стоит один и тот же
  // `lookup`, и второго слова на ту же беду не заводится.
  'lib/web/wt_certificate_slip_reprinter.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  'lib/web/wt_cart_service.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  'lib/web/wt_refund_service.dart|error.code':
      '`_translate`: `WtProtocolError` кассы становится `WireRefusal` с тем '
      'же кодом',
  'lib/web/wt_terminal_repository.dart|error.code':
      '`WtProtocolError` кассы становится `WireRefusal` с тем же кодом',
  'lib/domain/wire/wire_frame.dart|this.code': 'конструктор кадра',
  'lib/domain/wire/wire_frame.dart|decoded':
      'разбор кадра с провода: код тот, что касса положила в кадр; запасное '
      '`failed` недостижимо — `ErrorFrame.encode` пишет код всегда',
  'lib/domain/wire/wire_guard.dart|this.code': 'конструктор вердикта',
  'lib/domain/wire/wire_refusal.dart|this.code': 'конструктор отказа',
  'lib/web/wt_channel.dart|this.code': 'конструктор отказа провода',
  'lib/data/payment/payment_kind_catalog_impl.dart|refusal':
      '`PaymentKindRules.validate` — коды объявлены реестром '
      '`payment_kind_catalog.dart`',
  'lib/data/usecases/payment/customer_payment_use_case_impl.dart|'
          'result.refusalCode':
      'приём аванса по проводу: код назвал сам юзкейс в '
      '`CustomerPaymentResult.refusalCode` — все четыре объявлены '
      '`prepayment_intake.dart` и учтены его реестром',
  'lib/data/payment/local_certificate_issuer.dart|found.status':
      'выбор `certificateExpiredCode`/`certificateExhaustedCode` условием — '
      'оба объявлены реестром `gift_certificate.dart`',
};

typedef RefusalCodeScan = ({
  Set<String> codes,
  Map<String, Set<String>> origins,
  List<String> unresolved,
  List<String> unparsed,
  List<String> unusedPassThrough,
  int filesRead,
  int sites,
});

final _constString = RegExp(
  r"(?:^|\s)(?:static\s+)?const\s+([A-Za-z_$][\w$]*)\s*=\s*'([^']*)'\s*;",
  multiLine: true,
);

final _carrierArg = RegExp(
  '\\b(${refusalCodeCarriers.join('|')})\\(\\s*'
  r"(?:'([^']*)'|([A-Za-z_$][\w$.]*)(?=\s*[,)\s=])|(\S))",
);

String _posix(String path) => path.replaceAll(r'\', '/');

RefusalCodeScan scanRefusalCodes() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !_posix(f.path).startsWith('lib/l10n/'))
      .toList();

  final sources = <String, String>{
    for (final f in files) _posix(f.path): f.readAsStringSync(),
  };

  final declared = <String, Set<String>>{};
  for (final text in sources.values) {
    for (final m in _constString.allMatches(text)) {
      declared.putIfAbsent(m.group(1)!, () => {}).add(m.group(2)!);
    }
  }

  final codes = <String>{};
  final origins = <String, Set<String>>{};
  void found(String code, String where) {
    codes.add(code);
    origins.putIfAbsent(code, () => {}).add(where);
  }

  for (final path in refusalCodeRegistries) {
    final text = sources[path];
    if (text == null) throw StateError('реестра $path нет в дереве');
    for (final m in _constString.allMatches(text)) {
      found(m.group(2)!, path);
    }
  }

  final unresolved = <String>[];
  final unparsed = <String>[];
  final usedPassThrough = <String>{};
  var sites = 0;

  for (final MapEntry(key: path, value: text) in sources.entries) {
    for (final m in _carrierArg.allMatches(text)) {
      final lineStart = text.lastIndexOf('\n', m.start) + 1;
      final before = text.substring(lineStart, m.start).trimLeft();
      // Комментарий и строковый литерал — не создание отказа.
      if (before.startsWith('//')) continue;
      if ("'".allMatches(before).length.isOdd) continue;
      final other = m.group(4);
      // `WireRefusal(:final code)` и `WireRefusal() => false` — образцы
      // типа, а не создание: конструкторы отказов требуют двух доводов.
      if (other == ':' || other == ')') continue;

      final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
      final where = '$path:$line';
      final literal = m.group(2);
      final name = m.group(3);
      sites++;
      if (literal != null) {
        found(literal, where);
        continue;
      }
      final expression =
          name ?? text.substring(m.start + m.group(0)!.length - 1).split(
            RegExp(r'[\s(\[=!?]'),
          ).first;
      final exemption = '$path|$expression';
      if (refusalPassThrough.containsKey(exemption)) {
        usedPassThrough.add(exemption);
        continue;
      }
      if (name == null) {
        unparsed.add('$where: ${m.group(1)}($expression…');
        continue;
      }
      final values = declared[name.split('.').last];
      if (values == null || values.isEmpty) {
        unresolved.add('$where: ${m.group(1)}($name, …)');
      } else {
        for (final v in values) {
          found(v, where);
        }
      }
    }
  }

  return (
    codes: codes,
    origins: origins,
    unresolved: unresolved,
    unparsed: unparsed,
    unusedPassThrough: refusalPassThrough.keys
        .where((k) => !usedPassThrough.contains(k))
        .toList(),
    filesRead: files.length,
    sites: sites,
  );
}
