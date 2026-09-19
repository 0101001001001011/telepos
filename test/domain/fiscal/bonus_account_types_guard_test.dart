@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';

/// Сторож на **форму**: «типы счетов 4 и 7 — это бонус» сказано один раз.
///
/// # Почему сторож читает исходники, а не поведение
///
/// Поведенческая проба здесь бессильна по построению. Две копии одного
/// условия ведут себя одинаково ровно до того дня, когда одну из них
/// поправят, — и в этот день покраснеет не сторож, а касса у клиента.
/// Дефект, который здесь ловится, живёт **в форме кода**, и мерить его
/// нужно тоже формой.
///
/// # Что именно ищется
///
/// Не литералы `4` и `7` — их в дереве тысячи. Ищется **условие о роде
/// счёта**: перечисление двух бонусных родов рядом, в любом из видов, в
/// которых оно уже встречалось в этом дереве:
///
/// - `type == AccountType.agentCashback || type == AccountType.cashback`
///   (так писали `AccountPosting` и `SaleReceiptComposer`);
/// - `type IN (4, 7)` — так его написала бы миграция.
///
/// Разрешённых мест ровно два: объявление [BonusAccountTypes] и этот файл.
void main() {
  final root = Directory.current.path.replaceAll(r'\', '/');

  /// Все `.dart` дерева продукта, кроме сгенерированных.
  List<File> productSources() {
    final files = <File>[];
    for (final dir in const ['lib', 'test']) {
      final d = Directory('$root/$dir');
      if (!d.existsSync()) continue;
      for (final e in d.listSync(recursive: true)) {
        if (e is! File) continue;
        final p = e.path.replaceAll(r'\', '/');
        if (!p.endsWith('.dart')) continue;
        if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) continue;
        files.add(e);
      }
    }
    return files;
  }

  /// Условие «этот счёт бонусный», написанное руками.
  ///
  /// Обе ветви обязаны называть **оба** рода — одиночное упоминание
  /// `AccountType.cashback` законно (например, `createAcquiringAccount`
  /// заводит счёт своего рода), и запрещать его значило бы сторожить не то.
  ///
  /// **Ищется через перевод строки, а не в пределах строки.** Первая
  /// редакция этого сторожа шла построчно и **пропустила настоящую вторую
  /// копию**: `AccountPosting.isRedemption` записан в три строки, и ни в
  /// одной из них оба рода рядом не стоят. Сторож был зелен ровно там, где
  /// дефект и жил, — и это измерено прогоном, а не рассуждением.
  final handWritten = RegExp(
    r'(agentCashback[\s\S]{0,120}\|\|[\s\S]{0,120}\bcashback\b)'
    r'|(\bcashback\b[\s\S]{0,120}\|\|[\s\S]{0,120}agentCashback)'
    r'|(type\s+IN\s*\(\s*4\s*,\s*7\s*\))',
  );

  /// Тот же исходник без комментариев: докстринг, объясняющий правило,
  /// обязан иметь право его процитировать. Сторож на форму, запретивший
  /// объяснять себя, — сторож против читателя.
  ///
  /// Строки вычёркиваются, а не удаляются: номер строки в отчёте обязан
  /// оставаться настоящим.
  String withoutComments(String text) => text
      .split('\n')
      .map((line) {
        final code = line.trimLeft();
        return code.startsWith('//') ? '' : line;
      })
      .join('\n');

  test('«4 и 7 — бонус» объявлено ровно один раз', () {
    final hits = <String>[];
    for (final f in productSources()) {
      final rel = f.path.replaceAll(r'\', '/').replaceFirst('$root/', '');
      // Объявление и этот сторож — единственные, кому условие писать можно.
      if (rel == 'lib/domain/fiscal/bonus_account_types.dart') continue;
      if (rel == 'test/domain/fiscal/bonus_account_types_guard_test.dart') {
        continue;
      }
      final code = withoutComments(f.readAsStringSync());
      final match = handWritten.firstMatch(code);
      if (match != null) {
        hits.add('$rel: ${match.group(0)!.replaceAll('\n', ' ⏎ ')}');
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'условие о бонусном роде счёта живёт в BonusAccountTypes.isBonus '
          '(и в sqlInList для миграций). Найденные копии разъедутся:\n'
          '${hits.join('\n')}',
    );
  });

  test('список родов — это те самые 4 и 7, а не «что-нибудь»', () {
    // Сторож на форму без сторожа на содержание — театр: пустой [values]
    // прошёл бы предыдущую пробу целиком.
    expect(BonusAccountTypes.values, [4, 7]);
    expect(BonusAccountTypes.isBonus(AccountType.agentCashback), isTrue);
    expect(BonusAccountTypes.isBonus(AccountType.cashback), isTrue);
    expect(BonusAccountTypes.sqlInList, '(4, 7)');

    // Слом в обе стороны: **ни один** прочий род счёта бонусным не является.
    // Перечислены все восемь, а не «пара для примера»: проба, спросившая про
    // два рода из восьми, зелена и у реализации `isBonus => true`.
    for (final type in const [
      AccountType.pos,
      AccountType.customBank,
      AccountType.customCash,
      AccountType.agentMain,
      AccountType.teleposMain,
      AccountType.teleposBonus,
    ]) {
      expect(
        BonusAccountTypes.isBonus(type),
        isFalse,
        reason: 'род $type бонусным не объявлялся',
      );
    }

    // `teleposBonus` (6) в списке нет **намеренно**, и это не описка: счёт
    // рода 6 принадлежит поставщику программы, а не покупателю, и платёж на
    // него — приход. Утверждение стоит здесь, чтобы правка списка «за
    // компанию» покраснела.
    expect(BonusAccountTypes.isBonus(AccountType.teleposBonus), isFalse);
  });
}
