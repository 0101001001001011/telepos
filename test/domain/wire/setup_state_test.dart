import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/setup_state.dart';

/// Круговой тест третьей сведённой пары — состояния установки.
///
/// Эта форма и есть измеренное доказательство того, зачем сводить пары.
/// Писатель (`SetupRoutes._state`) никогда не слал `hasUsers`, читатель
/// (`HttpStartupStateRepository.hasUsers`) его читал, и браузерный терминал
/// вечно получал `false` — «пользователей нет» на кассе, где они есть. Ни
/// один тест этого не ловил, потому что ловить было нечего: у формы не было
/// места, в котором обе стороны видны сразу.
void main() {
  test('состояние переживает круг туда-обратно со всеми полями', () {
    const state = SetupState(
      configured: true,
      hasUsers: true,
      companyName: 'ТОО «Ромашка»',
      cashBoxName: 'Касса-1',
      countryCode: 3,
    );

    final decoded = setupStateFromWireJson(setupStateToWireJson(state));

    expect(decoded.configured, state.configured);
    expect(
      decoded.hasUsers,
      state.hasUsers,
      reason:
          'ровно это поле писатель и не слал: круг обязан краснеть, если '
          'одна из половин его снова потеряет',
    );
    expect(decoded.companyName, state.companyName);
    expect(decoded.cashBoxName, state.cashBoxName);
    expect(decoded.countryCode, state.countryCode);
  });

  test('свежая установка переживает круг тем же способом', () {
    // Ненастроенная касса — не «ошибка чтения»: мастер ещё не проходил, и
    // имени организации просто нет. Пустой круг обязан давать пустое, а не
    // подставленное.
    final decoded = setupStateFromWireJson(
      setupStateToWireJson(const SetupState(configured: false, hasUsers: false)),
    );

    expect(decoded.configured, isFalse);
    expect(decoded.hasUsers, isFalse);
    expect(decoded.companyName, isNull);
    expect(decoded.cashBoxName, isNull);
    expect(decoded.countryCode, isNull);
  });

  test('отсутствующее поле читается как «нет», а не как «да»', () {
    // Касса старее терминала: поля в ответе нет вовсе. Умолчание обязано
    // быть тем, которое ничего не разрешает, — «настроено» по умолчанию
    // отправило бы оператора мимо мастера настройки на пустую кассу.
    final decoded = setupStateFromWireJson(const {});

    expect(decoded.configured, isFalse);
    expect(decoded.hasUsers, isFalse);
  });
}
