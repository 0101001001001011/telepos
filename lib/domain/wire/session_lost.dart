/// Сеанс терминала не назван токеном вовсе или неизвестен/истёк кассе — код
/// [WireDenied.unauthorized] (`lib/domain/wire/wire_guard.dart`).
///
/// # Почему отдельный тип, а не код внутри [WtProtocolError]
///
/// До этой задачи `WireGuard.check` отвечал одним и тем же
/// `ErrorFrame('unauthorized', …)` на любую причину `WireDenied` — нет
/// сеанса, сеанс истёк, не хватает права, касса уже настроена, операция не в
/// словаре. Первый круг правок завёл этот тип, репозитории
/// `lib/web/*_repository.dart` его код нигде не разбирали, и истёкший сеанс
/// выглядел как обрыв связи или отказ по данным. Второй круг обнаружил
/// следствие: раз все причины `WireDenied` шли одним кодом, кассир, которому
/// просто не хватает права (`forbidden`), тоже получил бы [SessionLost] и
/// ходил бы кругом «войди — получи тот же отказ». Ответ — не смешение на
/// клиенте, а разбор на кассе (`WireDenied.code`,
/// `lib/domain/wire/wire_guard.dart`): [SessionLost] заводится **только** из
/// [WireDenied.unauthorized]; `forbidden`, `already_configured`, `unknown_op`
/// остаются рядовым [WtProtocolError] и идут прежним путём отказа операции —
/// клиент не обязан заново разбирать текст причины, ровно как и в задаче 2б
/// (`WireRefusal`, `lib/domain/wire/wire_refusal.dart`).
///
/// # Почему `lib/domain/wire/`, а не `lib/web/`
///
/// До волны правок закрытия долга «замок кассы» этот тип жил в
/// `lib/web/wt_session_lost.dart` — единственный браузерный тип, который
/// `lib/presentation/controllers/auth/login_controller.dart` был вынужден
/// импортировать напрямую из `lib/web/`, слоя, у которого нет и не должно
/// быть места в графе представления (И5). Тот же шов и не дал экранам
/// настроек научиться ловить [SessionLost] отдельно от прочих отказов
/// провода — они видят только [WtDeviceCheck] и соседей через доменные
/// контракты, а тип отказа, который те решили пропустить наверх, жил вне
/// домена. [SessionLost] — родственник [WireRefusal] ровно в том же
/// смысле: оба формулирует касса для терминала, оба безопасны по построению
/// (см. докстринг [WireRefusal]), и `lib/web/*.dart` его лишь бросает и
/// ловит, не владея им.
final class SessionLost implements Exception {
  const SessionLost(this.detail);

  /// Текст кассы: `'${op}: ${verdict.reason}'` — например
  /// `'terminals.deviceCheck: сеанс неизвестен или истёк'`.
  final String detail;

  @override
  String toString() => 'SessionLost($detail)';
}
