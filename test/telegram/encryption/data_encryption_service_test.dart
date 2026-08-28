import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';

class MockEncryptionKeyStore extends Mock implements EncryptionKeyStore {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

void main() {
  late DataEncryptionService service;
  late MockEncryptionKeyStore mockKeyStore;
  late MockTdLibLogger mockLogger;

  setUp(() {
    mockKeyStore = MockEncryptionKeyStore();
    mockLogger = MockTdLibLogger();
    service = DataEncryptionService(keyStore: mockKeyStore, logger: mockLogger);
  });

  group('DataEncryptionService', () {
    group('Key generation and storage', () {
      test(
        'should throw StateError when AES key is not found for encryption',
        () async {
          const sessionId = 'test-session-123';
          const payload = 'test payload';

          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenAnswer((_) async => null);

          expect(
            () => service.encryptPayload(payload, sessionId),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('No AES key found for session'),
              ),
            ),
          );
        },
      );

      test(
        'should throw StateError when AES key is not found for decryption',
        () async {
          const sessionId = 'test-session-123';
          const encryptedData = 'base64data';

          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenAnswer((_) async => null);

          expect(
            () => service.decryptPayload(encryptedData, sessionId),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('No AES key found for session'),
              ),
            ),
          );
        },
      );

      test('should use keyStore to load AES key during encryption', () async {
        const sessionId = 'test-session-456';
        const payload = 'Hello, World!';
        final aesKey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          aesKey[i] = i;
        }

        when(
          () => mockKeyStore.loadAesKey(sessionId),
        ).thenAnswer((_) async => aesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        await service.encryptPayload(payload, sessionId);

        verify(() => mockKeyStore.loadAesKey(sessionId)).called(1);
      });

      test('should use keyStore to load AES key during decryption', () async {
        const sessionId = 'test-session-789';
        final aesKey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          aesKey[i] = i;
        }

        when(
          () => mockKeyStore.loadAesKey(sessionId),
        ).thenAnswer((_) async => aesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        const payload = 'Test data';
        final encrypted = await service.encryptPayload(payload, sessionId);

        reset(mockKeyStore);
        when(
          () => mockKeyStore.loadAesKey(sessionId),
        ).thenAnswer((_) async => aesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        await service.decryptPayload(encrypted, sessionId);

        verify(() => mockKeyStore.loadAesKey(sessionId)).called(1);
      });
    });

