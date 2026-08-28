import 'dart:async';

import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class MediaService {
  final TdLibClient _client;
  final TdLibLogger _logger;

  MediaService({required TdLibClient client, required TdLibLogger logger})
    : _client = client,
      _logger = logger;

  Future<void> sendPhoto(int chatId, String filePath, {String? caption}) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessagePhoto',
        'photo': {'@type': 'inputFileLocal', 'path': filePath},
        'caption': caption != null
            ? {'@type': 'formattedText', 'text': caption}
            : null,
      },
    });

    _logger.logConnection('Photo sent to chat=$chatId');
  }

  Future<void> sendDocument(
    int chatId,
    String filePath, {
    String? caption,
    String? fileName,
  }) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputFileLocal', 'path': filePath},
        'caption': caption != null
            ? {'@type': 'formattedText', 'text': caption}
            : null,
      },
    });

    _logger.logConnection('Document sent to chat=$chatId');
  }

  Future<String> downloadFile(int fileId) async {
    final result = await _client.sendSync({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 1,
      'synchronous': true,
    });

    final localPath = result['local']?['path'] as String? ?? '';
    _logger.logConnection('File downloaded: $localPath');
    return localPath;
  }

  Future<void> sendDataAsFile(
    int chatId,
    String data,
    String fileName, {
    String? caption,
  }) async {
    final tempResult = await _client.sendSync({
      '@type': 'preliminaryUploadFile',
      'file': {
        '@type': 'inputFileGenerated',
        'original_path': fileName,
        'conversion': data,
        'expected_size': data.length,
      },
      'file_type': {'@type': 'fileTypeDocument'},
      'priority': 1,
    });

    await _client.sendSync({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageDocument',
        'document': tempResult,
        'caption': caption != null
            ? {'@type': 'formattedText', 'text': caption}
            : null,
      },
    });
  }

  Future<void> cancelDownload(int fileId) async {
    await _client.send({
      '@type': 'cancelDownloadFile',
      'file_id': fileId,
      'only_if_pending': false,
    });
  }

  Future<void> sendLocation(
    int chatId,
    double latitude,
    double longitude, {
    int? livePeriod,
  }) async {
    await _client.send({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageLocation',
        'location': {
          '@type': 'location',
          'latitude': latitude,
          'longitude': longitude,
        },
        if (livePeriod != null) 'live_period': livePeriod,
      },
    });

    _logger.logConnection(
      'Location sent to chat=$chatId: $latitude,$longitude',
    );
  }
}
