import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/data/terminal/terminal_identity_local.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('клиент без записи не знает, какой он терминал', () async {
    final prefs = await SharedPreferences.getInstance();
    final TerminalIdentity identity = PrefsTerminalIdentity(prefs);

    expect(await identity.currentId(), isNull);
  });

  test('запомненный терминал сохраняется между обращениями', () async {
    final prefs = await SharedPreferences.getInstance();
    final TerminalIdentity identity = PrefsTerminalIdentity(prefs);

    await identity.remember(7);

    expect(await identity.currentId(), 7);
    expect(
      await PrefsTerminalIdentity(prefs).currentId(),
      7,
      reason: 'личность живёт у клиента, а не в памяти объекта',
    );
  });

  test(
    'remember() пишет новый id и не трогает чужой ключ, уже лежащий в хранилище',
    () async {
      // Раньше тест только читал currentId() и ничего не писал — «сосед
      // выжил» было тривиально верно, потому что ничего не могло его
      // стереть. Здесь remember() действительно вызывается поверх
      // хранилища с чужим ключом, и проверяется и новое значение, и то, что
      // чужой ключ пережил запись.
      SharedPreferences.setMockInitialValues({
        'some_unrelated_key': 'unrelated_value',
        'terminal_id': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      final TerminalIdentity identity = PrefsTerminalIdentity(prefs);

      await identity.remember(9);

      expect(
        await identity.currentId(),
        9,
        reason: 'remember() обязан заменить прежний terminal_id новым',
      );
      expect(
        prefs.getString('some_unrelated_key'),
        'unrelated_value',
        reason: 'запись terminal_id не должна задевать чужой ключ рядом',
      );
    },
  );
}
