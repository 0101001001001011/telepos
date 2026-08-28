import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class MockTdLibClient extends Mock implements TdLibClient {}

class MockTdLibEventLoop extends Mock implements TdLibEventLoop {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

class MockTalker extends Mock implements Talker {}

class FakeMap extends Fake implements Map<String, dynamic> {}

TdLibLogger createMockLogger() {
  final mockTalker = MockTalker();
  when(() => mockTalker.info(any())).thenReturn(null);
  when(() => mockTalker.error(any(), any(), any())).thenReturn(null);
  when(() => mockTalker.verbose(any(), any())).thenReturn(null);
  when(() => mockTalker.warning(any())).thenReturn(null);
  when(() => mockTalker.critical(any(), any(), any())).thenReturn(null);
  return TdLibLogger(talker: mockTalker);
}

MockTdLibEventLoop createMockEventLoop() {
  final mockEventLoop = MockTdLibEventLoop();
  when(() => mockEventLoop.on(any(), any())).thenReturn(null);
  when(() => mockEventLoop.off(any(), any())).thenReturn(null);
  when(() => mockEventLoop.offAll(any())).thenReturn(null);
  when(() => mockEventLoop.isRunning).thenReturn(true);
  return mockEventLoop;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMap());
    registerFallbackValue(<String, dynamic>{});
  });

  group('TelegramAuthService', () {
    late MockTdLibClient mockClient;
    late TdLibLogger logger;
    late TdLibEventLoop eventLoop;
    late StreamController<Map<String, dynamic>> updateController;
    late TelegramAuthService authService;

    setUp(() {
      mockClient = MockTdLibClient();
      logger = createMockLogger();
      updateController = StreamController<Map<String, dynamic>>.broadcast();

      eventLoop = TdLibEventLoop(client: mockClient, logger: logger);

      when(() => mockClient.updates).thenAnswer((_) => updateController.stream);

      when(
        () => mockClient.setAuthenticationPhoneNumber(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockClient.checkAuthenticationCode(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockClient.checkAuthenticationPassword(any()),
      ).thenAnswer((_) async {});
      when(() => mockClient.requestQrCodeAuthentication(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'link': 'tg://login?token=abc123',
          'expires_in': 300,
        },
      );
      when(
        () => mockClient.registerUser(any(), any()),
      ).thenAnswer((_) async {});
      when(() => mockClient.logOut()).thenAnswer((_) async {});
      when(
        () => mockClient.sendSync(any()),
      ).thenAnswer((_) async => <String, dynamic>{});
      when(() => mockClient.send(any())).thenAnswer((_) async {});

      eventLoop.start();

      authService = TelegramAuthService(
        client: mockClient,
        eventLoop: eventLoop,
        logger: logger,
      );
    });

    tearDown(() async {
      await eventLoop.stop();
      await updateController.close();
      await authService.dispose();
    });

    group('initial state', () {
      test('starts in initial state', () {
        expect(authService.currentState, isA<TelegramAuthStateInitial>());
      });

      test('isAuthorized is false initially', () {
        expect(authService.isAuthorized, false);
      });

      test('stateStream is a broadcast stream', () {
        expect(authService.stateStream.isBroadcast, true);
      });

      test('can have multiple state stream listeners', () async {
        final states1 = <TelegramAuthState>[];
        final states2 = <TelegramAuthState>[];

        final sub1 = authService.stateStream.listen(states1.add);
        final sub2 = authService.stateStream.listen(states2.add);

        await authService.startPhoneAuth('+77001234567');

        await Future<void>.delayed(Duration.zero);

        await sub1.cancel();
        await sub2.cancel();

        expect(states1, equals(states2));
      });
    });

    group('auth state machine transitions', () {
      test(
        'transitions from initial to waitingPhoneNumber on TDLib update',
        () async {
          final states = <TelegramAuthState>[];
          final subscription = authService.stateStream.listen(states.add);

          updateController.add({
            '@type': 'updateAuthorizationState',
            'authorization_state': {
              '@type': 'authorizationStateWaitPhoneNumber',
            },
          });

          await Future<void>.delayed(const Duration(milliseconds: 10));
          await subscription.cancel();

          expect(states.last, isA<TelegramAuthStateWaitingPhoneNumber>());
        },
      );

      test('transitions to waitingCode on TDLib update', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitCode',
            'code_info': {
              'phone_number': '+77001234567',
              'type': {'@type': 'authenticationCodeTypeSms', 'length': 5},
            },
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingCode>());
        final codeState = states.last as TelegramAuthStateWaitingCode;
        expect(codeState.phoneNumber, '+77001234567');
        expect(codeState.codeLength, 5);
      });

      test('transitions to waitingPassword on TDLib update', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitPassword',
            'password_hint': 'Your favorite pet',
            'has_recovery_email_address': true,
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingPassword>());
        final passwordState = states.last as TelegramAuthStateWaitingPassword;
        expect(passwordState.passwordHint, 'Your favorite pet');
        expect(passwordState.hasRecoveryEmail, true);
      });

      test('transitions to waitingRegistration on TDLib update', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitRegistration',
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingRegistration>());
      });

      test('transitions to authorized on authorizationStateReady', () async {
        when(() => mockClient.sendSync({'@type': 'getMe'})).thenAnswer(
          (_) async => {
            'id': 12345,
            'first_name': 'John',
            'last_name': 'Doe',
            'phone_number': '+77001234567',
            'usernames': {'editable_username': 'johndoe'},
          },
        );

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateReady'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateAuthorized>());
        final authorizedState = states.last as TelegramAuthStateAuthorized;
        expect(authorizedState.userId, 12345);
        expect(authorizedState.firstName, 'John');
        expect(authorizedState.lastName, 'Doe');
        expect(authorizedState.phoneNumber, '+77001234567');
        expect(authorizedState.username, 'johndoe');
      });

      test('transitions to loggedOut on authorizationStateClosed', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateLoggedOut>());
      });

      test('transitions to loggedOut on authorizationStateClosing', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosing'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateLoggedOut>());
      });

      test(
        'transitions to waitingQrCode on authorizationStateWaitOtherDeviceConfirmation',
        () async {
          final states = <TelegramAuthState>[];
          final subscription = authService.stateStream.listen(states.add);

          updateController.add({
            '@type': 'updateAuthorizationState',
            'authorization_state': {
              '@type': 'authorizationStateWaitOtherDeviceConfirmation',
              'link': 'tg://login?token=xyz789',
            },
          });

          await Future<void>.delayed(const Duration(milliseconds: 10));
          await subscription.cancel();

          expect(states.last, isA<TelegramAuthStateWaitingQrCode>());
          final qrState = states.last as TelegramAuthStateWaitingQrCode;
          expect(qrState.qrCodeLink, 'tg://login?token=xyz789');
        },
      );

      test('ignores updates with null authorization_state', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': null,
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states, isEmpty);
        expect(authService.currentState, isA<TelegramAuthStateInitial>());
      });

      test('ignores updates with unknown authorization state type', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateUnknownFutureType',
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states, isEmpty);
        expect(authService.currentState, isA<TelegramAuthStateInitial>());
      });
    });

    group('phone authentication flow', () {
      test(
        'startPhoneAuth calls client with normalized phone number',
        () async {
          await authService.startPhoneAuth('+77001234567');

          verify(
            () => mockClient.setAuthenticationPhoneNumber('+77001234567'),
          ).called(1);
        },
      );

      test('startPhoneAuth transitions to waitingCode state', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startPhoneAuth('+77001234567');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingCode>());
        final codeState = states.last as TelegramAuthStateWaitingCode;
        expect(codeState.phoneNumber, '+77001234567');
        expect(codeState.codeType, 'sms');
      });

      test('startPhoneAuth handles 8-prefix Kazakhstan numbers', () async {
        await authService.startPhoneAuth('87001234567');

        verify(
          () => mockClient.setAuthenticationPhoneNumber('+77001234567'),
        ).called(1);
      });

      test('startPhoneAuth handles numbers without + prefix', () async {
        await authService.startPhoneAuth('77001234567');

        verify(
          () => mockClient.setAuthenticationPhoneNumber('+77001234567'),
        ).called(1);
      });

      test('startPhoneAuth transitions to error state on failure', () async {
        when(
          () => mockClient.setAuthenticationPhoneNumber(any()),
        ).thenThrow(Exception('Network error'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startPhoneAuth('+77001234567');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Failed to send phone number'));
      });
    });

    group('code verification', () {
      test('submitCode calls client with trimmed code', () async {
        await authService.submitCode('12345');

        verify(() => mockClient.checkAuthenticationCode('12345')).called(1);
      });

      test('submitCode trims whitespace from code', () async {
        await authService.submitCode('  12345  ');

        verify(() => mockClient.checkAuthenticationCode('12345')).called(1);
      });

      test('submitCode transitions to error state on invalid code', () async {
        when(
          () => mockClient.checkAuthenticationCode(any()),
        ).thenThrow(Exception('PHONE_CODE_INVALID'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitCode('00000');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Invalid code'));
      });

      test('submitCode handles empty code gracefully', () async {
        when(
          () => mockClient.checkAuthenticationCode(any()),
        ).thenThrow(Exception('Code cannot be empty'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitCode('');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
      });
    });

    group('2FA password handling', () {
      test('submitPassword calls client with password', () async {
        await authService.submitPassword('mySecretPassword');

        verify(
          () => mockClient.checkAuthenticationPassword('mySecretPassword'),
        ).called(1);
      });

      test(
        'submitPassword transitions to error state on invalid password',
        () async {
          when(
            () => mockClient.checkAuthenticationPassword(any()),
          ).thenThrow(Exception('PASSWORD_HASH_INVALID'));

          final states = <TelegramAuthState>[];
          final subscription = authService.stateStream.listen(states.add);

          await authService.submitPassword('wrongPassword');

          await Future<void>.delayed(Duration.zero);
          await subscription.cancel();

          expect(states.last, isA<TelegramAuthStateError>());
          final errorState = states.last as TelegramAuthStateError;
          expect(errorState.message, contains('Invalid password'));
        },
      );

      test('submitPassword handles empty password', () async {
        when(
          () => mockClient.checkAuthenticationPassword(any()),
        ).thenThrow(Exception('Password cannot be empty'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitPassword('');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
      });

      test(
        'submitPassword preserves password with special characters',
        () async {
          const password = r'P@$$w0rd!#$%^&*()_+-=[]{}|;:,.<>?';
          await authService.submitPassword(password);

          verify(
            () => mockClient.checkAuthenticationPassword(password),
          ).called(1);
        },
      );
    });

    group('QR code authentication', () {
      test('startQrAuth requests QR code from client', () async {
        await authService.startQrAuth();

        verify(() => mockClient.requestQrCodeAuthentication([])).called(1);
      });

      test('startQrAuth transitions to waitingQrCode state', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startQrAuth();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingQrCode>());
        final qrState = states.last as TelegramAuthStateWaitingQrCode;
        expect(qrState.qrCodeLink, 'tg://login?token=abc123');
        expect(qrState.expiresAt.isAfter(DateTime.now()), true);
      });

      test('startQrAuth sets correct expiration time', () async {
        when(() => mockClient.requestQrCodeAuthentication(any())).thenAnswer(
          (_) async => {'link': 'tg://login?token=test', 'expires_in': 600},
        );

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);
        final beforeRequest = DateTime.now();

        await authService.startQrAuth();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        final qrState = states.last as TelegramAuthStateWaitingQrCode;
        final expectedExpiry = beforeRequest.add(const Duration(seconds: 600));

        expect(
          qrState.expiresAt.difference(expectedExpiry).inSeconds.abs(),
          lessThanOrEqualTo(1),
        );
      });

      test('startQrAuth transitions to error state on failure', () async {
        when(
          () => mockClient.requestQrCodeAuthentication(any()),
        ).thenThrow(Exception('QR code generation failed'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startQrAuth();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Failed to start QR auth'));
      });

      test('startQrAuth handles empty link in response', () async {
        when(
          () => mockClient.requestQrCodeAuthentication(any()),
        ).thenAnswer((_) async => {'link': '', 'expires_in': 300});

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startQrAuth();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingQrCode>());
        final qrState = states.last as TelegramAuthStateWaitingQrCode;
        expect(qrState.qrCodeLink, '');
      });
    });

    group('registration flow', () {
      test('register calls client with first name only', () async {
        await authService.register(firstName: 'John');

        verify(() => mockClient.registerUser('John', null)).called(1);
      });

      test('register calls client with first and last name', () async {
        await authService.register(firstName: 'John', lastName: 'Doe');

        verify(() => mockClient.registerUser('John', 'Doe')).called(1);
      });

      test('register transitions to error state on failure', () async {
        when(
          () => mockClient.registerUser(any(), any()),
        ).thenThrow(Exception('Registration blocked'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.register(firstName: 'John');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Registration failed'));
      });

      test('register handles empty first name gracefully', () async {
        when(
          () => mockClient.registerUser(any(), any()),
        ).thenThrow(Exception('First name is required'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.register(firstName: '');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
      });

      test('register preserves Unicode characters in names', () async {
        await authService.register(firstName: 'Aleksandr', lastName: 'Ivanov');

        verify(() => mockClient.registerUser('Aleksandr', 'Ivanov')).called(1);
      });
    });

    group('logout', () {
      test('logOut calls client logOut method', () async {
        await authService.logOut();

        verify(() => mockClient.logOut()).called(1);
      });

      test('logOut transitions to loggedOut state', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.logOut();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateLoggedOut>());
      });

      test('logOut transitions to error state on failure', () async {
        when(() => mockClient.logOut()).thenThrow(Exception('Logout failed'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.logOut();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Logout failed'));
      });

      test('logOut can be called multiple times', () async {
        await authService.logOut();
        await authService.logOut();
        await authService.logOut();

        verify(() => mockClient.logOut()).called(3);
      });
    });

    group('error handling', () {
      test('error state preserves previous state', () async {
        await authService.startPhoneAuth('+77001234567');

        final previousState = authService.currentState;

        when(
          () => mockClient.checkAuthenticationCode(any()),
        ).thenThrow(Exception('Code error'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitCode('12345');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.previousState, equals(previousState));
      });

      test('error state includes error message', () async {
        when(
          () => mockClient.setAuthenticationPhoneNumber(any()),
        ).thenThrow(Exception('PHONE_NUMBER_INVALID'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startPhoneAuth('invalid');

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('PHONE_NUMBER_INVALID'));
      });

      test('handles authorization ready error gracefully', () async {
        when(
          () => mockClient.sendSync({'@type': 'getMe'}),
        ).thenThrow(Exception('Network error'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateReady'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateAuthorized>());
        final authorizedState = states.last as TelegramAuthStateAuthorized;
        expect(authorizedState.userId, 0);
        expect(authorizedState.firstName, 'Unknown');
      });

      test('handles null fields in authorization ready response', () async {
        when(
          () => mockClient.sendSync({'@type': 'getMe'}),
        ).thenAnswer((_) async => <String, dynamic>{});

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateReady'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateAuthorized>());
        final authorizedState = states.last as TelegramAuthStateAuthorized;
        expect(authorizedState.userId, 0);
        expect(authorizedState.firstName, '');
      });
    });

    group('identity verification', () {
      test(
        'submitIdentityDocuments transitions to verifyingDocuments state',
        () async {
          final states = <TelegramAuthState>[];
          final subscription = authService.stateStream.listen(states.add);

          await authService.submitIdentityDocuments(
            documentPaths: ['/path/to/passport.jpg'],
            documentTypes: [IdentityDocumentType.passport],
          );

          await Future<void>.delayed(Duration.zero);
          await subscription.cancel();

          expect(states.last, isA<TelegramAuthStateVerifyingDocuments>());
          final verifyingState =
              states.last as TelegramAuthStateVerifyingDocuments;
          expect(verifyingState.submittedDocumentPaths, [
            '/path/to/passport.jpg',
          ]);
          expect(verifyingState.status, DocumentVerificationStatus.submitted);
        },
      );

      test('submitIdentityDocuments handles multiple documents', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitIdentityDocuments(
          documentPaths: ['/path/to/passport.jpg', '/path/to/selfie.jpg'],
          documentTypes: [
            IdentityDocumentType.passport,
            IdentityDocumentType.selfieWithDocument,
          ],
        );

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateVerifyingDocuments>());
        final verifyingState =
            states.last as TelegramAuthStateVerifyingDocuments;
        expect(verifyingState.submittedDocumentPaths.length, 2);
      });

      test('submitIdentityDocuments transitions to error on failure', () async {
        when(
          () => mockClient.send(any()),
        ).thenThrow(Exception('Document upload failed'));

        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.submitIdentityDocuments(
          documentPaths: ['/path/to/doc.jpg'],
          documentTypes: [IdentityDocumentType.passport],
        );

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateError>());
        final errorState = states.last as TelegramAuthStateError;
        expect(errorState.message, contains('Document submission failed'));
      });

      test('checkVerificationStatus returns current status', () async {
        when(
          () => mockClient.sendSync(any()),
        ).thenAnswer((_) async => {'errors': []});

        final status = await authService.checkVerificationStatus();

        expect(status, isA<DocumentVerificationStatus>());
      });
    });

    group('isAuthorized getter', () {
      test('returns false when in initial state', () {
        expect(authService.isAuthorized, false);
      });

      test('returns false when waiting for phone number', () async {
        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateWaitPhoneNumber'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(authService.isAuthorized, false);
      });

      test('returns false when waiting for code', () async {
        await authService.startPhoneAuth('+77001234567');

        expect(authService.isAuthorized, false);
      });

      test('returns false when in error state', () async {
        when(
          () => mockClient.setAuthenticationPhoneNumber(any()),
        ).thenThrow(Exception('Error'));

        await authService.startPhoneAuth('+77001234567');

        expect(authService.isAuthorized, false);
      });

      test('returns true when authorized', () async {
        when(
          () => mockClient.sendSync({'@type': 'getMe'}),
        ).thenAnswer((_) async => {'id': 12345, 'first_name': 'John'});

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateReady'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(authService.isAuthorized, true);
      });

      test('returns false after logout', () async {
        when(
          () => mockClient.sendSync({'@type': 'getMe'}),
        ).thenAnswer((_) async => {'id': 12345, 'first_name': 'John'});

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateReady'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(authService.isAuthorized, true);

        await authService.logOut();

        expect(authService.isAuthorized, false);
      });
    });

    group('dispose', () {
      test('closes state stream', () async {
        var streamClosed = false;
        authService.stateStream.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

        await authService.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(streamClosed, true);
      });

      test('dispose can be called multiple times safely', () async {
        await authService.dispose();
        await authService.dispose();
        await authService.dispose();

        expect(true, true);
      });

      test('state updates are not emitted after dispose', () async {
        await authService.dispose();

        final states = <TelegramAuthState>[];
        authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateWaitPhoneNumber'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(states, isEmpty);
      });
    });

    group('edge cases and complex scenarios', () {
      test('handles rapid state transitions', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateWaitPhoneNumber'},
        });
        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitCode',
            'code_info': {'phone_number': '+77001234567', 'type': {}},
          },
        });
        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitPassword',
            'password_hint': 'hint',
            'has_recovery_email_address': false,
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(states.length, 3);
        expect(states[0], isA<TelegramAuthStateWaitingPhoneNumber>());
        expect(states[1], isA<TelegramAuthStateWaitingCode>());
        expect(states[2], isA<TelegramAuthStateWaitingPassword>());
      });

      test('handles interleaved method calls and updates', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        await authService.startPhoneAuth('+77001234567');

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitCode',
            'code_info': {
              'phone_number': '+77001234567',
              'type': {'@type': 'authenticationCodeTypeSms', 'length': 5},
            },
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(states.length, greaterThanOrEqualTo(1));
      });

      test('handles waitingCode state with missing code_info', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateWaitCode'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingCode>());
        final codeState = states.last as TelegramAuthStateWaitingCode;
        expect(codeState.phoneNumber, '');
        expect(codeState.codeType, 'unknown');
        expect(codeState.codeLength, isNull);
      });

      test('handles waitingPassword state with missing fields', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateWaitPassword'},
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states.last, isA<TelegramAuthStateWaitingPassword>());
        final passwordState = states.last as TelegramAuthStateWaitingPassword;
        expect(passwordState.passwordHint, '');
        expect(passwordState.hasRecoveryEmail, false);
      });

      test('ignores authorizationStateWaitTdlibParameters', () async {
        final states = <TelegramAuthState>[];
        final subscription = authService.stateStream.listen(states.add);

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitTdlibParameters',
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await subscription.cancel();

        expect(states, isEmpty);
      });

      test('currentState reflects the latest state', () async {
        expect(authService.currentState, isA<TelegramAuthStateInitial>());

        await authService.startPhoneAuth('+77001234567');
        expect(authService.currentState, isA<TelegramAuthStateWaitingCode>());

        updateController.add({
          '@type': 'updateAuthorizationState',
          'authorization_state': {
            '@type': 'authorizationStateWaitPassword',
            'password_hint': '',
            'has_recovery_email_address': false,
          },
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          authService.currentState,
          isA<TelegramAuthStateWaitingPassword>(),
        );
      });
    });
  });

  group('TelegramAuthState', () {
    test('initial state creates correctly', () {
      const state = TelegramAuthState.initial();
      expect(state, isA<TelegramAuthStateInitial>());
    });

    test('waitingPhoneNumber state creates correctly', () {
      const state = TelegramAuthState.waitingPhoneNumber();
      expect(state, isA<TelegramAuthStateWaitingPhoneNumber>());
    });

    test('waitingCode state creates with all parameters', () {
      const state = TelegramAuthState.waitingCode(
        phoneNumber: '+77001234567',
        codeType: 'sms',
        codeLength: 5,
      );

      expect(state, isA<TelegramAuthStateWaitingCode>());
      expect(
        (state as TelegramAuthStateWaitingCode).phoneNumber,
        '+77001234567',
      );
      expect(state.codeType, 'sms');
      expect(state.codeLength, 5);
    });

    test('waitingCode state handles null codeLength', () {
      const state = TelegramAuthState.waitingCode(
        phoneNumber: '+77001234567',
        codeType: 'sms',
      );

      expect((state as TelegramAuthStateWaitingCode).codeLength, isNull);
    });

    test('waitingPassword state creates with all parameters', () {
      const state = TelegramAuthState.waitingPassword(
        passwordHint: 'Your pet name',
        hasRecoveryEmail: true,
      );

      expect(state, isA<TelegramAuthStateWaitingPassword>());
      expect(
        (state as TelegramAuthStateWaitingPassword).passwordHint,
        'Your pet name',
      );
      expect(state.hasRecoveryEmail, true);
    });

    test('waitingQrCode state creates with all parameters', () {
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      final state = TelegramAuthState.waitingQrCode(
        qrCodeLink: 'tg://login?token=abc',
        expiresAt: expiresAt,
      );

      expect(state, isA<TelegramAuthStateWaitingQrCode>());
      expect(
        (state as TelegramAuthStateWaitingQrCode).qrCodeLink,
        'tg://login?token=abc',
      );
      expect(state.expiresAt, expiresAt);
    });

    test('waitingRegistration state creates correctly', () {
      const state = TelegramAuthState.waitingRegistration();
      expect(state, isA<TelegramAuthStateWaitingRegistration>());
    });

    test('authorized state creates with all parameters', () {
      const state = TelegramAuthState.authorized(
        userId: 12345,
        firstName: 'John',
        lastName: 'Doe',
        phoneNumber: '+77001234567',
        username: 'johndoe',
      );

      expect(state, isA<TelegramAuthStateAuthorized>());
      expect((state as TelegramAuthStateAuthorized).userId, 12345);
      expect(state.firstName, 'John');
      expect(state.lastName, 'Doe');
      expect(state.phoneNumber, '+77001234567');
      expect(state.username, 'johndoe');
    });

    test('authorized state handles null optional parameters', () {
      const state = TelegramAuthState.authorized(
        userId: 12345,
        firstName: 'John',
      );

      expect((state as TelegramAuthStateAuthorized).lastName, isNull);
      expect(state.phoneNumber, isNull);
      expect(state.username, isNull);
    });

    test('error state creates with all parameters', () {
      const previousState = TelegramAuthState.initial();
      const state = TelegramAuthState.error(
        message: 'Something went wrong',
        code: 500,
        previousState: previousState,
      );

      expect(state, isA<TelegramAuthStateError>());
      expect((state as TelegramAuthStateError).message, 'Something went wrong');
      expect(state.code, 500);
      expect(state.previousState, previousState);
    });

    test('error state handles null optional parameters', () {
      const state = TelegramAuthState.error(message: 'Error');

      expect((state as TelegramAuthStateError).code, isNull);
      expect(state.previousState, isNull);
    });

    test('loggedOut state creates correctly', () {
      const state = TelegramAuthState.loggedOut();
      expect(state, isA<TelegramAuthStateLoggedOut>());
    });

    test('waitingIdentityVerification state creates correctly', () {
      const state = TelegramAuthState.waitingIdentityVerification(
        requiredDocuments: [
          IdentityDocumentType.passport,
          IdentityDocumentType.selfieWithDocument,
        ],
        reason: 'Identity verification required',
      );

      expect(state, isA<TelegramAuthStateWaitingIdentityVerification>());
      expect(
        (state as TelegramAuthStateWaitingIdentityVerification)
            .requiredDocuments
            .length,
        2,
      );
      expect(state.reason, 'Identity verification required');
    });

    test('verifyingDocuments state creates correctly', () {
      const state = TelegramAuthState.verifyingDocuments(
        submittedDocumentPaths: ['/path/to/doc.jpg'],
        status: DocumentVerificationStatus.inReview,
      );

      expect(state, isA<TelegramAuthStateVerifyingDocuments>());
      expect(
        (state as TelegramAuthStateVerifyingDocuments).submittedDocumentPaths,
        ['/path/to/doc.jpg'],
      );
      expect(state.status, DocumentVerificationStatus.inReview);
    });
  });

  group('DocumentVerificationStatus', () {
    test('has all expected values', () {
      expect(
        DocumentVerificationStatus.values,
        containsAll([
          DocumentVerificationStatus.pending,
          DocumentVerificationStatus.submitted,
          DocumentVerificationStatus.inReview,
          DocumentVerificationStatus.approved,
          DocumentVerificationStatus.rejected,
          DocumentVerificationStatus.additionalRequired,
        ]),
      );
    });

    test('enum count is 6', () {
      expect(DocumentVerificationStatus.values.length, 6);
    });
  });

  group('IdentityDocumentType', () {
    test('has all expected values', () {
      expect(
        IdentityDocumentType.values,
        containsAll([
          IdentityDocumentType.passport,
          IdentityDocumentType.identityCard,
          IdentityDocumentType.driverLicense,
          IdentityDocumentType.selfieWithDocument,
          IdentityDocumentType.facePhoto,
          IdentityDocumentType.taxId,
        ]),
      );
    });

    test('enum count is 6', () {
      expect(IdentityDocumentType.values.length, 6);
    });
  });
}
