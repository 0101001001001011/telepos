import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/web_bundle.dart';

/// Где установленная касса берёт страницу терминала.
///
/// Проверяется без единого настоящего каталога: [resolveWebBundle] принимает
/// проверку существования файла аргументом именно затем. Иначе единственным
/// способом убедиться в правильности поиска осталась бы установленная касса, а
/// «работает у нас» и «работает у заказчика» в этом проекте уже расходились.
void main() {
  /// Диск, на котором «есть» ровно перечисленные каталоги-бандлы.
  bool Function(String) disk(List<String> bundleDirectories) {
    final files = {
      for (final dir in bundleDirectories)
        for (final marker in kWebBundleMarkers) '$dir\\$marker',
    };
    return (path) => files.contains(path.replaceAll('/', r'\'));
  }

  group('установленная касса', () {
    test('находит бандл рядом с исполняемым файлом, без аргументов', () {
      // Ровно тот случай, ради которого всё это существует: ярлык из меню
      // «Пуск» аргументов не несёт, рабочий каталог — каталог установки.
      final bundle = resolveWebBundle(
        executableDirectory: r'C:\Program Files\TelePOS',
        workingDirectory: r'C:\Program Files\TelePOS',
        fileExists: disk([r'C:\Program Files\TelePOS\web']),
      );

      expect(bundle, isA<WebBundleFound>());
      expect(
        (bundle as WebBundleFound).directory,
        r'C:\Program Files\TelePOS\web',
      );
      expect(bundle.origin, WebBundleOrigin.besideExecutable);
    });

    test('без бандла отказывает значением и называет ВСЕ просмотренные места', () {
      // И144. Прежняя строка называла один `build/web` — каталог, которого на
      // установленной кассе нет и быть не может.
      final bundle = resolveWebBundle(
        executableDirectory: r'C:\Program Files\TelePOS',
        workingDirectory: r'C:\Program Files\TelePOS',
        fileExists: disk(const []),
      );

      expect(bundle, isA<WebBundleMissing>());
      final missing = bundle as WebBundleMissing;
      expect(missing.searched, [
        r'C:\Program Files\TelePOS\web',
        r'C:\Program Files\TelePOS\build\web',
      ]);
      expect(missing.describe, contains(r'C:\Program Files\TelePOS\web'));
      expect(
        missing.describe,
        contains('flutter build web'),
        reason: 'отказ обязан говорить, чем его закрыть',
      );
    });
  });

  group('дерево разработчика', () {
    test('касса из корня дерева берёт build/web', () {
      // Рядом с `telepos.exe` в build\windows\...\Release бандла нет — там его
      // и не должно быть до установки.
      final bundle = resolveWebBundle(
        executableDirectory: r'D:\repo\build\windows\x64\runner\Release',
        workingDirectory: r'D:\repo',
        fileExists: disk([r'D:\repo\build\web']),
      );

      expect(bundle, isA<WebBundleFound>());
      expect((bundle as WebBundleFound).directory, r'D:\repo\build\web');
      expect(bundle.origin, WebBundleOrigin.workingDirectory);
    });

    test('--web-dir бьёт бандл, лежащий рядом с исполняемым файлом', () {
      // Оба места существуют. Взять не тот — значит молча отдать отлаживающему
      // чужую страницу.
      final bundle = resolveWebBundle(
        argument: r'D:\scratch\web',
        executableDirectory: r'C:\Program Files\TelePOS',
        workingDirectory: r'D:\repo',
        fileExists: disk([
          r'D:\scratch\web',
          r'C:\Program Files\TelePOS\web',
          r'D:\repo\build\web',
        ]),
      );

      expect((bundle as WebBundleFound).directory, r'D:\scratch\web');
      expect(bundle.origin, WebBundleOrigin.argument);
    });

    test('TELEPOS_WEB_DIR бьёт поиск, но уступает --web-dir', () {
      final baked = resolveWebBundle(
        define: r'D:\baked\web',
        executableDirectory: r'C:\Program Files\TelePOS',
        fileExists: disk([r'D:\baked\web', r'C:\Program Files\TelePOS\web']),
      );
      expect((baked as WebBundleFound).origin, WebBundleOrigin.define);

      final argued = resolveWebBundle(
        argument: r'D:\scratch\web',
        define: r'D:\baked\web',
        executableDirectory: r'C:\Program Files\TelePOS',
        fileExists: disk([r'D:\scratch\web', r'D:\baked\web']),
      );
      expect((argued as WebBundleFound).origin, WebBundleOrigin.argument);
    });

    test('опечатка в --web-dir отказывает, а не откатывается на поиск', () {
      // Молчаливый откат отдал бы УСТАНОВЛЕННЫЙ бандл вместо отлаживаемого, и
      // правка выглядела бы как непроходящая. Ищут такое часами и не там.
      final bundle = resolveWebBundle(
        argument: r'D:\scratc\web',
        executableDirectory: r'C:\Program Files\TelePOS',
        workingDirectory: r'D:\repo',
        fileExists: disk([
          r'C:\Program Files\TelePOS\web',
          r'D:\repo\build\web',
        ]),
      );

      expect(bundle, isA<WebBundleMissing>());
      expect((bundle as WebBundleMissing).explicit, r'D:\scratc\web');
      expect(bundle.searched, [r'D:\scratc\web']);
      expect(
        bundle.describe,
        isNot(contains('Program Files')),
        reason: 'названный путь не найден — про другие места речи нет',
      );
    });
  });

  group('признак бандла', () {
    test('каталога с одним index.html недостаточно', () {
      // Так выглядит `build/web` после неудавшейся сборки. Прежняя проверка
      // (`Directory.existsSync`) считала это бандлом, и браузер получал белый
      // экран и 404 на каждый файл — без единого слова о причине.
      expect(
        isWebBundle(
          r'D:\repo\build\web',
          fileExists: (p) => p.endsWith('index.html'),
        ),
        isFalse,
      );
    });

    test('пустой каталог бандлом не считается', () {
      final bundle = resolveWebBundle(
        executableDirectory: r'C:\Program Files\TelePOS',
        fileExists: (_) => false,
      );
      expect(bundle, isA<WebBundleMissing>());
    });
  });
}
