import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/entities/telegram/auth_state.dart';
import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/automation/auto_channel_creator.dart';
import 'package:telepos/telegram/automation/auto_setup_service.dart';
import 'package:telepos/telegram/core/telegram_initializer.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';

@immutable
class OrganizationData {
  const OrganizationData({
    this.storeName,
    this.bin,
    this.address,
    this.posId,
    this.ownerName,
  });

  final String? storeName;

  final String? bin;

  final String? address;

  final String? posId;

  final String? ownerName;

  bool get isComplete =>
      storeName != null &&
      storeName!.isNotEmpty &&
      bin != null &&
      bin!.isNotEmpty;

  OrganizationData copyWith({
    String? storeName,
    String? bin,
    String? address,
    String? posId,
    String? ownerName,
  }) {
    return OrganizationData(
      storeName: storeName ?? this.storeName,
      bin: bin ?? this.bin,
      address: address ?? this.address,
      posId: posId ?? this.posId,
      ownerName: ownerName ?? this.ownerName,
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'bin': bin,
    'address': address,
    'posId': posId,
    'ownerName': ownerName,
  };

  factory OrganizationData.fromJson(Map<String, dynamic> json) {
    return OrganizationData(
      storeName: json['storeName'] as String?,
      bin: json['bin'] as String?,
      address: json['address'] as String?,
      posId: json['posId'] as String?,
      ownerName: json['ownerName'] as String?,
    );
  }
}

@immutable
class TelegramSetupState {
  const TelegramSetupState({
    this.authState = const TelegramAuthState.initial(),
    this.setupStep = TelegramSetupStep.initializing,
    this.isLoading = false,
    this.error,
    this.qrCodeLink,
    this.phoneNumber,
    this.passwordHint,
    this.organization = const OrganizationData(),
    this.existingChannelsFound = false,
  });

  final TelegramAuthState authState;

  final TelegramSetupStep setupStep;

  final bool isLoading;

  final String? error;

  final String? qrCodeLink;

  final String? phoneNumber;

  final String? passwordHint;

  final OrganizationData organization;

  final bool existingChannelsFound;

  bool get hasError => error != null && error!.isNotEmpty;

  bool get isAuthorized => authState is TelegramAuthStateAuthorized;

  bool get isSetupComplete => setupStep == TelegramSetupStep.complete;

  TelegramSetupState copyWith({
    TelegramAuthState? authState,
    TelegramSetupStep? setupStep,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? qrCodeLink,
    bool clearQrCode = false,
    String? phoneNumber,
    String? passwordHint,
    OrganizationData? organization,
    bool? existingChannelsFound,
  }) {
    return TelegramSetupState(
      authState: authState ?? this.authState,
      setupStep: setupStep ?? this.setupStep,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      qrCodeLink: clearQrCode ? null : (qrCodeLink ?? this.qrCodeLink),
      phoneNumber: phoneNumber ?? this.phoneNumber,
      passwordHint: passwordHint ?? this.passwordHint,
      organization: organization ?? this.organization,
      existingChannelsFound:
          existingChannelsFound ?? this.existingChannelsFound,
    );
  }
}

enum TelegramSetupStep {
  initializing,

  nativeLibraryNotFound,

  auth,

  code,

  password,

  registration,

  searchingChannels,

  loadingOrganization,

  organizationSetup,

  creatingChannels,

  keyExchange,

  complete,
}

class TelegramSetupNotifier extends Notifier<TelegramSetupState> {
  TelegramInitializer? _initializer;
  TelegramAuthService? _authService;
  AutoSetupService? _autoSetupService;
  AutoChannelCreator? _channelCreator;
  TdLibClient? _tdLibClient;
  ChannelRegistry? _channelRegistry;
  StreamSubscription<TelegramAuthState>? _authSubscription;
  StreamSubscription<TelegramInitStatus>? _initSubscription;

  @override
  TelegramSetupState build() {
    if (GetIt.I.isRegistered<TelegramInitializer>()) {
      _initializer = GetIt.I<TelegramInitializer>();
      _subscribeToInitStatus();
    }
    if (GetIt.I.isRegistered<TelegramAuthService>()) {
      _authService = GetIt.I<TelegramAuthService>();
      _subscribeToAuthState();
    }
    if (GetIt.I.isRegistered<AutoSetupService>()) {
      _autoSetupService = GetIt.I<AutoSetupService>();
    }
    if (GetIt.I.isRegistered<AutoChannelCreator>()) {
      _channelCreator = GetIt.I<AutoChannelCreator>();
    }
    if (GetIt.I.isRegistered<TdLibClient>()) {
      _tdLibClient = GetIt.I<TdLibClient>();
    }
    if (GetIt.I.isRegistered<ChannelRegistry>()) {
      _channelRegistry = GetIt.I<ChannelRegistry>();
    }

    ref.onDispose(() {
      _authSubscription?.cancel();
      _initSubscription?.cancel();
    });

    return const TelegramSetupState(setupStep: TelegramSetupStep.initializing);
  }

