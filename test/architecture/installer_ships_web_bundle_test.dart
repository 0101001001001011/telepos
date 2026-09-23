@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/web_bundle.dart';

/// Сторож последнего звена браузерного терминала.
///
/// # Что было
///
/// Установщик не клал бандл ВОВСЕ: в `TelePOS.wxs` не было ни слова про
/// `build\web`, а `flutter build web -t lib/web/main_web.dart` выполнялся только
/// в CI, откуда его вывод никуда не ехал. Установленная касса поднимала сервер,
/// выписывала корень, открывала порт — и на запрос страницы отвечала `Frontend
/// bundle not found at build/web`, называя каталог, которого у неё нет и быть не
/// может. Всё остальное работало; терминал не работал целиком.
///
/// # Почему сторож по исходному тексту
///
/// Проверить это поведением под `flutter test` нечем: доказательство — MSI,
/// установленный на настоящую машину. Такая проверка живёт минутами и требует
/// прав администратора, поэтому её гоняют руками (см. `docs/internal/windows-installer.md`),
/// а здесь стоит то, что удерживает три пары имён от расхождения. Именно
/// расхождение имён — самый дешёвый способ вернуть ровно тот же отказ: бандл
/// собран, установщик его положил, а касса ищет в другом месте.
void main() {
  final wxs = File('installer/windows/TelePOS.wxs');
  final script = File('tools/build_windows_installer.ps1');
  final resolver = File('lib/backend/web_bundle.dart');

  test('все три файла на месте', () {
    // Иначе каждая проверка ниже стала бы зелёной проверкой пустоты.
    for (final file in [wxs, script, resolver]) {
      expect(
        file.existsSync(),
        isTrue,
        reason: 'сторож читает ${file.path} — без него он ничего не сторожит',
      );
    }
  });

  group('установщик кладёт бандл', () {
    test('каталог объявлен, наполнен и включён в состав', () {
      final source = wxs.readAsStringSync();

      expect(
        source,
        contains('<Files Include="\$(WebDir)\\**" />'),
        reason:
            'без этого установщик снова соберётся зелёным и поставит кассу '
            'без страницы',
      );
      expect(
        source,
        contains('<ComponentGroup Id="WebBundle" Directory="WebFolder">'),
        reason: 'бандл обязан лечь в отдельный каталог, а не поверх сборки',
      );
      // Объявленная и не включённая в Feature группа компонентов не попадает в
      // MSI, и wix об этом молчит: получился бы установщик, который выглядит
      // исправленным и ставит ровно то же, что и раньше.
      expect(
        source,
        contains('<ComponentGroupRef Id="WebBundle" />'),
        reason:
            'группа компонентов, не включённая в Feature, в установщик не '
            'попадает — а wix об этом не скажет ни слова',
      );
    });

    test('сборка отказывает до упаковщика, если бандла нет', () {
      final source = script.readAsStringSync();

      expect(
        source,
        contains('Invoke-FlutterWebBuild'),
        reason:
            'бандл обязан собираться здесь: пока он собирался только в CI, его '
            'вывод никуда не ехал',
      );
      expect(
        source,
        contains('flutter build web -t lib/web/main_web.dart'),
        reason:
            'точка входа своя: lib/main.dart тянет dart:ffi и в браузере не '
            'собирается вовсе',
      );

      // Порядок важен так же, как у нативных библиотек: проверка ПОСЛЕ вызова
      // wix означала бы готовый MSI с неработоспособной кассой внутри.
      final check = source.indexOf('Assert-WebBundle');
      final wixBuild = source.indexOf('& \$wix build');
      expect(check, greaterThan(-1), reason: 'проверки состава бандла нет');
      expect(wixBuild, greaterThan(-1), reason: 'вызова wix build нет');
      expect(
        check,
        lessThan(wixBuild),
        reason:
            'проверять состав после упаковки бессмысленно: MSI уже собран, и '
            'отказ проявится только у заказчика',
      );

      expect(
        source,
        contains(r'-d "WebDir=$WebDir"'),
        reason: 'иначе разметка не узнает, откуда брать бандл',
      );
    });
  });

  group('имена не расходятся', () {
    test('касса ищет там же, куда кладёт установщик', () {
      // Каталог `web` рядом с telepos.exe. Переименовать в одном месте и
      // забыть про второе — самый дешёвый способ вернуть исходный отказ.
      expect(
        wxs.readAsStringSync(),
        contains('<Directory Id="WebFolder" Name="web" />'),
        reason: 'установщик обязан класть бандл в каталог с этим именем',
      );
      expect(
        resolver.readAsStringSync(),
        contains("_join(executableDirectory, 'web')"),
        reason:
            'касса обязана искать бандл в каталоге `web` рядом с исполняемым '
            'файлом — там, куда его кладёт установщик',
      );
    });

    test('признак бандла у сборки и у кассы — один список', () {
      final declared = RegExp(
        r"\$RequiredWebFiles\s*=\s*@\(([^)]*)\)",
      ).firstMatch(script.readAsStringSync());
      expect(
        declared,
        isNotNull,
        reason: 'в сборке установщика нет списка обязательных файлов бандла',
      );

      final fromScript = RegExp(
        "'([^']+)'",
      ).allMatches(declared!.group(1)!).map((m) => m.group(1)!).toList();

      expect(
        fromScript,
        kWebBundleMarkers,
        reason:
            'разойдись эти два списка — установщик соберёт то, что касса не '
            'признает бандлом, и терминал получит отказ на исправленной сборке',
      );
    });
  });
}
