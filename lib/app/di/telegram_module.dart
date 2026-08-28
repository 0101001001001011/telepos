import 'package:get_it/get_it.dart';
import 'package:telepos/data/repositories/telegram_repository_impl.dart';
import 'package:telepos/domain/repositories/telegram_repository.dart';
import 'package:telepos/telegram/auth/identity_verification_handler.dart';
import 'package:telepos/telegram/auth/phone_auth_handler.dart';
import 'package:telepos/telegram/auth/qr_auth_handler.dart';
import 'package:telepos/telegram/auth/telegram_auth_service.dart';
import 'package:telepos/telegram/auth/two_factor_handler.dart';
import 'package:telepos/telegram/automation/auto_bot_deployer.dart';
import 'package:telepos/telegram/automation/auto_channel_creator.dart';
import 'package:telepos/telegram/automation/auto_group_manager.dart';
import 'package:telepos/telegram/automation/auto_setup_service.dart';
import 'package:telepos/telegram/automation/provisioning_service.dart';
import 'package:telepos/telegram/bots/bot_command_router.dart';
import 'package:telepos/telegram/bots/bot_manager.dart';
import 'package:telepos/telegram/bots/bot_webhook_handler.dart';
import 'package:telepos/telegram/bots/pos_bot_commands.dart';
import 'package:telepos/telegram/channels/auto_channel_factory.dart';
import 'package:telepos/telegram/channels/channel_manager.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/core/tdlib_client.dart';
import 'package:telepos/telegram/core/tdlib_event_loop.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/core/tdlib_session_manager.dart';
import 'package:telepos/telegram/core/telegram_credentials.dart';
import 'package:telepos/telegram/core/telegram_initializer.dart';
import 'package:telepos/telegram/data_exchange/chunk_transfer_service.dart';
import 'package:telepos/telegram/data_exchange/conflict_resolver.dart';
import 'package:telepos/telegram/data_exchange/data_packer.dart';
import 'package:telepos/telegram/data_exchange/data_unpacker.dart';
import 'package:telepos/telegram/data_exchange/telegram_sync_engine.dart';
import 'package:telepos/telegram/encryption/data_encryption_service.dart';
import 'package:telepos/telegram/encryption/e2e_encryption_service.dart';
import 'package:telepos/telegram/encryption/encryption_key_store.dart';
import 'package:telepos/telegram/encryption/key_exchange_service.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/telegram/integrations/erp_bridge.dart';
import 'package:telepos/telegram/integrations/multi_pos_bridge.dart';
import 'package:telepos/telegram/integrations/one_c_bridge.dart';
import 'package:telepos/telegram/integrations/server_bridge.dart';
import 'package:telepos/telegram/internal_chat/chat_history_service.dart';
import 'package:telepos/telegram/internal_chat/chat_permissions.dart';
import 'package:telepos/telegram/internal_chat/chat_room_manager.dart';
import 'package:telepos/telegram/internal_chat/staff_chat_service.dart';
import 'package:telepos/telegram/internal_chat/staff_identity_service.dart';
import 'package:telepos/telegram/messaging/media_service.dart';
import 'package:telepos/telegram/messaging/message_formatter.dart';
import 'package:telepos/telegram/messaging/message_queue.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/telegram/messaging/realtime_updates.dart';
import 'package:telepos/telegram/monitoring/dashboard_feed.dart';
import 'package:telepos/telegram/monitoring/health_reporter.dart';
import 'package:telepos/telegram/monitoring/metrics_collector.dart';
import 'package:telepos/telegram/monitoring/pos_status_service.dart';
import 'package:telepos/telegram/notifications/notification_router.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';
import 'package:telepos/telegram/notifications/notification_templates.dart';
import 'package:telepos/telegram/reports/report_generator.dart';
import 'package:telepos/telegram/reports/report_scheduler.dart';
import 'package:telepos/telegram/reports/report_sender.dart';
import 'package:telepos/telegram/backup/telegram_backup_service.dart';