  void _subscribeToInitStatus() {
    _initSubscription?.cancel();
    _initSubscription = _initializer?.statusStream.listen(
      _handleInitStatusChange,
    );
  }

  void _handleInitStatusChange(TelegramInitStatus status) {
    switch (status) {
      case TelegramInitStatus.notInitialized:
      case TelegramInitStatus.initializingTdLib:
        state = state.copyWith(
          setupStep: TelegramSetupStep.initializing,
          isLoading: true,
          clearError: true,
        );

      case TelegramInitStatus.nativeLibraryNotFound:
        state = state.copyWith(
          setupStep: TelegramSetupStep.nativeLibraryNotFound,
          isLoading: false,
          error: _initializer?.lastError ?? 'TDLib native library not found',
        );

      case TelegramInitStatus.readyForAuth:
        state = state.copyWith(
          setupStep: TelegramSetupStep.auth,
          isLoading: false,
          clearError: true,
        );

      case TelegramInitStatus.ready:
        state = state.copyWith(
          setupStep: TelegramSetupStep.complete,
          isLoading: false,
        );

      case TelegramInitStatus.error:
        state = state.copyWith(
          isLoading: false,
          error: _initializer?.lastError ?? 'Initialization error',
        );
    }
  }

  Future<void> startInitialization() async {
    final initializer = _initializer;
    if (initializer == null) {
      state = state.copyWith(error: 'error.telegram_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    await initializer.initialize();
  }

  void _subscribeToAuthState() {
    _authSubscription?.cancel();
    _authSubscription = _authService?.stateStream.listen(
      _handleAuthStateChange,
    );
  }

  void _handleAuthStateChange(TelegramAuthState authState) {
    switch (authState) {
      case TelegramAuthStateInitial():
      case TelegramAuthStateWaitingPhoneNumber():
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.auth,
          clearError: true,
        );

      case TelegramAuthStateWaitingCode(:final phoneNumber):
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.code,
          phoneNumber: phoneNumber,
          clearError: true,
        );

      case TelegramAuthStateWaitingQrCode(:final qrCodeLink):
        state = state.copyWith(
          authState: authState,
          qrCodeLink: qrCodeLink,
          clearError: true,
        );

      case TelegramAuthStateWaitingPassword(:final passwordHint):
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.password,
          passwordHint: passwordHint,
          clearError: true,
        );

      case TelegramAuthStateWaitingRegistration():
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.registration,
          clearError: true,
        );

      case TelegramAuthStateAuthorized():
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.complete,
          isLoading: false,
        );

      case TelegramAuthStateError(:final message):
        state = state.copyWith(
          authState: authState,
          error: message,
          isLoading: false,
        );

      case TelegramAuthStateLoggedOut():
        state = state.copyWith(
          authState: authState,
          setupStep: TelegramSetupStep.auth,
          clearError: true,
        );

