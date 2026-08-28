import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

bool localFileExists(String path) => File(path).existsSync();

int localFileLength(String path) => File(path).lengthSync();

Future<Uint8List> readLocalFile(String path) => File(path).readAsBytes();

Future<String> readLocalString(String path) => File(path).readAsString();

Future<void> writeLocalString(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents, flush: true);
}

Future<void> writeLocalFile(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

Future<void> deleteLocalFile(String path) async {
  final file = File(path);
  if (file.existsSync()) await file.delete();
}

/// Renders an image the user picked from disk.
Widget localImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
