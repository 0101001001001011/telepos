import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';

void main() {
  group('WireAccess', () {
    test('разбирается по ветвям, а не по полю', () {
      const List<WireAccess> all = [
        OpenAccess(),
        SessionAccess(),
        SessionAccess(needs: PermissionKeys.settingsHardware),
        SetupOnlyAccess(),
        EnrolmentAccess(),
      ];

      final names = all
          .map(
            (a) => switch (a) {
              OpenAccess() => 'открыто',
              SessionAccess() => 'сеанс',
              SetupOnlyAccess() => 'до настройки',
              EnrolmentAccess() => 'знакомство',
            },
          )
          .toList();

      expect(names, ['открыто', 'сеанс', 'сеанс', 'до настройки', 'знакомство']);
    });
  });

  group('каталог операций', () {
    test('ровно шестнадцать открытых, и это именно они', () {
      // Открытая операция — единственная дыра в защите по устройству, поэтому
      // список закреплён поимённо. Новая открытая операция обязана попасть
      // сюда осознанно, а не проскользнуть.
      //
      // `terminals.register` здесь больше нет — задача 6 плана «знакомство
      // терминала с кассой» (шаг 3 спеки) увела её в [EnrolmentAccess]
      // (проверено отдельно, ниже). `terminals.resume` (задача 5) добавлена
      // — она была `OpenAccess()` с самого начала (сторожу нечего проверять:
      // секрет — довод самого запроса), но эта раскладка не поспевала за ней
      // до этой правки: список остаётся закрытым поимённо, а не по счёту, и
      // отсутствие здесь новой открытой операции — само по себе находка, не
      // повод продолжать её не замечать.
      //
      // Шесть `network.*` (задача «сетевые настройки по проводу», спека
      // 2026-08-24) — открыты по тому же доводу, что и `terminals.self`:
      // экран публичный и на десктопе, доступен с экрана входа и из мастера.
      final open = TillOps.all
          .where((op) => op.access is OpenAccess)
          .map((op) => op.name)
          .toSet();

      expect(open, {
        'startup.boot',
        'setup.state',
        'setup.firstLaunch',
        'auth.users',
        'auth.login',
        'auth.logout',
        'auth.session',
        'terminals.self',
        'terminals.resume',
        'terminals.selfEnsure',
        'network.status',
        'network.wifiScan',
        'network.wifiConnect',
        'network.wifiDisconnect',
        'network.ethernetStatus',
        'network.ethernetConfigure',
      });
    });

    test(
      'гейт знакомства — задача 6: ровно одна операция несёт EnrolmentAccess',
      () {
        // Довод (код привязки) сторож не проверяет — докстринг
        // [EnrolmentAccess] — так что дыра, случись новой операции незаметно
        // унаследовать этот тип, была бы видна не сторожу, а только
        // обработчику, который её забыл проверить. Список закрыт поимённо
        // ровно по той же причине, что и открытые операции выше.
        final enrolment = TillOps.all
            .where((op) => op.access is EnrolmentAccess)
            .map((op) => op.name)
            .toSet();

        expect(enrolment, {'terminals.register'});
      },
    );

    test('печать пробного чека и ящик требуют права на оборудование', () {
      // deviceCheck печатает чек и открывает денежный ящик. До этой работы
      // операция была доступна любому, кто дотянулся до кассы по QUIC.
      //
      // `terminals.deviceBindings` — правка 2 волны закрытия долга
      // безопасности (2026-08-22): до неё она была единственной в своей
      // группе `ownTerminal.same` без `needs` вовсе, и любой живой сеанс без
      // права мог прочитать привязки устройств терминала.
      for (final name in const [
        'terminals.deviceCheck',
        'terminals.deviceDiscovery',
        'terminals.deviceBindings',
        'terminals.deviceBindingSave',
        'terminals.rename',
        'terminals.delete',
      ]) {
        final op = TillOps.all.firstWhere((o) => o.name == name);
        final access = op.access;
        expect(access, isA<SessionAccess>(), reason: name);
        expect(
          (access as SessionAccess).needs,
          PermissionKeys.settingsHardware,
          reason: name,
        );
      }
    });

    test('владение терминалом — задача 10: раскладка поимённо', () {
      // До этой задачи `terminals.rename`, `terminals.deviceBindings`,
      // `terminals.deviceBindingSave` и `terminals.deviceCheck` брали
      // `terminalId` из тела и не сверяли его с сеансом вовсе — кассир мог
      // напечатать чек и открыть ящик чужого терминала. `terminals.delete`
      // (задача 9) устроен наоборот: он не должен нацелиться на терминал
      // вызывающей вкладки. `terminals.deviceDiscovery` не про конкретный
      // терминал (ищет устройства кассы вообще, без `terminalId` в теле) и
      // намеренно не входит ни в одну из групп.
      const same = {
        'terminals.rename',
        'terminals.deviceBindings',
        'terminals.deviceBindingSave',
        'terminals.deviceCheck',
      };
      const different = {'terminals.delete'};

      for (final op in TillOps.all) {
        final access = op.access;
        if (access is! SessionAccess) continue;
        final expected = same.contains(op.name)
            ? TerminalOwnership.same
            : different.contains(op.name)
            ? TerminalOwnership.different
            : null;
        expect(access.ownTerminal, expected, reason: op.name);
      }
    });

    test(
      'список сеансов и их отзыв требуют право распоряжаться входом, не '
      'оборудованием',
      () {
        // Задача 19 закрытия долга безопасности: `SessionRegistry
        // .revokeAll()` существовал с задачи 9 и не звался ни одной
        // строкой рабочего кода. Отзыв чужого сеанса — не то же самое, что
        // настройка оборудования (`settingsHardware`): это тот же
        // периметр, что и у `/auth-settings` (задача 18) — «кто и как
        // входит в кассу». Правка, а не подгонка числом: без неё новая
        // пара операций могла бы тихо унести настоящий пароль права
        // (например, унаследовать `settingsHardware` копипастой соседней
        // операции) и разбор бы этого не заметил — тест ниже называет
        // ожидаемое право поимённо, а не считает штуки.
        for (final name in const ['auth.sessions', 'auth.sessionRevoke']) {
          final op = TillOps.all.firstWhere((o) => o.name == name);
          final access = op.access;
          expect(access, isA<SessionAccess>(), reason: name);
          expect(
            (access as SessionAccess).needs,
            PermissionKeys.settingsUsers,
            reason: name,
          );
          expect(
            access.ownTerminal,
            isNull,
            reason:
                '$name обязана уметь нацелиться на терминал, отличный от '
                'терминала вызывающей вкладки — иначе отзывать было бы '
                'нечего',
          );
        }
      },
    );

    test('мастер настройки открыт только до настройки', () {
      final setupOnly = TillOps.all
          .where((op) => op.access is SetupOnlyAccess)
          .map((op) => op.name)
          .toSet();

      expect(setupOnly, {
        'setup.backups',
        'setup.newPos',
        'setup.restore',
        'setup.loadGlobalData',
        'setup.complete',
      });
    });
  });
}
