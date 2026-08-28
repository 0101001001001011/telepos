import 'dart:convert';
import 'dart:io';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';

class DataPacker {
  final DataEncryptionService _encryption;
  final TdLibLogger _logger;

  static const _compressionThreshold = 256;

  DataPacker({
    required DataEncryptionService encryption,
    required TdLibLogger logger,
  }) : _encryption = encryption,
       _logger = logger;

  Future<PackedData> pack(
    dynamic data,
    String sessionId, {
    bool compress = true,
    bool encrypt = true,
  }) async {
    final jsonString = jsonEncode(data);
    final originalSize = utf8.encode(jsonString).length;

    _logger.logSync('Packing: original size = $originalSize bytes');

    String payload = jsonString;
    bool isCompressed = false;

    if (compress && originalSize > _compressionThreshold) {
      final compressed = gzip.encode(utf8.encode(jsonString));
      payload = base64Encode(compressed);
      isCompressed = true;

      _logger.logSync(
        'Compressed: $originalSize → ${compressed.length} bytes '
        '(${(compressed.length / originalSize * 100).toStringAsFixed(1)}%)',
      );
    }

    bool isEncrypted = false;
    if (encrypt) {
      payload = await _encryption.encryptPayload(payload, sessionId);
      isEncrypted = true;
      _logger.logSync('Encrypted payload');
    }

    final checksum = _encryption.computeChecksum(jsonString);

    return PackedData(
      payload: payload,
      checksum: checksum,
      originalSize: originalSize,
      packedSize: payload.length,
      isCompressed: isCompressed,
      isEncrypted: isEncrypted,
    );
  }

  String computeChecksum(dynamic data) {
    final jsonString = jsonEncode(data);
    return _encryption.computeChecksum(jsonString);
  }
}

class PackedData {
  final String payload;
  final String checksum;
  final int originalSize;
  final int packedSize;
  final bool isCompressed;
  final bool isEncrypted;

  PackedData({
    required this.payload,
    required this.checksum,
    required this.originalSize,
    required this.packedSize,
    required this.isCompressed,
    required this.isEncrypted,
  });

  double get compressionRatio =>
      originalSize > 0 ? packedSize / originalSize : 1.0;
}
