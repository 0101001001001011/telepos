import 'package:meta/meta.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// Почему касса не впустила.
///
/// Причина названа, а не сведена к `false`: «неверный PIN» и «такой PIN у
/// двоих» требуют от экрана разных слов, и человек у кассы обязан понимать,
/// что ему делать дальше.
///
/// До второго круга задачи 7 (2026-08-21, `login_throttle.dart`) здесь был
/// шестой член — `tooManyAttempts`, для попытки, отклонённой без ожидания на
/// пределе одновременных задержек замка. Предел убран целиком: у
/// `LoginThrottle.penalizeFailure` не осталось второго исхода, который стоило
/// бы называть отдельной причиной, — и `tooManyAttempts` ушёл вместе с ним,
/// а не остался неиспользуемым членом enum.
enum AuthRejectionReason {
  /// PIN не подошёл.
  wrongPin,

  /// PIN подошёл **больше чем одному** кассиру. Вход под первым попавшимся
  /// означал бы деньги смены, записанные не на того.
  ambiguousPin,

  /// У выбранного кассира PIN не заведён вовсе.
  noPinSet,

  /// PIN набран без выбора имени, а walk-up на этой точке выключен.
  walkUpDisabled,

  /// Касса не смогла ответить — например, не прочитала права. Отказ, а не
  /// вход: сбой чтения прав до 2026-08-20 выдавал полный доступ
  /// (`login_controller.dart:446`).
  unknown,

  /// Запись PIN нечитаема; повторный набор не поможет, чинить нужно запись.
  credentialUnreadable,
}

/// Чем закончилась попытка входа: сеанс или названный отказ.
///
/// `sealed`, а не `Object?` и не пара «значение + ошибка»: разбор по ветвям
/// проверяется сборкой, и забытая ветвь становится ошибкой компиляции, а не
/// поведением. Тот же приём, что у `WireOp` (`lib/domain/wire/wire_op.dart:22`).
sealed class AuthOutcome {}

/// Выписанный кассой сеанс.
///
/// # Права здесь уже действующие
///
/// [permissions] — это `права роли ∩ права режима терминала`, посчитанные на
/// кассе. Терминалу нечего пересекать и нечем ошибиться, и это осознанно:
/// пересечение, посчитанное на клиенте, обходится клиентом.
@immutable
final class AuthSession implements AuthOutcome {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
    required this.permissions,
    required this.operatingMode,
    required this.pointMode,
    required this.shift,
    required this.issuedAt,
    required this.expiresAt,
    required this.terminalId,
  });

  /// Предъявляется кассе в каждой операции сеанса. Живёт в памяти кассы и в
  /// `sessionStorage` вкладки — нигде больше.
  final String token;

  final int userId;

  final String name;

  final String role;

  /// Действующие права: уже пересечённые с правами режима терминала.
  final Set<String> permissions;

  /// Режим работы точки (розница, ресторан, услуги, склад) — индексом, как он
  /// лежит в `ThisPos.operatingMode`.
  final int operatingMode;

  /// Режим терминала именем, а не индексом: вставка нового члена
  /// `PointMode` иначе поменяла бы смысл уже выписанного сеанса.
  final String pointMode;

  /// Смена на момент выписки сеанса — задача 47: три состояния, а не
  /// `bool` (разбор в [ShiftStatus]). Касса пишет только измеренное.
  final ShiftStatus shift;

  /// Терминал, под которым выписан этот сеанс — тот, что вкладка передала
  /// `AuthAttempt.terminalId` при входе (`LocalAuthRepository._issue`).
  ///
  /// # Почему обязательное, а не `int?`
  ///
  /// `TerminalIdentity.remember()` в этом проекте уже однажды оказывался не
  /// позванным ни одной строкой рабочего кода — необязательное поле молчало
  /// об этом до живой проверки в браузере. Обязательное поле не даёт
  /// собрать сеанс без него: забытая заводка станет ошибкой компиляции на
  /// каждом месте, что строит `AuthSession`, а не пустотой, замеченной
  /// только на настоящей установке.
  ///
  /// # Зачем это здесь (задача 9 закрытия долга)
  ///
  /// До этого поля касса не могла отличить «терминал, которым пользуется
  /// вкладка, приславшая этот кадр» от «терминал, названный в теле самого
  /// кадра» — а верить второму в вопросе владения нельзя ровно так же, как
  /// нельзя верить `terminalId` в `AuthAttempt` без проверки существования
  /// (`TillOperations.askHandlers[auth.login]`). `terminals.delete`
  /// (`TillOperations`) сверяет `terminalId` из тела запроса именно с этим
  /// полем, чтобы вкладка не могла удалить терминал, под которым сидит сама.
  final int terminalId;

  final DateTime issuedAt;

  /// Когда сеанс погаснет, если ничего не делать. Продлевается каждой
  /// операцией по сеансу.
  final DateTime expiresAt;

  /// Копия с точечными заменами.
  ///
  /// Заведён после того, как `SessionRegistry.lookup` (`lib/backend/session_registry.dart`)
  /// нашёлся собирающим продлённый сеанс вручную по всем десяти полям —
  /// единственное место в этом коде, которому вообще нужна копия: у
  /// продления меняется только [expiresAt]. Без `copyWith` следующее поле,
  /// заведённое на [AuthSession], там же и потерялось бы молча — тип не
  /// заметил бы пропуска в ручном перечислении.
  AuthSession copyWith({DateTime? expiresAt}) => AuthSession(
    token: token,
    userId: userId,
    name: name,
    role: role,
    permissions: permissions,
    operatingMode: operatingMode,
    pointMode: pointMode,
    shift: shift,
    issuedAt: issuedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    terminalId: terminalId,
  );
}

@immutable
final class AuthRejection implements AuthOutcome {
  const AuthRejection(this.reason);

  final AuthRejectionReason reason;
}
