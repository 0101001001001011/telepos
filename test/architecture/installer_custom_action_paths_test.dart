@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Сторож одной обратной косой, из-за которой установщик не ставился вообще.
///
/// # Что было
///
/// ```xml
/// ExeCommand="powershell.exe ... -File &quot;[INSTALLFOLDER]trust.ps1&quot;
///             -Register -InstallDir &quot;[INSTALLFOLDER]&quot;"
/// ```
///
/// Путь каталога в MSI всегда раскрывается с завершающей обратной косой:
/// `C:\Program Files\TelePOS\`. По правилам `CommandLineToArgvW` такая косая
/// перед закрывающей кавычкой экранирует **саму кавычку**, и до скрипта
/// доезжало `C:\Program Files\TelePOS"` — со шальной кавычкой на конце.
/// `Test-Path` на таком пути ложен, `Invoke-Register` бросал «не найден … —
/// регистрировать нечего», действие возвращало 1, MSI — 1722, установка —
/// 1603 и полный откат.
///
/// Измерено 2026-08-06 на первой же попытке поставить собранный MSI: до этого
/// установщик собирали, но ни разу не ставили, и потому дефект прожил в дереве
/// с самого появления файла.
///
/// # Почему сторож по тексту разметки
///
/// Проверить это можно только установкой, а установка требует прав
/// администратора и живёт минутами — в наборе такому места нет. Здесь стоит то,
/// что удерживает от повторения: кавычка сразу после свойства каталога.
void main() {
  final wxs = File('installer/windows/TelePOS.wxs');

  test('разметка на месте', () {
    expect(
      wxs.existsSync(),
      isTrue,
      reason: 'сторож читает ${wxs.path} — без него он ничего не сторожит',
    );
  });

  test('ни один аргумент не заканчивается свойством каталога в кавычках', () {
    final source = wxs.readAsStringSync();

    // Свойства каталога MSI — те, что раскрываются с завершающей косой.
    // `&quot;` — это и есть закрывающая кавычка в атрибуте XML.
    final offenders = <String>[
      for (final property in const [
        'INSTALLFOLDER',
        'AppMenuFolder',
        'DesktopFolder',
        'ProgramFiles64Folder',
      ])
        if (source.contains('[$property]&quot;')) property,
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'аргумент вида -Ключ "[${offenders.isEmpty ? 'КАТАЛОГ' : offenders.first}]" '
          'доедет до программы со шальной кавычкой: завершающая обратная косая '
          'экранирует закрывающую. Так установщик не ставился вовсе — 1722, '
          'затем 1603 и откат. Каталог скрипту не нужен: он лежит в '
          r'INSTALLFOLDER и знает его как $PSScriptRoot',
    );
  });

  test('тихая установка без прав отказывает сразу, а не откатом', () {
    // Измерено 2026-08-06: `msiexec /i … /qn` без повышения доходил до
    // RemoveExistingProducts, получал 1730 и откатывал уже разложенные файлы —
    // 1603 без единого слова про права. Причём только там, где прежняя версия
    // уже стояла: на чистой машине тот же запуск отказывает внятным 1925.
    // Заказчик ставит версию поверх версии, то есть попадает во второй случай.
    final source = wxs.readAsStringSync();

    expect(
      source,
      contains('Condition="Privileged OR UILevel &gt; 2"'),
      reason:
          'без этого условия тихая установка без повышения снова отказывает '
          'откатом в середине, а не отказом в начале',
    );

    // Условие обязано пропускать НЕтихую установку: при двойном щелчке
    // (UILevel = 5) прав на этом шаге ещё нет — их даёт UAC позже, — и
    // проверка одного лишь `Privileged` запретила бы обычную установку всем.
    final privilegedOnly = RegExp(r'Condition="Privileged"');
    expect(
      privilegedOnly.hasMatch(source),
      isFalse,
      reason:
          'одного Privileged мало: при обычном двойном щелчке на этом шаге '
          'прав ещё нет, и установка стала бы невозможна вовсе',
    );
  });

  test(r'trust.ps1 не берёт $PSScriptRoot значением параметра', () {
    // Второй дефект той же установки, найденный сразу за первым: при запуске
    // через `powershell.exe -File` — а установщик зовёт именно так —
    // $PSScriptRoot в ЗНАЧЕНИИ ПАРАМЕТРА пуст. `Join-Path` на пустой строке
    // бросает, действие возвращает 1, установка откатывается целиком. При
    // запуске через `& <скрипт>` переменная заполнена, поэтому проверка руками
    // из оболочки проходила, а установка падала — ровно тот случай, когда
    // «работает у нас» и «работает у заказчика» расходятся.
    final script = File('installer/windows/trust.ps1');
    expect(script.existsSync(), isTrue);

    expect(
      script.readAsStringSync(),
      isNot(contains(r'$InstallDir = $PSScriptRoot')),
      reason:
          r'$PSScriptRoot в значении параметра пуст под -File; разбирать его '
          'надо в теле скрипта',
    );
    expect(
      script.readAsStringSync(),
      contains(r'if (-not $InstallDir) {'),
      reason: 'иначе каталог установки не разберётся ни из чего',
    );
  });

  test('trust.ps1 снимает шальную кавычку, даже если её пришлют', () {
    // Вторая половина защиты: следующий, кто передаст путь из MSI, наступит на
    // то же самое, и отказывать ему откатом установки без объяснения незачем.
    final script = File('installer/windows/trust.ps1');
    expect(script.existsSync(), isTrue);
    expect(
      script.readAsStringSync(),
      contains(r"""$InstallDir = $InstallDir.TrimEnd('"')"""),
      reason: 'без этого шальная кавычка снова стоила бы целой установки',
    );
  });
}
