/// Состояние установки на проводе — **читатель и писатель в одной паре**.
///
/// # Зачем этому файлу существовать
///
/// Это та самая форма, на которой цена раздельных половин была измерена.
/// Писатель — `SetupRoutes._state` — слал `configured`, `companyName`,
/// `cashBoxName` и `countryCode`. Читатель — `HttpStartupStateRepository` —
/// читал `configured` и `hasUsers`. Поля `hasUsers` в ответе не было **ни
/// разу**, и `state['hasUsers'] == true` спокойно давало `false`: браузерный
/// терминал считал, что на кассе нет ни одного пользователя, и отправлял
/// оператора в мастер настройки поверх работающей кассы.
///
/// Ни один тест этого не поймал, и не мог: круговой тест доказывает согласие
/// только тех полей, которые в нём названы, а поля, которого нет ни у кого в
/// голове, никто и не назовёт. Ловится это одним способом — местом, где обе
/// половины видны сразу. Оно здесь.
///
/// # Почему `SetupState`, а не две отдельные операции
///
/// `StartupStateRepository` спрашивает два раза — `isConfigured()` и
/// `hasUsers()`, — и по HTTP это были два запроса за один экран. Состояние
/// одно, приезжает оно одним кадром, и с переходом на `watch` (задача 16)
/// приезжает само, без вопроса.
library;

/// Что касса отвечает на `setup.state`.
class SetupState {
  const SetupState({
    required this.configured,
    required this.hasUsers,
    this.companyName,
    this.cashBoxName,
    this.countryCode,
  });

  /// Мастер настройки пройден: у установки есть непустое имя организации.
  final bool configured;

  /// Есть хоть одна учётная запись, под которой можно войти.
  final bool hasUsers;

  /// [companyName], [cashBoxName] и [countryCode] сегодня не читает ни один
  /// вызывающий — их слал `SetupRoutes._state`, и они остаются здесь, потому
  /// что убрать поле у формы провода означает сломать того, кто про него
  /// знает, а знать про него может не наш браузер (И18). Появится читатель —
  /// поле уже едет; не появится — оно стоит трёх строк.
  final String? companyName;

  final String? cashBoxName;

  /// Индекс `CountryCode` — как его хранит `ThisPos.countryCode`.
  final int? countryCode;
}

/// Пишет [SetupState] в форму провода. Обратная — [setupStateFromWireJson].
Map<String, Object?> setupStateToWireJson(SetupState state) => {
  'configured': state.configured,
  'hasUsers': state.hasUsers,
  'companyName': state.companyName,
  'cashBoxName': state.cashBoxName,
  'countryCode': state.countryCode,
};

/// Читает [SetupState] из формы провода. Обратная — [setupStateToWireJson].
///
/// Отсутствующий флаг читается как `false`, а не как `true`: умолчание обязано
/// быть тем, которое ничего не разрешает. «Настроено» по умолчанию провело бы
/// оператора мимо мастера настройки на пустую кассу.
SetupState setupStateFromWireJson(Map<String, dynamic> json) => SetupState(
  configured: json['configured'] == true,
  hasUsers: json['hasUsers'] == true,
  companyName: json['companyName'] as String?,
  cashBoxName: json['cashBoxName'] as String?,
  countryCode: json['countryCode'] as int?,
);
