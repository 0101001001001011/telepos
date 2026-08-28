/// Изолирующая проверка для шага 6: подаёт ли сама касса сигнал об изменении,
/// которое стенд делает через `/stand/configure`.
///
/// Нужна затем, что «страница не обновилась» имеет два разных объяснения, и
/// они лежат в разных местах: либо поток кассы не сработал вовсе (тогда
/// виноват мой способ менять состояние, и провод ни при чём), либо сработал —
/// и тогда потерялось на проводе или в браузере. Без этой проверки отчёт
/// назвал бы дефектом то, что дефектом может не быть.
@Tags(['manual'])
library;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_state_source.dart';

void main() {
  test('watchSetupStateOf подаёт второе значение после customUpdate', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final seen = <bool>[];
    final sub = watchSetupStateOf(db).listen((s) => seen.add(s.configured));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('ПЕРВОЕ: $seen');

    final changed = await db.customUpdate(
      'UPDATE this_pos_entries SET company_name = ? WHERE r_id = 1',
      variables: [Variable.withString('Ромашка')],
      updates: {db.thisPosEntries},
    );
    if (changed == 0) {
      await db.customInsert(
        'INSERT INTO this_pos_entries (r_id, company_name) VALUES (1, ?)',
        variables: [Variable.withString('Ромашка')],
        updates: {db.thisPosEntries},
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    await sub.cancel();
    // ignore: avoid_print
    print('ИЗМЕНЕНО СТРОК: $changed; ВСЕ ЗНАЧЕНИЯ: $seen');

    expect(seen.length, greaterThanOrEqualTo(2), reason: 'сигнал не пришёл');
    expect(seen.last, isTrue, reason: 'configured обязано стать true');
    await db.close();
  });
}
