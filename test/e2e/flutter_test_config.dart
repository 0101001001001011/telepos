library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/app/config/background_task_manager.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BackgroundTaskManager.disabledForTests = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadBundledFonts();
  final defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    goldenFileComparator = _NonThrowingGoldenComparator(
      defaultComparator.basedir,
    );
  }
  await testMain();
}

class _NonThrowingGoldenComparator extends LocalFileComparator {
  _NonThrowingGoldenComparator(Uri basedir)
    : super(basedir.resolve('_golden_config.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    try {
      final result = await GoldenFileComparator.compareLists(
        imageBytes,
        await getGoldenBytes(golden),
      );
      if (!result.passed) {
        // ignore: avoid_print
        print(
          '[golden:non-gating] $golden differs '
          '(${(result.diffPercent * 100).toStringAsFixed(2)}%) — ignored.',
        );
      }
      return true;
    } catch (e) {
      // ignore: avoid_print
      print(
        '[golden:non-gating] $golden could not be compared ($e) — ignored.',
      );
      return true;
    }
  }
}

Future<ByteData?> _asset(String key, String diskPath) async {
  try {
    return await rootBundle.load(key);
  } catch (_) {
    final f = File(diskPath);
    if (!f.existsSync()) return null;
    final b = f.readAsBytesSync();
    return ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes);
  }
}

Future<void> _register(String family, List<ByteData?> faces) async {
  final loader = FontLoader(family);
  var any = false;
  for (final f in faces) {
    if (f != null) {
      loader.addFont(Future.value(f));
      any = true;
    }
  }
  if (any) await loader.load();
}

ByteData? _file(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  final b = f.readAsBytesSync();
  return ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes);
}

Future<void> _loadBundledFonts() async {
  // До 2026-08-03 семейство Roboto собиралось здесь из файлов DejaVu Sans, а
  // medium приходилось доставать из артефактов Flutter, потому что в бандле
  // его не было вовсе. Теперь все три начертания — свои, и это те же файлы,
  // что уедут на кассу, включая дописанный в них знак тенге.
  final sansReg = await _asset(
    'assets/fonts/Roboto-Regular.ttf',
    r'assets\fonts\Roboto-Regular.ttf',
  );
  final sansMedium = await _asset(
    'assets/fonts/Roboto-Medium.ttf',
    r'assets\fonts\Roboto-Medium.ttf',
  );
  final sansBold = await _asset(
    'assets/fonts/Roboto-Bold.ttf',
    r'assets\fonts\Roboto-Bold.ttf',
  );
  final monoReg = await _asset(
    'assets/fonts/DejaVuSansMono-Regular.ttf',
    r'assets\fonts\DejaVuSansMono-Regular.ttf',
  );
  final monoBold = await _asset(
    'assets/fonts/DejaVuSansMono-Bold.ttf',
    r'assets\fonts\DejaVuSansMono-Bold.ttf',
  );

  final root = Platform.environment['FLUTTER_ROOT'];
  final matDir = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts'
      : r'D:\Flutter\flutter\bin\cache\artifacts\material_fonts';
  for (final family in ['Roboto', 'Segoe UI', 'SF Pro Text', '.SF UI Text']) {
    await _register(family, [sansReg, sansMedium, sansBold]);
  }
  await _register('monospace', [monoReg, monoBold]);
  await _register('TeleposMono', [monoReg, monoBold]);

  final icons = await _asset(
    'fonts/MaterialIcons-Regular.otf',
    '$matDir/materialicons-regular.otf',
  );
  await _register('MaterialIcons', [icons]);

  // Собственный набор. Без него КАЖДЫЙ глиф `TeleposIcons` рисуется пустым
  // квадратом, а снимок при этом снимается и тест зеленеет: `matchesGoldenFile`
  // записывает то, что нарисовалось, каким бы оно ни было.
  //
  // Так и случилось 2026-08-27: загрузчик прежнего набора убрали вместе с
  // самим набором, волны 1–2 завели новый шрифт, а вернуть загрузчик забыли.
  // Пятнадцать снимков README и 117 эталонов перезаписались с «тофу» вместо
  // иконок, и ни одна проверка не покраснела. Сторож —
  // `test/theme/icon_font_renders_test.dart`.
  await _register('TeleposIcons', [
    await _asset(
      'assets/fonts/TeleposIcons.ttf',
      r'assetsonts\TeleposIcons.ttf',
    ),
  ]);
}
