import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/terminal/terminal_secret.dart';

/// `TerminalSecret` — задача 4 плана «знакомство терминала с кассой» (шаг 2
/// спеки). Pure-Dart, без базы: то, что этот файл доказывает, доказывается
/// один раз здесь, а не в каждом тесте, который его использует
/// (`terminal_register_test.dart` проверяет, что оно действительно
/// используется в `LocalTerminalRepository.register`, не переизобретает эти
/// проверки).
///
/// # Сколько энтропии и почему хватает
///
/// [TerminalSecret.generate] берёт 32 байта (256 бит) из `Random.secure()`.
/// Пространство значений — 2²⁵⁶ — не перебирается ни на каком практическом
/// горизонте: для сравнения, четырёхзначный PIN (10⁴, `PinCredential`) уже
/// перебирается за минуты на одном ядре (докстринг `pin_credential_test.dart`).
/// Этот файл не пытается доказать «перебор невозможен» измерением — на таком
/// пространстве измерить нечего, — а проверяет то, что измеримо: длина
/// действительно соответствует заявленным 256 битам, и генерация
/// действительно не повторяется на практике (тест ниже — не доказательство
/// теоремы, а сторож от вырожденной реализации вроде константы или счётчика).
void main() {
  group('TerminalSecret.generate — форма и энтропия', () {
    test('длина соответствует 256 битам (32 байта base64Url без паддинга)', () {
      final secret = TerminalSecret.generate();

      // 32 байта → 43 символа base64Url без '=' (ceil(32*4/3), обрезано
      // паддингом, которое generate() снимает явно). Точное число, а не
      // "достаточно длинная строка": реализация, тайно урезающая длину до
      // "выглядит длинно", прошла бы менее точную проверку.
      expect(secret.length, 43);
      expect(secret, isNot(contains('=')), reason: 'паддинг снят явно');
    });

    test('1000 подряд сгенерированных секретов — ни одного повтора', () {
      final secrets = {for (var i = 0; i < 1000; i++) TerminalSecret.generate()};

      expect(
        secrets.length,
        1000,
        reason:
            'вырожденная реализация (константа, счётчик, слабый генератор) '
            'дала бы повтор задолго до тысячи попыток на 256-битном '
            'пространстве',
      );
    });

    test('генерация детерминирована при подставленном Random — довод тестов', () {
      // Не рабочий путь (там всегда Random.secure()) — довод, которым
      // terminal_register_test.dart пересчитывает отпечаток без доступа к
      // приватной свёртке.
      final a = TerminalSecret.generate(random: _FixedByte(7));
      final b = TerminalSecret.generate(random: _FixedByte(7));
      expect(a, b);
    });
  });

  group('TerminalSecret.fingerprint — отпечаток, не значение', () {
    test('отпечаток не содержит секрет ни как подстроку, ни целиком', () {
      final secret = TerminalSecret.generate();
      final fingerprint = TerminalSecret.fingerprint(secret);

      expect(fingerprint, isNot(secret));
      expect(
        fingerprint.contains(secret),
        isFalse,
        reason:
            'ГЛАВНАЯ ПРОВЕРКА: реализация, которая дописывает секрет к '
            'отпечатку вместо его свёртки, обязана поймать эту проверку',
      );
    });

    test('формат самоописывающийся: sha256\$<соль>\$<свёртка>, три части', () {
      final secret = TerminalSecret.generate();
      final fingerprint = TerminalSecret.fingerprint(secret);

      final parts = fingerprint.split('\$');
      expect(parts, hasLength(3));
      expect(parts[0], 'sha256');
      expect(parts[1], isNotEmpty, reason: 'соль');
      expect(
        parts[2],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: 'sha256 в hex — 64 символа',
      );
    });

    test(
      'тот же секрет, две выдачи fingerprint() подряд — разные отпечатки '
      '(случайная соль на рабочем пути)',
      () {
        final secret = TerminalSecret.generate();
        final first = TerminalSecret.fingerprint(secret);
        final second = TerminalSecret.fingerprint(secret);

        expect(
          first,
          isNot(second),
          reason:
              'без случайной соли на каждый вызов таблица отпечатков одного '
              'секрета, посчитанная заранее, годилась бы против всех '
              'терминалов сразу — соль обязана меняться, даже когда секрет '
              'не меняется',
        );
      },
    );

    test('одна и та же соль (Random зафиксирован) — детерминированный отпечаток', () {
      final secret = TerminalSecret.generate();
      final a = TerminalSecret.fingerprint(secret, random: _FixedByte(3));
      final b = TerminalSecret.fingerprint(secret, random: _FixedByte(3));

      expect(
        a,
        b,
        reason:
            'при одинаковой соли и одинаковом секрете свёртка обязана '
            'совпасть — иначе fingerprint() не является чистой функцией от '
            'своих входов',
      );
    });

    test('разные секреты — разные отпечатки даже при одинаковой соли', () {
      final a = TerminalSecret.fingerprint('secret-one', random: _FixedByte(9));
      final b = TerminalSecret.fingerprint('secret-two', random: _FixedByte(9));

      expect(a, isNot(b));
    });
  });

  // Задача 5 плана «знакомство терминала с кассой»: вкладка предъявляет
  // секрет обратно, и `matches` — единственное место, которое умеет
  // ответить, свой он или чужой.
  group('TerminalSecret.matches — свой секрет против чужого', () {
    test('свой секрет против своего отпечатка — true', () {
      final secret = TerminalSecret.generate();
      final fingerprint = TerminalSecret.fingerprint(secret);

      expect(TerminalSecret.matches(secret, fingerprint), isTrue);
    });

    test('чужой секрет против чужого отпечатка — false, не эхо чужого id', () {
      final owner = TerminalSecret.generate();
      final impostor = TerminalSecret.generate();
      final fingerprint = TerminalSecret.fingerprint(owner);

      expect(
        TerminalSecret.matches(impostor, fingerprint),
        isFalse,
        reason:
            'ГЛАВНАЯ ПРОВЕРКА: секрет одного терминала не имеет права '
            'сойтись с отпечатком другого',
      );
    });

    test('один и тот же секрет, отпечаток с другой солью — всё равно true', () {
      // fingerprint() берёт случайную соль на каждый вызов (докстринг
      // класса) — matches() обязана извлечь соль из хранимого отпечатка, а
      // не полагаться на то, что она совпадёт со свежей.
      final secret = TerminalSecret.generate();
      final first = TerminalSecret.fingerprint(secret);
      final second = TerminalSecret.fingerprint(secret);
      expect(first, isNot(second), reason: 'предпосылка — соли разные');

      expect(TerminalSecret.matches(secret, first), isTrue);
      expect(TerminalSecret.matches(secret, second), isTrue);
    });

    test('отсутствующий отпечаток (null) — false, а не исключение', () {
      // Терминал, заведённый до миграции v35→v36 (задача 4), хранит
      // secretFingerprint == null. Предъявление любого секрета такому
      // терминалу обязано ответить «нет», не упасть.
      expect(TerminalSecret.matches('что-нибудь', null), isFalse);
    });

    test('пустой отпечаток — false', () {
      expect(TerminalSecret.matches('что-нибудь', ''), isFalse);
    });

    test('испорченный отпечаток (не самоописывающийся формат) — false', () {
      expect(
        TerminalSecret.matches('секрет', 'совсем не то, что нужно'),
        isFalse,
      );
      expect(
        TerminalSecret.matches('секрет', 'sha256\$только-соль-без-свёртки'),
        isFalse,
      );
      expect(
        TerminalSecret.matches('секрет', 'md5\$соль\$свёртка'),
        isFalse,
        reason: 'алгоритм в формате обязан быть sha256, а не угадан',
      );
    });

    test('пустой секрет против настоящего отпечатка — false', () {
      final fingerprint = TerminalSecret.fingerprint(TerminalSecret.generate());
      expect(TerminalSecret.matches('', fingerprint), isFalse);
    });
  });
}

/// `Random`, всегда отдающий один и тот же байт [byte]. Довод тестов —
/// проверяет чистоту функций [TerminalSecret.generate]/[TerminalSecret.fingerprint]
/// относительно своих входов без полагания на внутренний формат.
class _FixedByte implements Random {
  const _FixedByte(this.byte);

  final int byte;

  @override
  int nextInt(int max) => byte % max;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}
