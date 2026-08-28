library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRealFonts();
  await testMain();
}

String? _materialFontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String?>[
    if (root != null && root.isNotEmpty)
      '$root/bin/cache/artifacts/material_fonts',
    _deriveFromExecutable(),
    r'D:\Flutter\flutter\bin\cache\artifacts\material_fonts',
  ].whereType<String>().toList();

  for (final c in candidates) {
    if (Directory(c).existsSync()) return c;
  }
  return null;
}

String? _deriveFromExecutable() {
  try {
    final exe = Platform.resolvedExecutable;
    final marker = '${Platform.pathSeparator}bin${Platform.pathSeparator}cache';
    final idx = exe.indexOf(marker);
    if (idx == -1) return null;
    final cacheDir = exe.substring(0, idx + marker.length);
    return '$cacheDir${Platform.pathSeparator}artifacts'
        '${Platform.pathSeparator}material_fonts';
  } catch (_) {
    return null;
  }
}

Future<void> _loadRealFonts() async {
  final dir = _materialFontsDir();

  ByteData? readBytes(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    final b = f.readAsBytesSync();
    return ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes);
  }

  ByteData? materialFont(String file) =>
      dir == null ? null : readBytes('$dir${Platform.pathSeparator}$file');

  ByteData? firstOf(List<String> paths) {
    for (final p in paths) {
      final b = readBytes(p);
      if (b != null) return b;
    }
    return null;
  }

  // Шрифты берутся из бандла приложения — те же файлы, что уедут на кассу.
  //
  // Раньше здесь первым стоял Arial из C:\Windows\Fonts, а medium и bold были
  // ОДНИМ И ТЕМ ЖЕ файлом arialbd.ttf. Значит, голдены снимались гарнитурой,
  // которой в приложении нет, а medium и bold в них были неразличимы по
  // построению — поэтому отсутствие 500-го начертания в теме и не всплывало
  // годами.
  // Inter — вариативный: один файл несёт всю ось wght, поэтому регистрируется
  // однократно, а вес выбирает движок.
  final regular =
      firstOf(['assets/fonts/Roboto-Regular.ttf']) ??
      materialFont('roboto-regular.ttf');
  final medium =
      firstOf(['assets/fonts/Roboto-Medium.ttf']) ??
      materialFont('roboto-medium.ttf');
  final bold =
      firstOf(['assets/fonts/Roboto-Bold.ttf']) ??
      materialFont('roboto-bold.ttf');
  final mono = firstOf(['assets/fonts/DejaVuSansMono-Regular.ttf']);
  final monoBold = firstOf(['assets/fonts/DejaVuSansMono-Bold.ttf']);
  final icons = materialFont('materialicons-regular.otf');

  const textFamilies = <String>[
    'Roboto',
    'Segoe UI',
    'SF Pro Text',
    'SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    '.AppleSystemUIFont',
  ];

  for (final family in textFamilies) {
    final loader = FontLoader(family);
    if (regular != null) loader.addFont(Future.value(regular));
    if (medium != null) loader.addFont(Future.value(medium));
    if (bold != null) loader.addFont(Future.value(bold));
    await loader.load();
  }

  // Штрихкоды и всё, что набрано моноширинным, иначе рисуются подстановкой и
  // расходятся с приложением.
  if (mono != null) {
    for (final family in ['TeleposMono', 'monospace']) {
      final loader = FontLoader(family)..addFont(Future.value(mono));
      if (monoBold != null) loader.addFont(Future.value(monoBold));
      await loader.load();
    }
  }

  if (icons != null) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(icons));
    await iconLoader.load();
  }

  // Собственный набор — 33 глифа навигации и действий. Без этой загрузки
  // каждый из них рисуется пустым квадратом, а эталон всё равно снимается:
  // `matchesGoldenFile` записывает то, что нарисовалось.
  //
  // Прежний набор из 21 иконки был удалён 2026-08-27 как мёртвый, и вместе с
  // ним отсюда убрали загрузчик. Волны 1–2 завели новый шрифт, загрузчик не
  // вернули — 117 эталонов и 15 снимков README перезаписались с «тофу», и ни
  // одна проверка не покраснела. Сторож на этот случай —
  // `test/theme/icon_font_renders_test.dart`: он рисует три разных глифа и
  // требует, чтобы они отличались друг от друга. Без шрифта все три
  // одинаковы.
  final teleposIcons = firstOf(['assets/fonts/TeleposIcons.ttf']);
  if (teleposIcons != null) {
    final loader = FontLoader('TeleposIcons')
      ..addFont(Future.value(teleposIcons));
    await loader.load();
  }
}

// ЭМОДЗИ ЗДЕСЬ НЕ ЗАГРУЖАЮТСЯ, И ЭТО НЕ УПУЩЕНИЕ.
//
// На снимках мастера флаги стран выглядят пустыми квадратами. Это артефакт
// испытательного движка: своих шрифтов у него нет вовсе, есть только те, что
// перечислены выше, а Roboto и TeleposMono эмодзи не содержат. Пустой квадрат
// появляется там, где на него никто не смотрит.
//
// Измерено 2026-08-04, чтобы следующий не принял это за дефект:
//
//   Chrome (веб)   — флаги в цвете, браузер подставляет свой шрифт;
//   Linux-прибор   — флаги в цвете: fonts-noto-color-emoji стоит жёсткой
//                    зависимостью в build/build-deb.sh и provision-rpi5.sh
//                    репозитория telepos-os;
//   Android        — флаги в цвете, шрифт системный;
//   Windows        — НЕ флаг и НЕ квадрат, а буквы кода: «KZ», «RU», «US».
//                    Segoe UI Emoji содержит глифы региональных индикаторов,
//                    но лигатуры пары в флаг у него нет — Microsoft флаги не
//                    рисует намеренно. Проверено разбором GSUB и отрисовкой.
//
// Единственный ущербный случай — Windows, и там видно двухбуквенный код
// страны рядом с её названием. Тащить ради этого подмножество эмодзи-шрифта
// (≈140 КБ) пробовали и отказались: строка «Казахстан» и без флага
// однозначна.
