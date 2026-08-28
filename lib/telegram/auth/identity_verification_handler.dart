import 'dart:async';

import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class IdentityVerificationHandler {
  final TdLibClient _client;
  final TdLibLogger _logger;

  DocumentVerificationStatus _status = DocumentVerificationStatus.pending;

  IdentityVerificationHandler({
    required TdLibClient client,
    required TdLibLogger logger,
  }) : _client = client,
       _logger = logger;

  DocumentVerificationStatus get status => _status;

  Future<void> submitDocuments({
    required List<String> documentPaths,
    required List<IdentityDocumentType> documentTypes,
  }) async {
    _logger.logAuthState(
      'Submitting ${documentPaths.length} documents for verification',
    );

    _status = DocumentVerificationStatus.submitted;

    for (var i = 0; i < documentPaths.length; i++) {
      final path = documentPaths[i];
      final type = i < documentTypes.length
          ? documentTypes[i]
          : IdentityDocumentType.identityCard;

      await _uploadDocument(path, type);
    }

    _status = DocumentVerificationStatus.inReview;
    _logger.logAuthState('Documents submitted for review');
  }

  Future<DocumentVerificationStatus> checkStatus() async {
    _logger.logAuthState('Checking verification status');

    try {
      final result = await _client.sendSync({
        '@type': 'getPassportAuthorizationForm',
        'bot_user_id': 0,
        'scope': '',
        'public_key': '',
        'nonce': '',
      });

      final errors = result['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        _status = DocumentVerificationStatus.rejected;
      }

      return _status;
    } catch (e) {
      _logger.logError('checkStatus', e);
      return _status;
    }
  }

  Future<List<IdentityDocumentType>> getRequiredDocuments() async {
    return [
      IdentityDocumentType.identityCard,
      IdentityDocumentType.selfieWithDocument,
    ];
  }

  bool validateIIN(String iin) {
    if (iin.length != 12) return false;
    if (!RegExp(r'^\d{12}$').hasMatch(iin)) return false;

    final weights1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    final weights2 = [3, 4, 5, 6, 7, 8, 9, 10, 11, 1, 2];

    final digits = iin.split('').map(int.parse).toList();

    var sum = 0;
    for (var i = 0; i < 11; i++) {
      sum += digits[i] * weights1[i];
    }

    var check = sum % 11;
    if (check == 10) {
      sum = 0;
      for (var i = 0; i < 11; i++) {
        sum += digits[i] * weights2[i];
      }
      check = sum % 11;
      if (check == 10) return false;
    }

    return check == digits[11];
  }

  bool validateBIN(String bin) {
    return validateIIN(bin);
  }

  bool validateINN(String inn) {
    if (inn.length != 10 && inn.length != 12) return false;
    if (!RegExp(r'^\d+$').hasMatch(inn)) return false;

    final digits = inn.split('').map(int.parse).toList();

    if (inn.length == 10) {
      final weights = [2, 4, 10, 3, 5, 9, 4, 6, 8];
      var sum = 0;
      for (var i = 0; i < 9; i++) {
        sum += digits[i] * weights[i];
      }
      return (sum % 11) % 10 == digits[9];
    } else {
      final weights1 = [7, 2, 4, 10, 3, 5, 9, 4, 6, 8];
      final weights2 = [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8];

      var sum1 = 0;
      for (var i = 0; i < 10; i++) {
        sum1 += digits[i] * weights1[i];
      }
      if ((sum1 % 11) % 10 != digits[10]) return false;

      var sum2 = 0;
      for (var i = 0; i < 11; i++) {
        sum2 += digits[i] * weights2[i];
      }
      return (sum2 % 11) % 10 == digits[11];
    }
  }

  Future<void> _uploadDocument(
    String filePath,
    IdentityDocumentType type,
  ) async {
    final passportType = _mapToPassportType(type);

    await _client.send({
      '@type': 'sendPassportAuthorizationForm',
      'authorization_form_id': 0,
      'types': [
        {'@type': passportType},
      ],
    });
  }

  String _mapToPassportType(IdentityDocumentType type) {
    switch (type) {
      case IdentityDocumentType.passport:
        return 'passportElementTypePassport';
      case IdentityDocumentType.identityCard:
        return 'passportElementTypeIdentityCard';
      case IdentityDocumentType.driverLicense:
        return 'passportElementTypeDriverLicense';
      case IdentityDocumentType.selfieWithDocument:
        return 'passportElementTypePersonalDetails';
      case IdentityDocumentType.facePhoto:
        return 'passportElementTypePersonalDetails';
      case IdentityDocumentType.taxId:
        return 'passportElementTypePersonalDetails';
    }
  }
}
