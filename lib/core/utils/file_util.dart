import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

class FileUtil {
  FileUtil._();

  static Future<String?> readString(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  static Future<dynamic> readJson(String path) async {
    final content = await readString(path);
    if (content != null) {
      return jsonDecode(content);
    }
    return null;
  }

  static Future<Uint8List?> readBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<String>?> readLines(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsLines();
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> writeString(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> writeJson(
    String path,
    dynamic data, {
    bool pretty = false,
  }) async {
    final encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return writeString(path, encoder.convert(data));
  }

  static Future<bool> writeBytes(String path, Uint8List bytes) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> appendString(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content, mode: FileMode.append);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> copy(String from, String to) async {
    try {
      final source = File(from);
      if (await source.exists()) {
        await File(to).parent.create(recursive: true);
        await source.copy(to);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> move(String from, String to) async {
    try {
      final source = File(from);
      if (await source.exists()) {
        await File(to).parent.create(recursive: true);
        await source.rename(to);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> exists(String path) async {
    return await File(path).exists();
  }

  static Future<int?> size(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return null;
  }

  static Future<DateTime?> lastModified(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.lastModified();
      }
    } catch (_) {}
    return null;
  }

  static String getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  static String getFileName(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    if (lastSep == -1) return path;
    return path.substring(lastSep + 1);
  }

  static String getFileNameWithoutExtension(String path) {
    final name = getFileName(path);
    final lastDot = name.lastIndexOf('.');
    if (lastDot == -1) return name;
    return name.substring(0, lastDot);
  }

  static String getDirectory(String path) {
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    if (lastSep == -1) return '';
    return path.substring(0, lastSep);
  }

  static String makeUnique(String path) {
    final dir = getDirectory(path);
    final name = getFileNameWithoutExtension(path);
    final ext = getExtension(path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$dir${Platform.pathSeparator}${name}_$timestamp.$ext';
  }

  static Future<String?> createBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final backupPath = makeUnique(path);
        await file.copy(backupPath);
        return backupPath;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> md5Hash(String path) async {
    try {
      final bytes = await readBytes(path);
      if (bytes != null) {
        final digest = crypto.md5.convert(bytes);
        return digest.toString();
      }
    } catch (_) {}
    return null;
  }
}
