import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Browser stand-ins for the handful of local-file operations the UI performs.
///
/// A web build has no filesystem. What the file and image pickers hand back is
/// a `blob:` URL, which the network image loader can render and fetch, so the
/// paths flowing through the UI keep working without every call site learning
/// that it is on the web.

/// A blob URL is only ever produced by a picker, so if we hold one it exists.
bool localFileExists(String path) => path.isNotEmpty;

/// Not knowable without fetching the blob; callers use this for display only.
int localFileLength(String path) => 0;

Future<Uint8List> readLocalFile(String path) async {
  throw UnsupportedError(
    'Reading local files is not available in a web build ($path). '
    'Use the bytes the picker returned instead.',
  );
}

Future<void> writeLocalFile(String path, List<int> bytes) async {
  throw UnsupportedError(
    'Writing local files is not available in a web build ($path). '
    'Offer the bytes as a download instead.',
  );
}

Future<String> readLocalString(String path) async {
  throw UnsupportedError(
    'Reading local files is not available in a web build ($path). '
    'Use the bytes the picker returned instead.',
  );
}

Future<void> writeLocalString(String path, String contents) async {
  throw UnsupportedError(
    'Writing local files is not available in a web build ($path). '
    'Offer the text as a download instead.',
  );
}

Future<void> deleteLocalFile(String path) async {
  // Nothing is persisted, so there is nothing to remove.
}

Widget localImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.network(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