    group('AES-256-GCM encryption/decryption', () {
      late Uint8List validAesKey;
      const testSessionId = 'aes-test-session';

      setUp(() {
        validAesKey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          validAesKey[i] = (i * 7 + 13) % 256;
        }

        when(
          () => mockKeyStore.loadAesKey(testSessionId),
        ).thenAnswer((_) async => validAesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);
      });

      test('should encrypt payload and return base64 string', () async {
        const payload = 'Secret message to encrypt';

        final encrypted = await service.encryptPayload(payload, testSessionId);

        expect(encrypted, isA<String>());
        expect(encrypted.isNotEmpty, isTrue);

        expect(() => base64Decode(encrypted), returnsNormally);
      });

      test(
        'should produce different ciphertext for same plaintext (due to random IV)',
        () async {
          const payload = 'Same message encrypted twice';

          final encrypted1 = await service.encryptPayload(
            payload,
            testSessionId,
          );
          final encrypted2 = await service.encryptPayload(
            payload,
            testSessionId,
          );

          expect(encrypted1, isNot(equals(encrypted2)));
        },
      );

      test('should decrypt payload correctly', () async {
        const originalPayload = 'This is a secret message!';
        final encrypted = await service.encryptPayload(
          originalPayload,
          testSessionId,
        );

        final decrypted = await service.decryptPayload(
          encrypted,
          testSessionId,
        );

        expect(decrypted, equals(originalPayload));
      });

      test('should handle empty payload', () async {
        const payload = '';

        final encrypted = await service.encryptPayload(payload, testSessionId);
        final decrypted = await service.decryptPayload(
          encrypted,
          testSessionId,
        );

        expect(decrypted, equals(payload));
      });

      test('should handle very long payload', () async {
        final payload = 'A' * 10000;

        final encrypted = await service.encryptPayload(payload, testSessionId);
        final decrypted = await service.decryptPayload(
          encrypted,
          testSessionId,
        );

        expect(decrypted, equals(payload));
      });

      test('should handle unicode characters', () async {
        const payload = 'Hello World! Merhaba Dunya!';

        final encrypted = await service.encryptPayload(payload, testSessionId);
        final decrypted = await service.decryptPayload(
          encrypted,
          testSessionId,
        );

        expect(decrypted, equals(payload));
      });

      test('should handle special characters and JSON', () async {
        const payload =
            '{"key": "value", "amount": 123.45, "items": ["a", "b", "c"]}';

        final encrypted = await service.encryptPayload(payload, testSessionId);
        final decrypted = await service.decryptPayload(
          encrypted,
          testSessionId,
        );

        expect(decrypted, equals(payload));
      });

      test('should log encryption event', () async {
        const payload = 'Log test payload';

        await service.encryptPayload(payload, testSessionId);

        verify(() => mockLogger.logEncryption(any())).called(1);
      });

      test('should log decryption event', () async {
        const payload = 'Log test payload';
        final encrypted = await service.encryptPayload(payload, testSessionId);
        reset(mockLogger);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        await service.decryptPayload(encrypted, testSessionId);

        verify(() => mockLogger.logEncryption(any())).called(1);
      });
    });

    group('Round-trip data integrity', () {
      late Uint8List aesKey;
      const sessionId = 'integrity-test-session';

      setUp(() {
        aesKey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          aesKey[i] = (i * 11 + 5) % 256;
        }

        when(
          () => mockKeyStore.loadAesKey(sessionId),
        ).thenAnswer((_) async => aesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);
      });

      test('should preserve exact data after encrypt-decrypt cycle', () async {
        const testData = [
          'Simple text',
          'Text with numbers 12345',
          'Special chars: !@#\$%^&*()',
          'Unicode: Privet mir! Salam Dunya!',
          '{"json": true, "nested": {"key": "value"}}',
          'Multiline\ntext\nwith\nnewlines',
          'Tabs\tand\tspaces   here',
          '',
          ' ',
          'A',
        ];

        for (final original in testData) {
          final encrypted = await service.encryptPayload(original, sessionId);
          final decrypted = await service.decryptPayload(encrypted, sessionId);

          expect(
            decrypted,
            equals(original),
            reason: 'Failed for input: "$original"',
          );
        }
      });

      test('should preserve binary data encoded as base64 string', () async {
        final binaryData = Uint8List.fromList(List.generate(256, (i) => i));
        final payload = base64Encode(binaryData);

        final encrypted = await service.encryptPayload(payload, sessionId);
        final decrypted = await service.decryptPayload(encrypted, sessionId);

        expect(decrypted, equals(payload));
        expect(base64Decode(decrypted), equals(binaryData));
      });

      test(
        'should work with different sessions using different keys',
        () async {
          const session1 = 'session-1';
          const session2 = 'session-2';
          const payload = 'Same payload, different keys';

          final key1 = Uint8List(32);
          final key2 = Uint8List(32);
          for (var i = 0; i < 32; i++) {
            key1[i] = i;
            key2[i] = 255 - i;
          }

          when(
            () => mockKeyStore.loadAesKey(session1),
          ).thenAnswer((_) async => key1);
          when(
            () => mockKeyStore.loadAesKey(session2),
          ).thenAnswer((_) async => key2);

          final encrypted1 = await service.encryptPayload(payload, session1);
          final encrypted2 = await service.encryptPayload(payload, session2);

          expect(encrypted1, isNot(equals(encrypted2)));

          final decrypted1 = await service.decryptPayload(encrypted1, session1);
          final decrypted2 = await service.decryptPayload(encrypted2, session2);
          expect(decrypted1, equals(payload));
          expect(decrypted2, equals(payload));
        },
      );
    });

    group('Payload signing and verification', () {
      const testKeyId = 'test-rsa-key';
      const testData = 'Data to sign';

      test('should sign data successfully when private key exists', () async {
        when(() => mockKeyStore.loadRsaPrivateKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
        );
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        final signature = await service.signData(testData, testKeyId);

        expect(signature, isA<String>());
        expect(signature.isNotEmpty, isTrue);
      });

      test(
        'should throw StateError when private key not found for signing',
        () async {
          when(
            () => mockKeyStore.loadRsaPrivateKey(testKeyId),
          ).thenAnswer((_) async => null);

          expect(
            () => service.signData(testData, testKeyId),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('No RSA private key found'),
              ),
            ),
          );
        },
      );

      test('should verify valid signature successfully', () async {
        when(() => mockKeyStore.loadRsaPrivateKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
        );
        when(() => mockKeyStore.loadRsaPublicKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PUBLIC KEY-----\ntest\n-----END PUBLIC KEY-----',
        );
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        final signature = await service.signData(testData, testKeyId);

        final isValid = await service.verifySignature(
          testData,
          signature,
          testKeyId,
        );

        expect(isValid, isTrue);
      });

      test('should reject invalid signature', () async {
        when(() => mockKeyStore.loadRsaPublicKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PUBLIC KEY-----\ntest\n-----END PUBLIC KEY-----',
        );

        final isValid = await service.verifySignature(
          testData,
          'invalid-signature',
          testKeyId,
        );

        expect(isValid, isFalse);
      });

      test(
        'should return false when public key not found for verification',
        () async {
          when(
            () => mockKeyStore.loadRsaPublicKey(testKeyId),
          ).thenAnswer((_) async => null);
          when(() => mockLogger.logError(any(), any())).thenReturn(null);

          final isValid = await service.verifySignature(
            testData,
            'some-signature',
            testKeyId,
          );

          expect(isValid, isFalse);
          verify(() => mockLogger.logError('verifySignature', any())).called(1);
        },
      );

      test('should log signing event', () async {
        when(() => mockKeyStore.loadRsaPrivateKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
        );
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        await service.signData(testData, testKeyId);

        verify(() => mockLogger.logEncryption(any())).called(1);
      });

      test(
        'should produce consistent signatures for same data and key',
        () async {
          when(() => mockKeyStore.loadRsaPrivateKey(testKeyId)).thenAnswer(
            (_) async =>
                '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
          );
          when(() => mockLogger.logEncryption(any())).thenReturn(null);

          final signature1 = await service.signData(testData, testKeyId);
          final signature2 = await service.signData(testData, testKeyId);

          expect(signature1, equals(signature2));
        },
      );

      test('should produce different signatures for different data', () async {
        when(() => mockKeyStore.loadRsaPrivateKey(testKeyId)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
        );
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        final signature1 = await service.signData('data1', testKeyId);
        final signature2 = await service.signData('data2', testKeyId);

        expect(signature1, isNot(equals(signature2)));
      });

      test('should produce different signatures for different keys', () async {
        const keyId1 = 'key1';
        const keyId2 = 'key2';

        when(() => mockKeyStore.loadRsaPrivateKey(keyId1)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\nkey1\n-----END PRIVATE KEY-----',
        );
        when(() => mockKeyStore.loadRsaPrivateKey(keyId2)).thenAnswer(
          (_) async =>
              '-----BEGIN PRIVATE KEY-----\nkey2\n-----END PRIVATE KEY-----',
        );
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        final signature1 = await service.signData(testData, keyId1);
        final signature2 = await service.signData(testData, keyId2);

        expect(signature1, isNot(equals(signature2)));
      });
    });

    group('computeChecksum', () {
      test('should compute consistent checksum for same input', () {
        const payload = 'test payload';

        final checksum1 = service.computeChecksum(payload);
        final checksum2 = service.computeChecksum(payload);

        expect(checksum1, equals(checksum2));
      });

      test('should compute different checksum for different inputs', () {
        const payload1 = 'test payload 1';
        const payload2 = 'test payload 2';

        final checksum1 = service.computeChecksum(payload1);
        final checksum2 = service.computeChecksum(payload2);

        expect(checksum1, isNot(equals(checksum2)));
      });

      test('should return 64-character SHA-256 hex string', () {
        const payload = 'any payload';

        final checksum = service.computeChecksum(payload);

        expect(checksum.length, equals(64));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum), isTrue);
      });

      test('should handle empty string', () {
        final checksum = service.computeChecksum('');

        expect(checksum.length, equals(64));
        expect(
          checksum,
          equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );
      });

      test('should handle unicode input', () {
        const payload = 'Privet mir!';

        final checksum = service.computeChecksum(payload);

        expect(checksum.length, equals(64));
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum), isTrue);
      });
    });

    group('Error handling', () {
      group('Invalid keys', () {
        test('should handle missing AES key gracefully', () async {
          const sessionId = 'nonexistent';

          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenAnswer((_) async => null);

          expect(
            () => service.encryptPayload('data', sessionId),
            throwsStateError,
          );
        });

        test('should handle missing RSA private key for signing', () async {
          const keyId = 'nonexistent';

          when(
            () => mockKeyStore.loadRsaPrivateKey(keyId),
          ).thenAnswer((_) async => null);

          expect(() => service.signData('data', keyId), throwsStateError);
        });

        test(
          'should return false for verification with missing public key',
          () async {
            const keyId = 'nonexistent';

            when(
              () => mockKeyStore.loadRsaPublicKey(keyId),
            ).thenAnswer((_) async => null);
            when(() => mockLogger.logError(any(), any())).thenReturn(null);

            final result = await service.verifySignature('data', 'sig', keyId);

            expect(result, isFalse);
          },
        );
      });

      group('Corrupted data', () {
        late Uint8List validKey;
        const sessionId = 'error-test-session';

        setUp(() {
          validKey = Uint8List(32);
          for (var i = 0; i < 32; i++) {
            validKey[i] = i;
          }
          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenAnswer((_) async => validKey);
          when(() => mockLogger.logEncryption(any())).thenReturn(null);
        });

        test(
          'should throw ArgumentError for encrypted data shorter than IV',
          () async {
            final shortData = base64Encode(Uint8List(10));

            expect(
              () => service.decryptPayload(shortData, sessionId),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  contains('Encrypted data too short'),
                ),
              ),
            );
          },
        );

        test('should throw for invalid base64 input', () async {
          const invalidBase64 = 'not valid base64!!!';

          expect(
            () => service.decryptPayload(invalidBase64, sessionId),
            throwsA(isA<FormatException>()),
          );
        });

        test('should fail decryption with wrong key', () async {
          const payload = 'secret data';
          final encrypted = await service.encryptPayload(payload, sessionId);

          final wrongKey = Uint8List(32);
          for (var i = 0; i < 32; i++) {
            wrongKey[i] = 255 - i;
          }

          const otherSession = 'other-session';
          when(
            () => mockKeyStore.loadAesKey(otherSession),
          ).thenAnswer((_) async => wrongKey);

          expect(
            () => service.decryptPayload(encrypted, otherSession),
            throwsA(anything),
          );
        });

        test('should fail for tampered ciphertext', () async {
          const payload = 'original data';
          final encrypted = await service.encryptPayload(payload, sessionId);

          final bytes = base64Decode(encrypted);
          if (bytes.length > 20) {
            bytes[20] = bytes[20] ^ 0xFF;
          }
          final tampered = base64Encode(bytes);

          expect(
            () => service.decryptPayload(tampered, sessionId),
            throwsA(anything),
          );
        });
      });

      group('Edge cases', () {
        test('should handle keyStore throwing exception', () async {
          const sessionId = 'error-session';

          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenThrow(Exception('Storage error'));

          expect(
            () => service.encryptPayload('data', sessionId),
            throwsException,
          );
        });

        test('should handle empty session ID', () async {
          const sessionId = '';

          when(
            () => mockKeyStore.loadAesKey(sessionId),
          ).thenAnswer((_) async => null);

          expect(
            () => service.encryptPayload('data', sessionId),
            throwsStateError,
          );
        });
      });
    });

    group('Logging behavior', () {
      late Uint8List aesKey;
      const sessionId = 'log-test-session';

      setUp(() {
        aesKey = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          aesKey[i] = i;
        }
        when(
          () => mockKeyStore.loadAesKey(sessionId),
        ).thenAnswer((_) async => aesKey);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);
      });

      test('should log encryption with byte sizes', () async {
        const payload = 'Test payload for logging';

        await service.encryptPayload(payload, sessionId);

        verify(() => mockLogger.logEncryption(any())).called(1);
      });

      test('should log decryption with byte sizes', () async {
        const payload = 'Test payload for logging';
        final encrypted = await service.encryptPayload(payload, sessionId);
        reset(mockLogger);
        when(() => mockLogger.logEncryption(any())).thenReturn(null);

        await service.decryptPayload(encrypted, sessionId);

        verify(() => mockLogger.logEncryption(any())).called(1);
      });

      test('should log error when public key not found', () async {
        when(
          () => mockKeyStore.loadRsaPublicKey('missing'),
        ).thenAnswer((_) async => null);
        when(() => mockLogger.logError(any(), any())).thenReturn(null);

        await service.verifySignature('data', 'sig', 'missing');

        verify(() => mockLogger.logError(any(), any())).called(1);
      });
    });
  });
}
