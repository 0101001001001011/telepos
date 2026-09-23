/// Сторож словаря причин фискального отказа.
///
/// # Что он ловит
///
/// * **Вид причины без ключа** в любом из пяти `assets/i18n/intl_*.arb`.
///   Виды читаются из перечисления `FiscalFailureKind`, а не списком здесь:
///   список, переписанный в тест руками, зеленеет навсегда в день написания.
///   Генератор Flutter подставляет недостающую строку из шаблона
///   (`intl_ru.arb`) молча — без этой проверки кассир с казахским
///   интерфейсом снова читал бы русский.
/// * **Русский литерал, записанный в `lastError`** где угодно под `lib/`.
///   Колонка — строка; компилятор не мешает положить туда фразу мимо кода.
/// * **Код отказа, свалившийся в «неизвестную причину»** при переводе в вид.
///
/// # Чего он не ловит
///
/// Фразу, **переменной** уехавшую в `lastError` или `SaleFiscalization
/// .message` (`message: message`). Это проверяют пробы по цепочке —
/// `cyrillic_receipt_fiscalized_test.dart`, `unfiscalized_row_test.dart`:
/// они читают записанное и требуют, чтобы оно разбиралось кодом.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/fiscal_reason_text.dart';

const _locales = ['ru', 'en', 'kk', 'ky', 'uz'];

const _frameKeys = [
  'fiscalReasonWithCode',
  'fiscalReasonLegacy',
  'fiscalReasonNotRecorded',
];

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('assets/i18n/intl_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('у каждого вида причины есть ключ во всех пяти словарях', () {
    final missing = <String>[];
    for (final locale in _locales) {
      final arb = _arb(locale);
      final keys = [
        for (final kind in FiscalFailureKind.values) fiscalReasonArbKey(kind),
        ..._frameKeys,
      ];
      for (final key in keys) {
        final value = arb[key];
        if (value is! String || value.trim().isEmpty) {
          missing.add('intl_$locale.arb: $key');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'нет перевода причины — генератор подставит русский из шаблона '
          'молча:\n${missing.join('\n')}',
    );
  });

  test('фраза строится словарём в каждой локали и кода наружу не несёт', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    for (final locale in _locales) {
      final l10n = lookupAppLocalizations(Locale(locale));
      for (final kind in FiscalFailureKind.values) {
        final stored = FiscalFailureReason(kind, rawCode: 9).encode();
        final shown = fiscalReasonText(l10n, stored);
        expect(shown.trim(), isNotEmpty, reason: '$locale/$kind');
        expect(shown, isNot(contains('fiscal(')), reason: '$locale/$kind');
        expect(
          shown,
          contains('9'),
          reason: '$locale/$kind: код оператора потерян',
        );
        if (locale == 'en' || locale == 'uz') {
          // Латиница: фраза, совпавшая с русской, — подставленный шаблон.
          expect(
            fiscalReasonPhrase(l10n, kind),
            isNot(fiscalReasonPhrase(ru, kind)),
            reason: '$locale/$kind переведено русским текстом',
          );
        }
      }
    }
  });

  test('ни один код отказа не переводится в «неизвестную причину» сам', () {
    for (final code in FiscalErrorCode.values) {
      if (code == FiscalErrorCode.ok || code == FiscalErrorCode.unknown) {
        continue;
      }
      expect(
        FiscalFailureReason.of(code).kind,
        isNot(FiscalFailureKind.unknown),
        reason: '$code свалился в unknown — у кассира пропадёт причина',
      );
    }
  });

  test('код переживает строку туда и обратно; старая фраза — не код', () {
    for (final kind in FiscalFailureKind.values) {
      for (final raw in [null, 0, 503]) {
        final reason = FiscalFailureReason(kind, rawCode: raw);
        expect(FiscalFailureReason.parse(reason.encode()), reason);
      }
    }
    expect(FiscalFailureReason.parse('Превышено автономное окно 72ч'), isNull);
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(
      fiscalReasonText(ru, 'Касса заблокирована'),
      contains('Касса заблокирована'),
      reason: 'старая строка очереди не теряет причину',
    );
    expect(fiscalReasonText(ru, null), ru.fiscalReasonNotRecorded);
    expect(
      FiscalFailureReason.fromResult(
        FiscalResult.failure(
          'x',
          code: FiscalErrorCode.network,
          rawErrorCode: -1,
        ),
      ).rawCode,
      isNull,
      reason: 'отрицательный код транспорта человеку ничего не говорит',
    );
  });

  test('в причину отказа очереди и продажи не пишется русский литерал', () {
    // `lastError = 'Фраза…'`, `..lastError = 'Фраза…'`, `lastError: 'Фраза…'`
    // — в том числе с переносом строки после знака.
    //
    // Корни — те, что пишут **причину отказа строки очереди и исхода
    // продажи**. `lastError` есть и у других: `WebKassaStatus.lastError`
    // (`lib/data/usecases/fiscal/webkassa_service_impl.dart`, строка
    // состояния связи) и местная переменная `wifi_printer.dart` — первая
    // тоже русская и названа открытой в отчёте дорожки D, вторая — не текст
    // для человека. Первая редакция сторожа ходила по всему `lib/` и
    // обещала больше, чем проверяет дорожка; измерено: четыре попадания
    // мимо очереди.
    const roots = [
      'lib/data/fiscal',
      'lib/data/sale',
      'lib/presentation/screens/fiscal',
    ];
    final literal = RegExp(
      "lastError\\s*[:=]\\s*(?:\\n\\s*)?'[^'\\n]*[А-Яа-яЁё]",
    );
    final hits = <String>[];
    var scanned = 0;
    for (final root in roots) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        scanned++;
        final source = entity.readAsStringSync();
        for (final m in literal.allMatches(source)) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          hits.add('${entity.path}:$line');
        }
      }
    }
    expect(scanned, greaterThan(10), reason: 'обход ничего не прочёл');
    expect(
      hits,
      isEmpty,
      reason:
          'причина отказа записана фразой мимо словаря — пишите '
          'FiscalFailureReason(...).encode():\n${hits.join('\n')}',
    );
  });
}
