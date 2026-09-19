/// Порт HTTP-зеркала страницы стенда (`test/manual/wt_stand.dart`).
///
/// Вынесено из `_runStand` отдельной чистой функцией ради пробы
/// `test/manual/stand_ports_test.dart`: сам стенд под тестом не поднимается.
///
/// # Дефект (приёмка 2026-09-13)
///
/// Умолчание было «страница + 1». Второй стенд подняли с
/// `TELEPOS_STAND_PORT=8971` и `TELEPOS_STAND_CONTROL=8972` — соседние
/// порты, как их и набирают руками, — и зеркало заняло 8972 раньше двери
/// управления: стенд падал на подъёме «адрес занят», не сказав, кто занял.
library;

/// Порт петлевой HTTP-двери страницы.
///
/// [explicit] — значение `TELEPOS_STAND_HTTP`, если задано: берётся как
/// есть, но **не** равным [control] — такой запуск не поднялся бы, и отказ
/// словами дешевле «адрес занят» из глубины `shelf_io.serve`.
///
/// Без него — «страница + 1», а если там управление, следующий за ним.
int standPlainHttpPort({
  required int page,
  required int control,
  String? explicit,
}) {
  final named = int.tryParse(explicit ?? '');
  if (named != null) {
    if (named == control) {
      throw ArgumentError.value(
        named,
        'TELEPOS_STAND_HTTP',
        'совпадает с TELEPOS_STAND_CONTROL — дверь управления не поднимется',
      );
    }
    return named;
  }
  var port = page + 1;
  while (port == control || port == page) {
    port++;
  }
  return port;
}
