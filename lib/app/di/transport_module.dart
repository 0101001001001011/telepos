import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import '../../domain/repositories/transport_repository.dart';
import '../../data/repositories/transport_repository_impl.dart';
import '../../telegram/channels/channel_manager.dart';
import '../../telegram/channels/channel_registry.dart';
import '../../telegram/core/tdlib_client.dart';
import '../../telegram/data_exchange/telegram_sync_engine.dart';
import '../../telegram/messaging/media_service.dart';
import '../../telegram/messaging/message_service.dart';
import '../../telegram/messaging/realtime_updates.dart';
import '../../telegram/notifications/notification_service.dart';
import '../../telegram/reports/report_sender.dart';
import '../../transport/transport_exports.dart';

class TransportModule {
  TransportModule._();

  static Future<void> register(
    GetIt getIt, {
    required Talker logger,
    required String dataDir,
  }) async {
    getIt.registerLazySingleton<SettingsStorage>(
      () => SettingsStorageImpl.defaultPath(dataDir),
    );

    getIt.registerLazySingleton<SettingsManager>(
      () => SettingsManager(getIt<SettingsStorage>()),
    );

    getIt.registerLazySingleton<QueueStorage>(
      () => QueueStorageImpl.defaultPath(dataDir),
    );

    getIt.registerLazySingleton<OfflineQueue>(
      () => OfflineQueue(
        storage: getIt<QueueStorage>(),
        logger: (msg) => logger.debug(msg),
      ),
    );

    getIt.registerLazySingleton<TransportConfig>(() {
      return TransportConfig.restOnly(
        RestTransportConfig(baseUrl: 'https://api.telepos.example.com'),
      );
    });

    getIt.registerLazySingleton<TelegramTransport>(
      () => TelegramTransportImpl(
        tdLibClient: getIt<TdLibClient>(),
        syncEngine: getIt<TelegramSyncEngine>(),
        notificationService: getIt<NotificationService>(),
        messageService: getIt<MessageService>(),
        channelManager: getIt<ChannelManager>(),
        channelRegistry: getIt<ChannelRegistry>(),
        mediaService: getIt<MediaService>(),
        reportSender: getIt<ReportSender>(),
        realtimeUpdates: getIt<RealtimeUpdates>(),
      ),
    );

    getIt.registerLazySingleton<RestTransport>(() {
      final config = getIt<TransportConfig>().rest;
      return RestTransportImpl.withConfig(
        baseUrl: config?.baseUrl ?? 'https://api.telepos.example.com',
        timeout: config?.timeout ?? const Duration(seconds: 30),
      );
    });

    getIt.registerLazySingleton<FallbackHandler>(
      () => FallbackHandler(
        logger: (msg) => logger.debug(msg),
        onEvent: (event) => logger.info('Fallback event: $event'),
      ),
    );

    getIt.registerLazySingleton<ParallelExecutor>(() => ParallelExecutor());

    getIt.registerLazySingleton<TransportCoordinator>(() {
      final config = getIt<TransportConfig>();

      return TransportCoordinator(
        config: config,
        telegram: config.hasTelegram ? getIt<TelegramTransport>() : null,
        rest: config.hasRest ? getIt<RestTransport>() : null,
      );
    });

    getIt.registerLazySingleton<TransportRepository>(
      () => TransportRepositoryImpl(
        coordinator: getIt<TransportCoordinator>(),
        queue: getIt<OfflineQueue>(),
        logger: logger,
      ),
    );

    await _initialize(getIt, logger);
  }

  static Future<void> _initialize(GetIt getIt, Talker logger) async {
    try {
      final settingsManager = getIt<SettingsManager>();
      await settingsManager.initialize();
      logger.debug('[TransportModule] Settings manager initialized');

      final queue = getIt<OfflineQueue>();
      await queue.initialize();
      logger.debug('[TransportModule] Offline queue initialized');

      final repository = getIt<TransportRepository>();
      await repository.initialize();
      logger.debug('[TransportModule] Transport repository initialized');

      logger.info('[TransportModule] All transport components initialized');
    } catch (e, st) {
      logger.error('[TransportModule] Initialization failed', e, st);
      rethrow;
    }
  }

  static Future<void> dispose(GetIt getIt) async {
    await getIt<TransportRepository>().dispose();
    await getIt<OfflineQueue>().dispose();
    await getIt<FallbackHandler>().dispose();
    getIt<SettingsManager>().dispose();
  }
}

extension TransportGetItExtension on GetIt {
  TransportCoordinator get transportCoordinator => get<TransportCoordinator>();
  TransportRepository get transportRepository => get<TransportRepository>();
  OfflineQueue get offlineQueue => get<OfflineQueue>();
  SettingsManager get transportSettings => get<SettingsManager>();
}
