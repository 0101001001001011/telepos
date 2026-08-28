import 'dart:convert';
import 'dart:io';

import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';

class DataUnpacker {
  final DataEncryptionService _encryption;
  final TdLibLogger _logger;

  DataUnpacker({
    required DataEncryptionService encryption,
    required TdLibLogger logger,
  }) : _encryption = encryption,
       _logger = logger;

  Future<UnpackedData> unpack(
    String payload, {
    required String sessionId,
    required String checksum,
    bool isCompressed = true,
    bool isEncrypted = true,
  }) async {
    String data = payload;

    if (isEncrypted) {
      data = await _encryption.decryptPayload(data, sessionId);
      _logger.logSync('Decrypted payload');
    }

    if (isCompressed) {
      final compressed = base64Decode(data);
      final decompressed = gzip.decode(compressed);
      data = utf8.decode(decompressed);
      _logger.logSync(
        'Decompressed: ${compressed.length} → ${data.length} bytes',
      );
    }

    final actualChecksum = _encryption.computeChecksum(data);
    final isValid = actualChecksum == checksum;

    if (!isValid) {
      _logger.logError(
        'unpack',
        'Checksum mismatch: expected=$checksum, actual=$actualChecksum',
      );
    }

    final parsed = jsonDecode(data);

    return UnpackedData(
      data: parsed,
      isChecksumValid: isValid,
      originalChecksum: checksum,
      computedChecksum: actualChecksum,
    );
  }

  dynamic unpackLocal(String jsonString) {
    return jsonDecode(jsonString);
  }
}

class UnpackedData {
  final dynamic data;
  final bool isChecksumValid;
  final String originalChecksum;
  final String computedChecksum;

  UnpackedData({
    required this.data,
    required this.isChecksumValid,
    required this.originalChecksum,
    required this.computedChecksum,
  });

  Map<String, dynamic> get asMap => data as Map<String, dynamic>;

  List<dynamic> get asList => data as List<dynamic>;
}
