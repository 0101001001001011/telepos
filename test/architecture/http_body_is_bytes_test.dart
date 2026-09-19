library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Сторож: **тело HTTP не пишется строкой через `write`** — ни в запрос, ни
/// в ответ. Разрешительный список пуст.
///
/// # Почему запрет, а не «пишите осторожно»
///
/// `HttpClientRequest.write` и `HttpResponse.write` кодируют строку
/// кодировкой из `charset` типа содержимого, а без него — **latin1**. Первая
/// русская буква даёт `Invalid argument (string): Contains invalid
/// characters`. Именно так `WebKassaApiClient._defaultSend` не отправил
/// оператору ни одного чека с кириллицей за всю жизнь кассы — а касса
/// докладывала «в очереди», `success: true`.
///
/// Верная форма одна: `add(utf8.encode(body))` с `contentLength` и
/// `charset=utf-8` в типе. `package:http` и `dio` кодируют строку в UTF-8
/// сами (измерено по исходникам `http-1.4.0 Request.body` и `dio-5.8.0
/// DioMixin._transformData`) и этим сторожем не касаются.
///
/// # Как ищется
///
/// Имена переменных, **державших** запрос или ответ `dart:io`, вынимаются из
/// самого файла: объявленные типом (`HttpClientRequest x`, `HttpResponse x`)
/// и полученные из `…Url(` (`final rq = await client.postUrl(uri)`). Плюс
/// всякое `.response.write(`. Переименование переменной сторожа не
/// обходит — это проверено диверсией.
void main() {
  late List<File> sources;

  setUpAll(() {
    sources = [
      ...Directory('lib').listSync(recursive: true),
      if (Directory('packages').existsSync())
        ...Directory('packages')
            .listSync(recursive: true)
            .where((e) => e.path.replaceAll(r'\', '/').contains('/lib/')),
    ].whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  });

  test('обход дерева читает то, что обещает', () {
    expect(
      sources.length,
      greaterThan(1000),
      reason:
          'в lib/ больше тысячи файлов .dart; меньше — обход сломался, и '
          'пустой список нарушителей ниже зелен по недосмотру',
    );
  });

  test('детектор краснеет на известных формах и молчит на чужих write', () {
    const bad = [
      'final request = await _httpClient.postUrl(uri);\nrequest.write(body);',
      'final rq = await client.openUrl("POST", uri);\nrq..write(body);',
      'HttpClientRequest req = await c.putUrl(u);\nreq.writeln(x);',
      'void h(HttpRequest r) { r.response.write("Привет"); }',
      'Future<void> s(HttpResponse out) async { out.writeAll(parts); }',
    ];
    const good = [
      'final request = await _httpClient.postUrl(uri);\nrequest.add(utf8.encode(body));',
      'final buffer = StringBuffer();\nbuffer.write("x");',
      'socket.write(line);',
      'sink.writeln("log");',
    ];
    for (final s in bad) {
      expect(stringBodyWrites(s), isNotEmpty, reason: 'не пойман:\n$s');
    }
    for (final s in good) {
      expect(stringBodyWrites(s), isEmpty, reason: 'ложная тревога:\n$s');
    }
  });

  test('ни один файл не пишет тело HTTP строкой через write', () {
    final offenders = <String>[];
    for (final file in sources) {
      final text = file.readAsStringSync();
      for (final hit in stringBodyWrites(text)) {
        offenders.add('${file.path}: $hit');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'write строкой = latin1 без charset: кириллица бросает до сокета. '
          'Писать add(utf8.encode(body)) с contentLength и '
          'charset=utf-8. Разрешений у этого правила нет.',
    );
  });
}

final _declaredByType = RegExp(
  r'\b(?:HttpClientRequest|HttpResponse)\??\s+(\w+)\b',
);
final _openedFromUrl = RegExp(
  r'(?:final|var)\s+(\w+)\s*=\s*await\s+[\w.!?]+\s*\.\s*'
  r'(?:open|get|post|put|patch|delete|head)Url\(',
);
final _responseAccessor = RegExp(r'\.response\s*\.\.?\s*write(?:ln|All)?\s*\(');

/// Строки, где тело HTTP `dart:io` пишется строкой. Открыто для пробы
/// самого детектора.
List<String> stringBodyWrites(String source) {
  final names = <String>{
    for (final m in _declaredByType.allMatches(source)) m.group(1)!,
    for (final m in _openedFromUrl.allMatches(source)) m.group(1)!,
  };
  final hits = <String>[];
  final lines = source.split('\n');
  for (final raw in lines) {
    final line = raw.trimLeft();
    if (line.startsWith('//')) continue;
    if (_responseAccessor.hasMatch(line)) {
      hits.add(line.trim());
      continue;
    }
    for (final name in names) {
      final write = RegExp(
        '\\b${RegExp.escape(name)}\\s*[!?]?\\s*\\.\\.?\\s*write(?:ln|All)?\\s*\\(',
      );
      if (write.hasMatch(line)) {
        hits.add(line.trim());
        break;
      }
    }
  }
  return hits;
}
