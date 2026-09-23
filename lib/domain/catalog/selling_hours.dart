/// Часы, в которые категорию продавать нельзя.
///
/// # Зачем это настройка, а не правило страны
///
/// Запрет ночной продажи алкоголя есть не только в Казахстане: он в России,
/// Киргизии, Узбекистане, в большинстве штатов США, в Польше, Турции и
/// далее. Часы везде РАЗНЫЕ, меняются законом и часто различаются внутри
/// одной страны — по городу или по дню недели.
///
/// Зашить их числом значило бы обещать соблюдение закона, которого мы не
/// знаем. Поэтому здесь только механизм: окно задаёт владелец, как и
/// налоговую ставку. Страна даёт валюту и налог умолчанием, а часы продажи
/// — то, что владелец обязан узнать сам и поставить сам.
///
/// # Окно — это ЗАПРЕТ, а не разрешение
///
/// «С 23:00 до 08:00 нельзя» читается прямо. Обратное прочтение («работаем
/// с 08:00 до 23:00») при пустой настройке означало бы «нельзя никогда», и
/// касса, которую не настроили, перестала бы продавать.
///
/// # Полночь внутри окна
///
/// Главный случай и есть ночной: `23:00–08:00` пересекает полночь. Наивное
/// `begin <= now && now < end` здесь молчит всю ночь — то есть ровно тогда,
/// когда запрет и нужен.
library;

/// Минуты от полуночи из записи `ЧЧ:ММ`; `null` — запись непригодна.
///
/// Разбор строгий намеренно. Тихо принять «25:00» значило бы завести окно,
/// которое никогда не наступит, и владелец узнал бы об этом не из настройки,
/// а из ночной продажи.
int? minutesOfDay(String? hhmm) {
  if (hhmm == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Окно запрета продажи.
class SellingBan {
  const SellingBan({required this.beginMinutes, required this.endMinutes});

  /// Окно из записей `ЧЧ:ММ`; `null` — одна из записей непригодна.
  static SellingBan? parse(String? begin, String? end) {
    final from = minutesOfDay(begin);
    final to = minutesOfDay(end);
    if (from == null || to == null) return null;
    return SellingBan(beginMinutes: from, endMinutes: to);
  }

  final int beginMinutes;
  final int endMinutes;

  /// Окно, у которого начало равно концу, не запрещает НИЧЕГО.
  ///
  /// Прочесть его как «запрещено круглосуточно» было бы вторым смыслом у
  /// одной записи: владелец, стерший часы наполовину, остановил бы продажу
  /// целиком, не поняв, почему.
  bool get isEmpty => beginMinutes == endMinutes;

  /// Пересекает ли окно полночь (`23:00–08:00`).
  bool get crossesMidnight => endMinutes < beginMinutes;

  /// Запрещена ли продажа в этот момент суток.
  ///
  /// Конец окна не включается: запрет «до 08:00» снимается ровно в 08:00, а
  /// не минутой позже. Включи мы его — касса отказывала бы в минуту, когда
  /// закон уже разрешает, и спорить было бы не с чем.
  bool bansAt(DateTime moment) {
    if (isEmpty) return false;
    final now = moment.hour * 60 + moment.minute;
    return crossesMidnight
        ? now >= beginMinutes || now < endMinutes
        : now >= beginMinutes && now < endMinutes;
  }

  String get label => '${_hhmm(beginMinutes)}–${_hhmm(endMinutes)}';

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Запрет для категории: любое из её окон, действующее сейчас.
///
/// Окон у категории может быть НЕСКОЛЬКО — например, ночное и на время
/// школьных часов. Прежняя реализация брала `restrictions.first` и молча
/// теряла остальные.
SellingBan? activeBan(Iterable<SellingBan> windows, DateTime moment) {
  for (final window in windows) {
    if (window.bansAt(moment)) return window;
  }
  return null;
}
