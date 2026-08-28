import 'dart:async';

import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/auth/phone_auth_handler.dart';
import 'package:telepos/telegram/auth/qr_auth_handler.dart';
import 'package:telepos/telegram/auth/two_factor_handler.dart';
import 'package:telepos/telegram/auth/identity_verification_handler.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';

class TelegramAuthService {
  final TdLibClient _client;
  final TdLibEventLoop _eventLoop;
  final TdLibLogger _logger;

  late final PhoneAuthHandler _phoneAuth;
  late final QrAuthHandler _qrAuth;
  late final TwoFactorHandler _twoFactor;
  late final IdentityVerificationHandler _identityVerification;

  final _stateController = StreamController<TelegramAuthState>.broadcast();
  TelegramAuthState _currentState = const TelegramAuthState.initial();

  TelegramAuthService({
    required TdLibClient client,
    required TdLibEventLoop eventLoop,
    required TdLibLogger logger,
  }) : _client = client,
       _eventLoop = eventLoop,
       _logger = logger {
    _phoneAuth = PhoneAuthHandler(client: _client, logger: _logger);
    _qrAuth = QrAuthHandler(client: _client, logger: _logger);
    _twoFactor = TwoFactorHandler(client: _client, logger: _logger);
    _identityVerification = IdentityVerificationHandler(
      client: _client,
      logger: _logger,
    );
    _setupUpdateHandlers();
  }

  TelegramAuthState get currentState => _currentState;

  Stream<TelegramAuthState> get stateStream => _stateController.stream;

  bool get isAuthorized => _currentState is TelegramAuthStateAuthorized;

  Future<void> startPhoneAuth(String phoneNumber) async {
    _logger.logAuthState('Starting phone auth: $phoneNumber');
    try {
      await _phoneAuth.sendPhoneNumber(phoneNumber);
      _setState(
        TelegramAuthState.waitingCode(
          phoneNumber: phoneNumber,
          codeType: 'sms',
        ),
      );
    } catch (e) {
      _setError('Failed to send phone number: $e');
    }
  }

  Future<void> startQrAuth() async {
    _logger.logAuthState('Starting QR auth');
    try {
      final qrData = await _qrAuth.requestQrCode();
      _setState(
        TelegramAuthState.waitingQrCode(
          qrCodeLink: qrData.link,
          expiresAt: qrData.expiresAt,
        ),
      );
    } catch (e) {
      _setError('Failed to start QR auth: $e');
    }
  }

  Future<void> submitCode(String code) async {
    _logger.logAuthState('Submitting code');
    try {
      await _phoneAuth.submitCode(code);
    } catch (e) {
      _setError('Invalid code: $e');
    }
  }

  Future<void> submitPassword(String password) async {
    _logger.logAuthState('Submitting 2FA password');
    try {
      await _twoFactor.submitPassword(password);
    } catch (e) {
      _setError('Invalid password: $e');
    }
  }

  Future<void> register({required String firstName, String? lastName}) async {
    _logger.logAuthState('Registering user: $firstName');
    try {
      await _client.registerUser(firstName, lastName);
    } catch (e) {
      _setError('Registration failed: $e');
    }
  }

  Future<void> submitIdentityDocuments({
    required List<String> documentPaths,
    required List<IdentityDocumentType> documentTypes,
  }) async {
    _logger.logAuthState('Submitting identity documents');
    try {
      _setState(
        TelegramAuthState.verifyingDocuments(
          submittedDocumentPaths: documentPaths,
          status: DocumentVerificationStatus.submitted,
        ),
      );

      await _identityVerification.submitDocuments(
        documentPaths: documentPaths,
        documentTypes: documentTypes,
      );
    } catch (e) {
      _setError('Document submission failed: $e');
    }
  }

  Future<DocumentVerificationStatus> checkVerificationStatus() async {
    return _identityVerification.checkStatus();
  }

  Future<void> logOut() async {
    _logger.logAuthState('Logging out');
    try {
      await _client.logOut();
      _setState(const TelegramAuthState.loggedOut());
    } catch (e) {
      _setError('Logout failed: $e');
    }
  }

  Future<void> dispose() async {
    await _stateController.close();
  }

  void _setupUpdateHandlers() {
    _eventLoop.on('updateAuthorizationState', (update) {
      final authState = update['authorization_state'] as Map<String, dynamic>?;
      if (authState == null) return;

      final type = authState['@type'] as String?;
      _logger.logAuthState('TDLib auth state: $type');

      switch (type) {
        case 'authorizationStateWaitTdlibParameters':
          break;

        case 'authorizationStateWaitPhoneNumber':
          _setState(const TelegramAuthState.waitingPhoneNumber());
          break;

        case 'authorizationStateWaitCode':
          final codeInfo = authState['code_info'] as Map<String, dynamic>?;
          _setState(
            TelegramAuthState.waitingCode(
              phoneNumber: codeInfo?['phone_number'] as String? ?? '',
              codeType: codeInfo?['type']?['@type'] as String? ?? 'unknown',
              codeLength: codeInfo?['type']?['length'] as int?,
            ),
          );
          break;

        case 'authorizationStateWaitPassword':
          _setState(
            TelegramAuthState.waitingPassword(
              passwordHint: authState['password_hint'] as String? ?? '',
              hasRecoveryEmail:
                  authState['has_recovery_email_address'] as bool? ?? false,
            ),
          );
          break;

        case 'authorizationStateWaitRegistration':
          _setState(const TelegramAuthState.waitingRegistration());
          break;

        case 'authorizationStateReady':
          _handleAuthorizationReady();
          break;

        case 'authorizationStateClosing':
        case 'authorizationStateClosed':
          _setState(const TelegramAuthState.loggedOut());
          break;

        case 'authorizationStateWaitOtherDeviceConfirmation':
          final link = authState['link'] as String? ?? '';
          _setState(
            TelegramAuthState.waitingQrCode(
              qrCodeLink: link,
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
            ),
          );
          break;
      }
    });
  }

  Future<void> _handleAuthorizationReady() async {
    try {
      final me = await _client.sendSync({'@type': 'getMe'});
      _setState(
        TelegramAuthState.authorized(
          userId: me['id'] as int? ?? 0,
          firstName: me['first_name'] as String? ?? '',
          lastName: me['last_name'] as String?,
          phoneNumber: me['phone_number'] as String?,
          username: me['usernames']?['editable_username'] as String?,
        ),
      );
    } catch (e) {
      _logger.logError('_handleAuthorizationReady', e);
      _setState(
        const TelegramAuthState.authorized(userId: 0, firstName: 'Unknown'),
      );
    }
  }

  void _setState(TelegramAuthState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _setError(String message) {
    _logger.logError('auth', message);
    _setState(
      TelegramAuthState.error(message: message, previousState: _currentState),
    );
  }
}
