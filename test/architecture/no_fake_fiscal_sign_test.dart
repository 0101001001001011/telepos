library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Сторож: **поддельного фискального признака в дереве нет**, и третьего
/// конвейера фискализации тоже.
///
/// # Что именно было подделкой
///
/// `FiscErrorsServiceImpl.skipFiscalization` писал в `WebkassaReceipts`
/// строку с `fiscalNo: 'SKIPPED'`. Это **не пометка «пропущено»**: таблица
/// `WebkassaReceipts` и есть место, где живут фискальные документы, а
/// `_getUnfiscalizedSales` считала чек фискализованным ровно по наличию
/// непустого `fiscalNo`. То есть кнопка «пропустить» превращала чек без
/// документа в чек с документом — для всего остального кода. Соседний
/// `retryFiscalization` был не лучше: он искал продажу по `saleId`, получая
/// на самом деле `receiptNo`, и слал оператору `Decimal.zero` во всех трёх
/// денежных полях.
///
/// # Почему сторож, а не «мы же удалили»
///
/// Удалённое возвращается. Дешевле всего оно возвращается именно так:
/// кому-то снова понадобится «убрать чек из списка», и `'SKIPPED'` — самая
/// короткая дорога. Сторож краснеет в тот же день. Списание существует и
/// теперь (экран нефискализованных чеков), но оно **не трогает таблицу
/// документов**: оно кладёт имя, причину и время в саму строку очереди.
///
/// # Считаем прочитанное
///
/// Сторож, ничего не нашедший, зелен по недосмотру. Поэтому число
/// просмотренных файлов утверждается отдельно: обход, который сломался и
/// не прочитал ничего, покраснеет здесь, а не притворится чистым.
void main() {
  late List<File> sources;

  setUpAll(() {
    sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  });

  test('обход дерева читает то, что обещает', () {
    expect(
      sources.length,
      greaterThan(1000),
      reason:
          'в lib/ больше тысячи файлов .dart; меньше — значит обход сломался, '
          'и всё, что ниже, зелено по недосмотру, а не по факту',
    );
  });

  test('ни один файл не пишет поддельный фискальный признак', () {
    final offenders = <String>[];
    for (final file in sources) {
      final text = file.readAsStringSync();
      if (text.contains("'SKIPPED'") || text.contains('"SKIPPED"')) {
        offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'fiscalNo: SKIPPED — это подделка фискального документа, а не '
          'пометка. Чек без документа разбирается на экране нефискализованных '
          'чеков: повтор сохранённого документа или списание с именем и '
          'причиной.',
    );
  });

  test('третьего конвейера фискализации в дереве нет', () {
    final offenders = <String>[];
    for (final file in sources) {
      final text = file.readAsStringSync();
      for (final dead in const [
        'FiscErrorsService',
        'FiscErrorsSchedule',
        'FiscalErrorsDialog',
        'skipFiscalization',
      ]) {
        if (text.contains(dead)) {
          offenders.add('${file.path}: $dead');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'служба опрашивалась раз в минуту, её поток имел ноль подписчиков, '
          'её диалог — ноль вызывающих, а её повтор слал нули. Второй '
          'конвейер физически не мог увидеть отказ первого: он искал чеки в '
          'WebkassaReceipts, а отказ ложится в FiscalQueueEntries.',
    );
  });
}
