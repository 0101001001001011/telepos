/// Вызываемые отказы эмуляторов железа.
///
/// **Эмулятор, который не умеет отказать, бесполезен.** Ветка отказа
/// недостижима, её сторожа зелены впустую, и продукт уходит в магазин с
/// разбором, который никто ни разу не исполнил. Измерено на этом же дереве:
/// тринадцать веток разбора кодов ошибки не проходились ни одной живой
/// проверкой, пока не появился эмулятор.
///
/// Магических значений в потоке («задание на 999 байт значит откажи») здесь
/// нет и не будет: такое задание однажды приедет из настоящей продажи. Отказ
/// назначается пультом — снаружи разговора.
///
/// # Чего эти отказы НЕ доказывают
///
/// **Что настоящий прибор отказывает так же и по тем же поводам.** Список
/// снят с веток разбора **нашего** `WifiPrinterManager`, а не с документации
/// производителя. Он доказывает, что каждая наша ветка исполняется и
/// приводит к названной причине, — и ничего о том, бывает ли такой отказ у
/// настоящего принтера и как он выглядит на самом деле.
library;

class EmulatorFaults {
  /// Принтер не в сети: бит 3 ответа `DLE EOT 1`.
  bool offline = false;

  /// Бумага кончилась: биты 5 и 6 ответа `DLE EOT 4`.
  bool outOfPaper = false;

  /// Крышка открыта: бит 2 ответа `DLE EOT 4`.
  bool coverOpen = false;

  /// Задание принять и выбросить, ответив отказом.
  int rejectsLeft = 0;

  /// Закрыть сокет без ответа — вход в ветку полуоткрытого сокета.
  int killsLeft = 0;

  /// Не ответить на опрос состояния — вход в тайм-аут `DLE EOT`.
  int silencesLeft = 0;

  /// Ответить байтом, у которого не сходятся биты маркера, — вход в ветку
  /// «мусор вместо байта состояния».
  int garbageLeft = 0;

  /// Задержка перед ответом — вход в тайм-аут, но через **медленный**
  /// прибор, а не через молчащий. Это разные ветки, и обе живые.
  Duration latency = Duration.zero;

  void apply(Map<String, Object?> body) {
    offline = _bool(body['offline'], offline);
    outOfPaper = _bool(body['outOfPaper'], outOfPaper);
    coverOpen = _bool(body['coverOpen'], coverOpen);
    rejectsLeft = _int(body['reject'], rejectsLeft);
    killsLeft = _int(body['kill'], killsLeft);
    silencesLeft = _int(body['silence'], silencesLeft);
    garbageLeft = _int(body['garbage'], garbageLeft);
    final ms = body['latencyMs'];
    if (ms is num) latency = Duration(milliseconds: ms.toInt());
  }

  void reset() {
    offline = false;
    outOfPaper = false;
    coverOpen = false;
    rejectsLeft = 0;
    killsLeft = 0;
    silencesLeft = 0;
    garbageLeft = 0;
    latency = Duration.zero;
  }

  bool takeReject() => _take(() => rejectsLeft, (v) => rejectsLeft = v);
  bool takeKill() => _take(() => killsLeft, (v) => killsLeft = v);
  bool takeSilence() => _take(() => silencesLeft, (v) => silencesLeft = v);
  bool takeGarbage() => _take(() => garbageLeft, (v) => garbageLeft = v);

  bool _take(int Function() get, void Function(int) set) {
    if (get() <= 0) return false;
    set(get() - 1);
    return true;
  }

  /// Состояние словами — для журнала. Довод, а не факт вызова: запись
  /// «ответил 0x1a» не говорит ничего, запись «ответил 0x1a, потому что
  /// бумага кончилась» говорит всё.
  String describeState() {
    final parts = <String>[
      if (offline) 'не в сети',
      if (outOfPaper) 'бумага кончилась',
      if (coverOpen) 'крышка открыта',
    ];
    return parts.isEmpty ? 'исправен' : parts.join(', ');
  }

  Map<String, Object?> describe() => {
    'offline': offline,
    'outOfPaper': outOfPaper,
    'coverOpen': coverOpen,
    'reject': rejectsLeft,
    'kill': killsLeft,
    'silence': silencesLeft,
    'garbage': garbageLeft,
    'latencyMs': latency.inMilliseconds,
  };

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
}