class TelegramModule {
  static void register(
    GetIt getIt, {
    required String sessionsDir,
    required String registryPath,
    required String queuePath,
  }) {
    getIt.registerLazySingleton<TdLibLogger>(() => TdLibLogger());

    getIt.registerLazySingleton<TdLibClient>(
      () => TdLibClient(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<TdLibEventLoop>(
      () => TdLibEventLoop(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<TdLibSessionManager>(
      () => TdLibSessionManager(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
        sessionsDir: sessionsDir,
      ),
    );

    getIt.registerLazySingleton<TelegramCredentials>(
      () => TelegramCredentials(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<TelegramInitializer>(
      () => TelegramInitializer(
        client: getIt<TdLibClient>(),
        eventLoop: getIt<TdLibEventLoop>(),
        credentials: getIt<TelegramCredentials>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<EncryptionKeyStore>(
      () => EncryptionKeyStore(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<DataEncryptionService>(
      () => DataEncryptionService(
        keyStore: getIt<EncryptionKeyStore>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<KeyExchangeService>(
      () => KeyExchangeService(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
        keyStore: getIt<EncryptionKeyStore>(),
      ),
    );

    getIt.registerLazySingleton<E2EEncryptionService>(
      () => E2EEncryptionService(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<TelegramAuthService>(
      () => TelegramAuthService(
        client: getIt<TdLibClient>(),
        eventLoop: getIt<TdLibEventLoop>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<PhoneAuthHandler>(
      () => PhoneAuthHandler(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<QrAuthHandler>(
      () => QrAuthHandler(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<TwoFactorHandler>(
      () => TwoFactorHandler(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<IdentityVerificationHandler>(
      () => IdentityVerificationHandler(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChannelManager>(
      () => ChannelManager(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChannelRegistry>(
      () => ChannelRegistry(
        logger: getIt<TdLibLogger>(),
        registryPath: registryPath,
      ),
    );

    getIt.registerLazySingleton<AutoChannelFactory>(
      () => AutoChannelFactory(
        channelManager: getIt<ChannelManager>(),
        registry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<BotManager>(
      () => BotManager(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<BotCommandRouter>(
      () => BotCommandRouter(
        client: getIt<TdLibClient>(),
        eventLoop: getIt<TdLibEventLoop>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<BotWebhookHandler>(
      () => BotWebhookHandler(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<MessageService>(
      () => MessageService(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<MediaService>(
      () => MediaService(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<RealtimeUpdates>(
      () => RealtimeUpdates(
        eventLoop: getIt<TdLibEventLoop>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<MessageQueue>(
      () => MessageQueue(
        messageService: getIt<MessageService>(),
        logger: getIt<TdLibLogger>(),
        persistPath: queuePath,
      ),
    );

    getIt.registerLazySingleton<MessageFormatter>(
      () => const MessageFormatter(),
    );

    getIt.registerLazySingleton<DataPacker>(
      () => DataPacker(
        encryption: getIt<DataEncryptionService>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<DataUnpacker>(
      () => DataUnpacker(
        encryption: getIt<DataEncryptionService>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChunkTransferService>(
      () => ChunkTransferService(
        messageService: getIt<MessageService>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ConflictResolver>(
      () => ConflictResolver(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<TelegramSyncEngine>(
      () => TelegramSyncEngine(
        messageService: getIt<MessageService>(),
        packer: getIt<DataPacker>(),
        unpacker: getIt<DataUnpacker>(),
        chunkTransfer: getIt<ChunkTransferService>(),
        conflictResolver: getIt<ConflictResolver>(),
        encryption: getIt<DataEncryptionService>(),
        channelRegistry: getIt<ChannelRegistry>(),
        realtimeUpdates: getIt<RealtimeUpdates>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<NotificationRouter>(() => NotificationRouter());

    getIt.registerLazySingleton<NotificationTemplates>(
      () => NotificationTemplates(),
    );

    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(
        messageService: getIt<MessageService>(),
        messageQueue: getIt<MessageQueue>(),
        channelRegistry: getIt<ChannelRegistry>(),
        router: getIt<NotificationRouter>(),
        templates: getIt<NotificationTemplates>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<StaffChatService>(
      () => StaffChatService(
        messageService: getIt<MessageService>(),
        mediaService: getIt<MediaService>(),
        realtimeUpdates: getIt<RealtimeUpdates>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChatRoomManager>(
      () => ChatRoomManager(
        channelManager: getIt<ChannelManager>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChatPermissions>(
      () => ChatPermissions(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ChatHistoryService>(
      () => ChatHistoryService(
        client: getIt<TdLibClient>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<StaffIdentityService>(
      () => StaffIdentityService(
        db: getIt<AppDatabase>(),
        chatService: getIt<StaffChatService>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<MetricsCollector>(
      () => MetricsCollector(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<PosStatusService>(
      () => PosStatusService(
        messageService: getIt<MessageService>(),
        channelRegistry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<HealthReporter>(
      () => HealthReporter(
        messageService: getIt<MessageService>(),
        channelRegistry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<DashboardFeed>(
      () => DashboardFeed(
        messageService: getIt<MessageService>(),
        metricsCollector: getIt<MetricsCollector>(),
        channelRegistry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ReportGenerator>(
      () => ReportGenerator(logger: getIt<TdLibLogger>()),
    );

    getIt.registerLazySingleton<ReportSender>(
      () => ReportSender(
        messageService: getIt<MessageService>(),
        mediaService: getIt<MediaService>(),
        channelRegistry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ReportScheduler>(
      () => ReportScheduler(
        generator: getIt<ReportGenerator>(),
        sender: getIt<ReportSender>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<AutoChannelCreator>(
      () => AutoChannelCreator(
        client: getIt<TdLibClient>(),
        factory: getIt<AutoChannelFactory>(),
        registry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<AutoBotDeployer>(
      () => AutoBotDeployer(
        botManager: getIt<BotManager>(),
        commandRouter: getIt<BotCommandRouter>(),
        channelRegistry: getIt<ChannelRegistry>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<AutoGroupManager>(
      () => AutoGroupManager(
        channelManager: getIt<ChannelManager>(),
        chatPermissions: getIt<ChatPermissions>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<AutoSetupService>(
      () => AutoSetupService(
        authService: getIt<TelegramAuthService>(),
        channelCreator: getIt<AutoChannelCreator>(),
        botDeployer: getIt<AutoBotDeployer>(),
        keyExchange: getIt<KeyExchangeService>(),
        logger: getIt<TdLibLogger>(),
      ),
    );

    getIt.registerLazySingleton<ProvisioningService>(
      () => ProvisioningService(
        channelFactory: getIt<AutoChannelFactory>(),
        setupService: getIt<AutoSetupService>(),
        logger: getIt<TdLibLogger>(),
        channelManager: getIt<ChannelManager>(),
        channelRegistry: getIt<ChannelRegistry>(),
        keyStore: getIt<EncryptionKeyStore>(),
      ),
    );

    getIt.registerLazySingleton<TelegramBackupService>(
      () => TelegramBackupService(
        client: getIt<TdLibClient>(),
        messageService: getIt<MessageService>(),
        channelRegistry: getIt<ChannelRegistry>(),
        encryption: getIt<DataEncryptionService>(),
        logger: getIt<TdLibLogger>(),
        databasePath: '',
      ),
    );

    getIt.registerLazySingleton<TelegramRepository>(
      () => TelegramRepositoryImpl(
        authService: getIt<TelegramAuthService>(),
        syncEngine: getIt<TelegramSyncEngine>(),
        notificationService: getIt<NotificationService>(),
        staffChatService: getIt<StaffChatService>(),
        realtimeUpdates: getIt<RealtimeUpdates>(),
        channelRegistry: getIt<ChannelRegistry>(),
        keyStore: getIt<EncryptionKeyStore>(),
      ),
    );

    getIt.registerLazySingleton<PosBotCommands>(
      () => PosBotCommands(
        router: getIt<BotCommandRouter>(),
        logger: getIt<TdLibLogger>(),
        syncEngine: getIt<TelegramSyncEngine>(),
        reportGenerator: getIt<ReportGenerator>(),
        posStatusService: getIt<PosStatusService>(),
      ),
    );

    getIt.registerLazySingleton<BridgeFactory>(
      () => BridgeFactory(
        syncEngine: getIt<TelegramSyncEngine>(),
        realtimeUpdates: getIt<RealtimeUpdates>(),
        logger: getIt<TdLibLogger>(),
      ),
    );
  }
}

class BridgeFactory {
  final TelegramSyncEngine _syncEngine;
  final RealtimeUpdates _realtimeUpdates;
  final TdLibLogger _logger;

  BridgeFactory({
    required TelegramSyncEngine syncEngine,
    required RealtimeUpdates realtimeUpdates,
    required TdLibLogger logger,
  }) : _syncEngine = syncEngine,
       _realtimeUpdates = realtimeUpdates,
       _logger = logger;

  ServerBridge createServerBridge({
    required String posId,
    required String serverId,
    required String sessionId,
  }) {
    return ServerBridge(
      syncEngine: _syncEngine,
      realtimeUpdates: _realtimeUpdates,
      logger: _logger,
      posId: posId,
      serverId: serverId,
      sessionId: sessionId,
    );
  }

  OneCBridge createOneCBridge({
    required String posId,
    required String oneCId,
    required String sessionId,
  }) {
    return OneCBridge(
      syncEngine: _syncEngine,
      logger: _logger,
      posId: posId,
      oneCId: oneCId,
      sessionId: sessionId,
    );
  }

  MultiPosBridge createMultiPosBridge({
    required String posId,
    required String sessionId,
  }) {
    return MultiPosBridge(
      syncEngine: _syncEngine,
      logger: _logger,
      posId: posId,
      sessionId: sessionId,
    );
  }

  ErpBridge createErpBridge({
    required String posId,
    required String erpId,
    required String erpName,
    required String sessionId,
  }) {
    return ErpBridge(
      syncEngine: _syncEngine,
      logger: _logger,
      posId: posId,
      erpId: erpId,
      erpName: erpName,
      sessionId: sessionId,
    );
  }
}
