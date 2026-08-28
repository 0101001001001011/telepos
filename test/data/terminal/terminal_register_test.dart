import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Задача 7 закрытия долга: `terminals.register` — открытая операция (её
/// зовёт сам вход раньше `auth.login`), и до неё вставляла новую строку без
/// дедупликации на любое имя — любой, кто дотянулся до кассы по QUIC
/// напрямую, мог плодить строки терминалов сколько угодно. Задача 7 добавила
/// потолок (тесты ниже) и заодно дедупликацию по имени.
///
/// **Дедупликация снята пунктом 6 фазы 3/4 закрытия долга (2026-08-21)** —
/// решение, а не откат находки задачи 7. Разбор нашёл, что она не защищала:
/// назначения не выполняла (единственный вызывающий,
/// `_defaultBrowserTerminalName` в `login_controller.dart`, шлёт имя со
/// штампом времени до секунды — совпадений не бывает), а вместо этого
/// открывала обход пункта 2 той же волны: `terminals.register` — `OpenAccess`
/// без сеанса, `terminals.rename` даёт выбрать имя человеку (значит оно не
/// секрет), и нападающий, узнавший чужое имя, получал бы через `register`
/// **ту же строку**, что и настоящий владелец — ровно тот путь, которым
/// пункт 2 закрывает подмену `terminalId` в теле `auth.login`. Подробности —
/// докстринг `LocalTerminalRepository.register`.
void main() {
  late AppDatabase db;
  late TerminalRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalTerminalRepository(db);
  });

  tearDown(() => db.close());

  test(
    'повторная регистрация с тем же именем заводит вторую строку — '
    'дедупликация снята пунктом 6',
    () async {
      final first = (await repo.register(name: 'Терминал у окна')).terminal;
      final second = (await repo.register(name: 'Терминал у окна')).terminal;

      expect(
        second.id,
        isNot(first.id),
        reason:
            'дедупликация по имени была дырой (см. докстринг класса) — '
            'снята нарочно, а не забыта: два вызова обязаны завести две '
            'строки',
      );

      final rows = await db.select(db.terminals).get();
      expect(rows, hasLength(2));
    },
  );

  test('регистрация сверх потолка отказывает названной причиной', () async {
    for (var i = 0; i < LocalTerminalRepository.maxTerminals; i++) {
      await repo.register(name: 'Терминал $i');
    }

    final rowsBeforeRefusal = await db.select(db.terminals).get();
    expect(rowsBeforeRefusal, hasLength(LocalTerminalRepository.maxTerminals));

    await expectLater(
      repo.register(name: 'Терминал сверх потолка'),
      throwsA(
        isA<WireRefusal>().having(
          (e) => e.code,
          'code',
          'terminal_limit_reached',
        ),
      ),
      reason:
          'потолок обязан отказывать названной причиной (WireRefusal), а '
          'не молча вставлять строку и не бросать ArgumentError с текстом '
          'для человека — этот канал закрыт нарочно',
    );

    final rowsAfterRefusal = await db.select(db.terminals).get();
    expect(
      rowsAfterRefusal,
      hasLength(LocalTerminalRepository.maxTerminals),
      reason:
          'отказ обязан быть побочно-чистым — лишней строки не должно остаться',
    );
  });

  test('потолок не мешает свежей установке завести первый терминал', () async {
    // Свежая установка обязана уметь завести первый терминал — потолок не
    // имеет права запереть кассу от самой себя.
    final terminal = (await repo.register(name: 'Первый терминал')).terminal;
    expect(terminal.id, isNotNull);
  });

  // Пункт 7 фазы 3/4 закрытия долга: путь освободить место назван брифом
  // задачи 8, но тест «упёрлись в потолок → удалили → завели снова»,
  // которым она обосновывалась, заведён не был.
  test(
    'упёрлись в потолок → удалили один → завели снова без отказа',
    () async {
      final ids = <int>[];
      for (var i = 0; i < LocalTerminalRepository.maxTerminals; i++) {
        ids.add((await repo.register(name: 'Терминал $i')).terminal.id);
      }

      await expectLater(
        repo.register(name: 'Терминал сверх потолка'),
        throwsA(isA<WireRefusal>()),
        reason: 'предпосылка — потолок действительно упёрт',
      );

      await repo.delete(ids.first);
      expect(
        await db.select(db.terminals).get(),
        hasLength(LocalTerminalRepository.maxTerminals - 1),
        reason: 'освобождённое место обязано быть видно в счёте строк',
      );

      final freed =
          (await repo.register(name: 'Терминал после освобождения')).terminal;
      expect(
        freed.id,
        isNotNull,
        reason:
            'место освобождено — заводка обязана пройти, а не повторить '
            'отказ потолка',
      );
      expect(
        await db.select(db.terminals).get(),
        hasLength(LocalTerminalRepository.maxTerminals),
      );
    },
  );

  // Задача 4 плана «знакомство терминала с кассой», шаг 1 брифа: заведение
  // отдаёт секрет; на кассе лежит отпечаток, не значение.
  group('секрет терминала (задача 4)', () {
    test('заведение отдаёт непустой высокоэнтропийный секрет', () async {
      final enrollment = await repo.register(name: 'Касса у входа');

      expect(enrollment.secret, isNotEmpty);
      expect(
        enrollment.secret.length,
        greaterThanOrEqualTo(32),
        reason:
            '32 байта (256 бит), закодированные base64Url, дают заведомо '
            'больше 32 символов — короткая строка значила бы, что секрет не '
            'той длины, что заявлено в докстринге TerminalSecret',
      );
    });

    test(
      'на кассе лежит отпечаток — сырое значение секрета в строке не '
      'встречается',
      () async {
        final enrollment = await repo.register(name: 'Касса у входа');

        final row = await db.terminalDao.findById(enrollment.terminal.id);
        expect(row, isNotNull);
        expect(
          row!.secretFingerprint,
          isNotNull,
          reason: 'заведение обязано записать отпечаток на кассе',
        );
        expect(
          row.secretFingerprint,
          isNot(enrollment.secret),
          reason: 'колонка обязана нести отпечаток, а не секрет как есть',
        );
        expect(
          row.secretFingerprint,
          isNot(contains(enrollment.secret)),
          reason:
              'ГЛАВНАЯ ПРОВЕРКА: сырое значение секрета не должно быть '
              'подстрокой хранимого отпечатка ни в каком виде — сломанная '
              'реализация, которая просто дописывает секрет к отпечатку '
              '(вместо его свёртки), обязана поймать эту проверку',
        );
        expect(
          row.secretFingerprint,
          startsWith('sha256\$'),
          reason:
              'формат самоописывающийся, тем же приёмом, что и '
              'PinCredential — TerminalSecret.fingerprint',
        );
      },
    );

    test(
      'два заведения дают разные секреты и разные отпечатки — не константа '
      'и не эхо имени',
      () async {
        final first = await repo.register(name: 'Терминал A');
        final second = await repo.register(name: 'Терминал B');

        expect(first.secret, isNot(second.secret));

        final firstRow = await db.terminalDao.findById(first.terminal.id);
        final secondRow = await db.terminalDao.findById(second.terminal.id);
        expect(
          firstRow!.secretFingerprint,
          isNot(secondRow!.secretFingerprint),
          reason:
              'разные секреты (и разные случайные соли) обязаны дать разные '
              'отпечатки — совпадение значило бы, что fingerprint игнорирует '
              'вход',
        );
      },
    );

    test(
      'отпечаток, записанный на кассе, действительно сходится со своим '
      'секретом через TerminalSecret — не выдуманная форма, а настоящий приём',
      () async {
        final enrollment = await repo.register(name: 'Касса у входа');
        final row = await db.terminalDao.findById(enrollment.terminal.id);

        final parts = row!.secretFingerprint!.split('\$');
        expect(parts, hasLength(3));
        expect(parts[0], 'sha256');
        final salt = parts[1];

        // Пересчитывает отпечаток тем же путём, каким его строит
        // TerminalSecret.fingerprint — детерминированной солью через
        // тестовый Random, а не полагаясь на внутренний формат вслепую.
        final recomputed = TerminalSecret.fingerprint(
          enrollment.secret,
          random: _FixedSalt(salt),
        );
        expect(recomputed, row.secretFingerprint);
      },
    );
  });

  // Задача 5 плана «знакомство терминала с кассой», шаг 2 брифа: вкладка,
  // пережившая F5, предъявляет секрет обратно вместо того, чтобы заводить
  // новую строку заново.
  group('возврат по секрету (задача 5)', () {
    test(
      'свой секрет возвращает тот же терминал — та же строка, не новая',
      () async {
        final enrollment = await repo.register(name: 'Терминал у окна');

        final resumed = await repo.resume(
          terminalId: enrollment.terminal.id,
          secret: enrollment.secret,
        );

        expect(resumed.id, enrollment.terminal.id);
        expect(resumed.name, enrollment.terminal.name);
        expect(
          await db.select(db.terminals).get(),
          hasLength(1),
          reason:
              'ГЛАВНАЯ ПРОВЕРКА: возврат по секрету не имеет права вставить '
              'вторую строку — это и есть цель задачи 5',
        );
      },
    );

    test(
      'чужой секрет отказывает, а не отдаёт свой терминал под чужим видом',
      () async {
        final owner = await repo.register(name: 'Терминал владельца');
        final impostorEnrollment = await repo.register(
          name: 'Терминал самозванца',
        );

        await expectLater(
          repo.resume(
            terminalId: owner.terminal.id,
            secret: impostorEnrollment.secret,
          ),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              'terminal_secret_invalid',
            ),
          ),
          reason:
              'ГЛАВНАЯ ПРОВЕРКА: секрет одного терминала не имеет права '
              'открыть чужую строку — отказ, а не чужой terminalId',
        );
      },
    );

    test('секрет удалённого терминала отказывает, id не воскресает', () async {
      final enrollment = await repo.register(name: 'Терминал на удаление');
      await repo.delete(enrollment.terminal.id);

      await expectLater(
        repo.resume(
          terminalId: enrollment.terminal.id,
          secret: enrollment.secret,
        ),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            'terminal_secret_invalid',
          ),
        ),
      );
    });

    test('несуществующий terminalId отказывает тем же кодом', () async {
      await expectLater(
        repo.resume(terminalId: 999999, secret: 'что-нибудь'),
        throwsA(
          isA<WireRefusal>().having(
            (e) => e.code,
            'code',
            'terminal_secret_invalid',
          ),
        ),
      );
    });

    test(
      'строка старше миграции v35→v36 (secretFingerprint == null) '
      'отказывает, а не падает',
      () async {
        // Тот самый случай, который описывает докстринг миграции v36:
        // строка, заведённая до неё, остаётся с secretFingerprint == null
        // навсегда. Вставлена здесь напрямую, минуя register() — только он
        // и умеет заполнить отпечаток, значит только прямая вставка
        // воспроизводит строку без него.
        final id = await db
            .into(db.terminals)
            .insert(
              TerminalsCompanion.insert(
                name: 'Терминал до миграции',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            );
        final row = await db.terminalDao.findById(id);
        expect(
          row!.secretFingerprint,
          isNull,
          reason: 'предпосылка — строка действительно без отпечатка',
        );

        await expectLater(
          repo.resume(terminalId: id, secret: 'любой секрет'),
          throwsA(
            isA<WireRefusal>().having(
              (e) => e.code,
              'code',
              'terminal_secret_invalid',
            ),
          ),
        );
      },
    );

    test('пустой секрет против настоящего терминала отказывает', () async {
      final enrollment = await repo.register(name: 'Терминал у входа');

      await expectLater(
        repo.resume(terminalId: enrollment.terminal.id, secret: ''),
        throwsA(isA<WireRefusal>()),
      );
    });
  });
}

/// `Random`, чей единственный выход — байты заранее известной base64Url-соли
/// [salt], байт за байтом. Существует только чтобы пересчитать отпечаток
/// [TerminalSecret.fingerprint] с ТОЙ ЖЕ солью, которую он уже выбрал сам —
/// без этого сверить самоописывающуюся строку можно было бы только текстовым
/// сравнением с самой собой (бессмысленно) либо пересборкой формата вручную
/// (дублирует приватную `_fingerprintWithSalt`, а не проверяет её).
class _FixedSalt implements Random {
  _FixedSalt(String base64UrlSalt) : _bytes = base64Url.decode(_pad(base64UrlSalt));

  static String _pad(String s) => s + '=' * ((4 - s.length % 4) % 4);

  final List<int> _bytes;
  int _cursor = 0;

  @override
  int nextInt(int max) {
    final value = _bytes[_cursor % _bytes.length];
    _cursor++;
    return value;
  }

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}