      default:
        state = state.copyWith(authState: authState);
    }
  }

  Future<void> startPhoneAuth(String countryCode, String phone) async {
    final authService = _authService;
    if (authService == null) {
      state = state.copyWith(error: 'error.telegram_auth_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final fullPhone = '$countryCode$phone'.replaceAll(RegExp(r'[^0-9+]'), '');
      await authService.startPhoneAuth(fullPhone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.phone_send_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> startQrAuth() async {
    final authService = _authService;
    if (authService == null) {
      state = state.copyWith(error: 'error.telegram_auth_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await authService.startQrAuth();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.qr_auth_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> submitCode(String code) async {
    final authService = _authService;
    if (authService == null) {
      state = state.copyWith(error: 'error.telegram_auth_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await authService.submitCode(code);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.wrong_code:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> submitPassword(String password) async {
    final authService = _authService;
    if (authService == null) {
      state = state.copyWith(error: 'error.telegram_auth_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await authService.submitPassword(password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.wrong_password:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> register(String firstName, String? lastName) async {
    final authService = _authService;
    if (authService == null) {
      state = state.copyWith(error: 'error.telegram_auth_not_initialized');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await authService.register(firstName: firstName, lastName: lastName);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'error.registration_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  // ignore: unused_element - вызывается после авторизации, flow пока не подключен
  Future<void> _startAutoSetup(TelegramAuthStateAuthorized authState) async {
    state = state.copyWith(
      authState: authState,
      setupStep: TelegramSetupStep.searchingChannels,
      isLoading: true,
      clearError: true,
    );

    try {
      final channelCreator = _channelCreator;
      if (channelCreator == null) {
        state = state.copyWith(
          setupStep: TelegramSetupStep.organizationSetup,
          isLoading: false,
        );
        return;
      }

      final existingChannels = await _searchForAnyExistingChannels();

      if (existingChannels.isNotEmpty) {
        state = state.copyWith(
          setupStep: TelegramSetupStep.loadingOrganization,
          existingChannelsFound: true,
        );

        final orgData = await _loadOrganizationFromBackup(
          existingChannels.first,
        );

        if (orgData != null) {
          state = state.copyWith(organization: orgData);
          await _completeSetupWithExistingChannels(existingChannels, orgData);
        } else {
          state = state.copyWith(
            setupStep: TelegramSetupStep.organizationSetup,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          setupStep: TelegramSetupStep.organizationSetup,
          existingChannelsFound: false,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: 'error.channel_search_failed:${safeErrorText(e)}',
        setupStep: TelegramSetupStep.organizationSetup,
        isLoading: false,
      );
    }
  }

  Future<List<dynamic>> _searchForAnyExistingChannels() async {
    final client = _tdLibClient;
    if (client == null) return [];

    try {
      final result = await client.sendSync({
        '@type': 'searchChatsOnServer',
        'query': 'POS-',
        'limit': 50,
      });

      final chatIds = result['chat_ids'] as List? ?? [];
      final channels = <Map<String, dynamic>>[];

      for (final chatId in chatIds) {
        try {
          final chatInfo = await client.getChat(chatId as int);
          final title = chatInfo['title'] as String? ?? '';

          if (title.contains('POS-System') || title.contains('POS-Backup')) {
            channels.add({'chatId': chatId, 'title': title});
          }
        } catch (_) {}
      }

      return channels;
    } catch (e) {
      return [];
    }
  }

  Future<OrganizationData?> _loadOrganizationFromBackup(
    Map<String, dynamic> backupChannel,
  ) async {
    final client = _tdLibClient;
    if (client == null) return null;

    try {
      final chatId = backupChannel['chatId'] as int;

      final messages = await client.sendSync({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'limit': 50,
        'from_message_id': 0,
      });

      final messageList = messages['messages'] as List? ?? [];

      for (final msg in messageList) {
        final content = msg['content'];
        if (content == null) continue;

        final text = content['text']?['text'] as String? ?? '';

        if (text.startsWith('__TELEPOS_ORG_CONFIG__:')) {
          final jsonStr = text.substring('__TELEPOS_ORG_CONFIG__:'.length);
          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            return OrganizationData.fromJson(data);
          } catch (_) {}
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _completeSetupWithExistingChannels(
    List<dynamic> channels,
    OrganizationData orgData,
  ) async {
    state = state.copyWith(setupStep: TelegramSetupStep.creatingChannels);

    try {
      final channelCreator = _channelCreator;
      if (channelCreator != null && orgData.storeName != null) {
        final existingChannels = await channelCreator.findExistingChannels(
          orgData.storeName!,
        );
        await channelCreator.joinExistingChannels(existingChannels);
      }

      state = state.copyWith(setupStep: TelegramSetupStep.keyExchange);

      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
        setupStep: TelegramSetupStep.complete,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'error.channel_connect_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> submitOrganizationData({
    required String storeName,
    required String bin,
    String? address,
    String? posId,
    String? ownerName,
  }) async {
    final orgData = OrganizationData(
      storeName: storeName,
      bin: bin,
      address: address,
      posId: posId ?? 'POS-1',
      ownerName: ownerName,
    );

    state = state.copyWith(
      organization: orgData,
      setupStep: TelegramSetupStep.creatingChannels,
      isLoading: true,
      clearError: true,
    );

    try {
      final autoSetup = _autoSetupService;
      if (autoSetup != null) {
        await autoSetup.startSetup(
          storeName: storeName,
          posId: posId ?? 'POS-1',
        );
      }

      await _saveOrganizationToBackup(orgData);

      state = state.copyWith(
        setupStep: TelegramSetupStep.complete,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'error.channel_create_failed:${safeErrorText(e)}',
        isLoading: false,
      );
    }
  }

  Future<void> _saveOrganizationToBackup(OrganizationData orgData) async {
    final client = _tdLibClient;
    final registry = _channelRegistry;
    if (client == null || registry == null) return;

    try {
      final backupChannel = registry.get(SystemChannelType.posDataExchange);
      if (backupChannel == null) return;

      final configJson = jsonEncode(orgData.toJson());
      final message = '__TELEPOS_ORG_CONFIG__:$configJson';

      await client.sendSync({
        '@type': 'sendMessage',
        'chat_id': backupChannel.chatId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {'@type': 'formattedText', 'text': message},
        },
      });
    } catch (e) {}
  }

  void goBack() {
    state = state.copyWith(
      setupStep: TelegramSetupStep.auth,
      clearError: true,
      clearQrCode: true,
    );
  }

  void reset() {
    state = const TelegramSetupState();
  }
}

final telegramSetupControllerProvider =
    NotifierProvider<TelegramSetupNotifier, TelegramSetupState>(
      TelegramSetupNotifier.new,
    );
