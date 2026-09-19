import 'package:meta/meta.dart';

/// Настройка провайдера QR/СБП на кассе — адрес, имя и **секрет**.
///
/// # Где живёт и кто её видит
///
/// Строка таблицы `qr_provider_configs` в базе **кассы**, и только там.
/// Читает её ровно один класс — `QrPaymentDesk` (`lib/data/payment/`), —
/// который собирает из неё `HttpQrPaymentProvider` и кладёт [apiKey] в
/// заголовок запроса к провайдеру. Больше этот ключ не едет никуда:
///
/// * **ни в один ответ провода.** Браузерный терминал получает от QR
///   только `QrTender` — ключ намерения, состояние, суммы, код для
///   покупателя и секунды терпения. Ни адреса, ни имени провайдера, ни ид
///   намерения на той стороне там нет: терминалу они не нужны ни одной
///   веткой, а всё, что едет в кадре, видит вкладка, которая нам не
///   принадлежит. Сторож — проба `qr_secret_never_reaches_terminal_test`
///   на настоящем графе кассы: она **ищет ключ во всех ответах** и
///   одновременно требует, чтобы провайдер его получил (иначе поиск был бы
///   зелен и у кассы, которая ключа не читает вовсе).
/// * **ни в журнал.** [toString] ключ не печатает.
///
/// # Почему своя таблица, а не колонки `ThisPosEntries`
///
/// Строку `this_pos_entries` читает много кто — мастер настройки,
/// заставка, `setup.state` (едет в браузер **до входа**). Секрет, лежащий
/// в строке, которую разбирают на поля для провода, отделён от утечки
/// одной забытой строкой кодека. Отдельная таблица с одним читателем
/// отделена от неё построением: чтобы ключ уехал, надо сначала завести
/// второго читателя, и сторож исходника его увидит.
@immutable
class QrProviderSettings {
  const QrProviderSettings({
    required this.baseUrl,
    required this.code,
    this.apiKey,
    this.patience = defaultPatience,
  });

  /// Сколько касса ждёт покупателя по умолчанию.
  static const defaultPatience = Duration(minutes: 3);

  /// Адрес провайдера. Для эмулятора — `http://127.0.0.1:8890`: подобие
  /// отличается от настоящего **только адресом** (докстринг
  /// `HttpQrPaymentProvider`).
  final String baseUrl;

  /// Короткое имя провайдера — уезжает в `Payments.providerCode`.
  final String code;

  /// Секрет провайдера. `null` — провайдер ключа не требует.
  final String? apiKey;

  /// Сколько касса согласна ждать покупателя, прежде чем сдаться сама.
  ///
  /// Настройка, а не константа: у провайдера свой срок жизни кода, и
  /// ждать дольше него бессмысленно, а меньше — обидно покупателю.
  final Duration patience;

  /// Настроено достаточно, чтобы звать провайдера.
  bool get isComplete => baseUrl.trim().isNotEmpty && code.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is QrProviderSettings &&
      other.baseUrl == baseUrl &&
      other.code == code &&
      other.apiKey == apiKey &&
      other.patience == patience;

  @override
  int get hashCode => Object.hash(baseUrl, code, apiKey, patience);

  /// **Ключ не печатается.** Настройку пишут в журнал при разборе беды, и
  /// журнал кассы уезжает в поддержку файлом.
  @override
  String toString() =>
      'QrProviderSettings($code, $baseUrl, '
      'key=${apiKey == null ? 'нет' : 'задан'}, patience=$patience)';
}
