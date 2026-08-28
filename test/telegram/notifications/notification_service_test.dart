import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:telepos/telegram/channels/channel_registry.dart';
import 'package:telepos/telegram/channels/channel_types.dart';
import 'package:telepos/telegram/core/tdlib_logger.dart';
import 'package:telepos/telegram/messaging/message_queue.dart';
import 'package:telepos/telegram/messaging/message_service.dart';
import 'package:telepos/domain/entities/telegram/notification_payload.dart';
import 'package:telepos/domain/entities/telegram/telegram_message.dart';
import 'package:telepos/telegram/notifications/notification_router.dart';
import 'package:telepos/telegram/notifications/notification_service.dart';
import 'package:telepos/telegram/notifications/notification_templates.dart';

class MockMessageService extends Mock implements MessageService {}

class MockMessageQueue extends Mock implements MessageQueue {}

class MockChannelRegistry extends Mock implements ChannelRegistry {}

class MockNotificationRouter extends Mock implements NotificationRouter {}

class MockNotificationTemplates extends Mock implements NotificationTemplates {}

class MockTdLibLogger extends Mock implements TdLibLogger {}

class FakeQueuedMessage extends Fake implements QueuedMessage {}

class FakeChannelRegistry extends Fake implements ChannelRegistry {}

class FakeNotificationPayload extends Fake implements NotificationPayload {}

void main() {
  late NotificationService notificationService;
  late MockMessageService mockMessageService;
  late MockMessageQueue mockMessageQueue;
  late MockChannelRegistry mockChannelRegistry;
  late MockNotificationRouter mockRouter;
  late MockNotificationTemplates mockTemplates;
  late MockTdLibLogger mockLogger;

  setUpAll(() {
    registerFallbackValue(FakeQueuedMessage());
    registerFallbackValue(FakeChannelRegistry());
    registerFallbackValue(FakeNotificationPayload());
    registerFallbackValue(NotificationType.sale);
    registerFallbackValue(SystemChannelType.posAlerts);
  });

  setUp(() {
    mockMessageService = MockMessageService();
    mockMessageQueue = MockMessageQueue();
    mockChannelRegistry = MockChannelRegistry();
    mockRouter = MockNotificationRouter();
    mockTemplates = MockNotificationTemplates();
    mockLogger = MockTdLibLogger();

    notificationService = NotificationService(
      messageService: mockMessageService,
      messageQueue: mockMessageQueue,
      channelRegistry: mockChannelRegistry,
      router: mockRouter,
      templates: mockTemplates,
      logger: mockLogger,
    );
  });

  NotificationPayload createTestNotification({
    String notificationId = 'test-notification-1',
    NotificationType type = NotificationType.sale,
    NotificationPriority priority = NotificationPriority.normal,
    String title = 'Test Notification',
    String body = 'This is a test notification body',
    String posId = 'POS-001',
    String? storeName,
    DateTime? timestamp,
    int? targetChatId,
    bool isSilent = false,
  }) {
    return NotificationPayload(
      notificationId: notificationId,
      type: type,
      priority: priority,
      title: title,
      body: body,
      posId: posId,
      storeName: storeName,
      timestamp: timestamp ?? DateTime.now(),
      targetChatId: targetChatId,
      isSilent: isSilent,
    );
  }

  TelegramMessage createMockMessage({int messageId = 12345, int chatId = 100}) {
    return TelegramMessage(
      messageId: messageId,
      chatId: chatId,
      senderId: 200,
      direction: MessageDirection.outgoing,
      contentType: MessageContentType.text,
      text: 'Test message',
      date: DateTime.now(),
    );
  }

  group('NotificationService', () {
    group('isEnabled', () {
      test('returns true by default', () {
        expect(notificationService.isEnabled, isTrue);
      });

      test('returns false after disable() is called', () {
        notificationService.disable();
        expect(notificationService.isEnabled, isFalse);
      });

      test('returns true after enable() is called', () {
        notificationService.disable();
        notificationService.enable();
        expect(notificationService.isEnabled, isTrue);
      });
    });

    group('enable()', () {
      test('sets isEnabled to true', () {
        notificationService.disable();
        notificationService.enable();
        expect(notificationService.isEnabled, isTrue);
      });

      test('logs connection event', () {
        notificationService.enable();
        verify(
          () => mockLogger.logConnection('Notifications enabled'),
        ).called(1);
      });
    });

    group('disable()', () {
      test('sets isEnabled to false', () {
        notificationService.disable();
        expect(notificationService.isEnabled, isFalse);
      });

      test('logs connection event', () {
        notificationService.disable();
        verify(
          () => mockLogger.logConnection('Notifications disabled'),
        ).called(1);
      });
    });

    group('send()', () {
      test('does not send when notifications are disabled', () async {
        notificationService.disable();
        final notification = createTestNotification();

        await notificationService.send(notification);

        verifyNever(() => mockMessageService.sendText(any(), any()));
        verifyNever(() => mockMessageService.sendSilent(any(), any()));
      });

      test('uses targetChatId from notification when provided', () async {
        const targetChatId = 999;
        final notification = createTestNotification(targetChatId: targetChatId);
        const formattedMessage = 'Formatted message';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(1);
        verifyNever(() => mockRouter.resolveChannel(any(), any()));
      });

      test(
        'uses router to resolve channel when targetChatId is null',
        () async {
          const resolvedChatId = 888;
          final notification = createTestNotification(targetChatId: null);
          const formattedMessage = 'Formatted message';

          when(
            () => mockRouter.resolveChannel(
              notification.type,
              mockChannelRegistry,
            ),
          ).thenReturn(resolvedChatId);
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(resolvedChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

          await notificationService.send(notification);

          verify(
            () => mockRouter.resolveChannel(
              notification.type,
              mockChannelRegistry,
            ),
          ).called(1);
          verify(
            () => mockMessageService.sendText(resolvedChatId, formattedMessage),
          ).called(1);
        },
      );

      test('logs error when no target channel is found', () async {
        final notification = createTestNotification(
          targetChatId: null,
          type: NotificationType.sale,
        );

        when(() => mockRouter.resolveChannel(any(), any())).thenReturn(null);

        await notificationService.send(notification);

        verify(
          () => mockLogger.logError(
            'send',
            'No target channel for notification: sale',
          ),
        ).called(1);
        verifyNever(() => mockMessageService.sendText(any(), any()));
      });

      test('formats notification using templates', () async {
        const targetChatId = 777;
        final notification = createTestNotification(targetChatId: targetChatId);
        const formattedMessage = 'Custom formatted message with icons';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        verify(() => mockTemplates.format(notification)).called(1);
        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(1);
      });

      test('sends silent message when notification.isSilent is true', () async {
        const targetChatId = 666;
        final notification = createTestNotification(
          targetChatId: targetChatId,
          isSilent: true,
        );
        const formattedMessage = 'Silent message';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendSilent(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        verify(
          () => mockMessageService.sendSilent(targetChatId, formattedMessage),
        ).called(1);
        verifyNever(() => mockMessageService.sendText(any(), any()));
      });

      test(
        'sends regular message when notification.isSilent is false',
        () async {
          const targetChatId = 555;
          final notification = createTestNotification(
            targetChatId: targetChatId,
            isSilent: false,
          );
          const formattedMessage = 'Regular message';

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

          await notificationService.send(notification);

          verify(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).called(1);
          verifyNever(() => mockMessageService.sendSilent(any(), any()));
        },
      );

      test('logs success when notification is sent', () async {
        const targetChatId = 444;
        final notification = createTestNotification(
          targetChatId: targetChatId,
          type: NotificationType.shift,
        );
        const formattedMessage = 'Success message';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        verify(
          () => mockLogger.logConnection(
            'Notification sent: shift \u2192 chat=$targetChatId',
          ),
        ).called(1);
      });

      group('error handling', () {
        test('enqueues message when send fails', () async {
          const targetChatId = 333;
          final notification = createTestNotification(
            notificationId: 'error-test-id',
            targetChatId: targetChatId,
            isSilent: false,
          );
          const formattedMessage = 'Failed message';

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenThrow(Exception('Network error'));
          when(() => mockMessageQueue.enqueue(any())).thenReturn(null);

          await notificationService.send(notification);

          final captured = verify(
            () => mockMessageQueue.enqueue(captureAny()),
          ).captured;
          final queuedMessage = captured.first as QueuedMessage;

          expect(queuedMessage.id, 'error-test-id');
          expect(queuedMessage.chatId, targetChatId);
          expect(queuedMessage.text, formattedMessage);
          expect(queuedMessage.isSilent, false);
        });

        test('enqueues silent message with isSilent flag', () async {
          const targetChatId = 222;
          final notification = createTestNotification(
            notificationId: 'silent-error-id',
            targetChatId: targetChatId,
            isSilent: true,
          );
          const formattedMessage = 'Silent failed message';

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendSilent(targetChatId, formattedMessage),
          ).thenThrow(Exception('Connection timeout'));
          when(() => mockMessageQueue.enqueue(any())).thenReturn(null);

          await notificationService.send(notification);

          final captured = verify(
            () => mockMessageQueue.enqueue(captureAny()),
          ).captured;
          final queuedMessage = captured.first as QueuedMessage;

          expect(queuedMessage.isSilent, true);
        });

        test('logs error when send fails', () async {
          const targetChatId = 111;
          final notification = createTestNotification(
            targetChatId: targetChatId,
          );
          const formattedMessage = 'Error log test';
          final exception = Exception('Test error');

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenThrow(exception);
          when(() => mockMessageQueue.enqueue(any())).thenReturn(null);

          await notificationService.send(notification);

          verify(
            () =>
                mockLogger.logError('send', 'Notification queued: $exception'),
          ).called(1);
        });
      });
    });

    group('rate limiting', () {
      test('allows notifications within rate limit', () async {
        const targetChatId = 500;
        const formattedMessage = 'Rate limit test';

        for (var i = 0; i < 5; i++) {
          final notification = createTestNotification(
            notificationId: 'rate-test-$i',
            targetChatId: targetChatId,
            type: NotificationType.sale,
          );

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

          await notificationService.send(notification);
        }

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(5);
      });

      test(
        'blocks notifications when rate limit is exceeded for shift type',
        () async {
          const targetChatId = 501;
          const formattedMessage = 'Shift rate limit test';

          for (var i = 0; i < 10; i++) {
            final notification = createTestNotification(
              notificationId: 'shift-rate-$i',
              targetChatId: targetChatId,
              type: NotificationType.shift,
            );

            when(
              () => mockTemplates.format(notification),
            ).thenReturn(formattedMessage);
            when(
              () => mockMessageService.sendText(targetChatId, formattedMessage),
            ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

            await notificationService.send(notification);
          }

          final blockedNotification = createTestNotification(
            notificationId: 'shift-rate-blocked',
            targetChatId: targetChatId,
            type: NotificationType.shift,
          );

          when(
            () => mockTemplates.format(blockedNotification),
          ).thenReturn(formattedMessage);

          await notificationService.send(blockedNotification);

          verify(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).called(10);
          verify(
            () => mockLogger.logConnection('Notification rate limited: shift'),
          ).called(1);
        },
      );

      test(
        'blocks notifications when rate limit is exceeded for sync type',
        () async {
          const targetChatId = 502;
          const formattedMessage = 'Sync rate limit test';

          for (var i = 0; i < 10; i++) {
            final notification = createTestNotification(
              notificationId: 'sync-rate-$i',
              targetChatId: targetChatId,
              type: NotificationType.sync,
            );

            when(
              () => mockTemplates.format(notification),
            ).thenReturn(formattedMessage);
            when(
              () => mockMessageService.sendText(targetChatId, formattedMessage),
            ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

            await notificationService.send(notification);
          }

          final blockedNotification = createTestNotification(
            notificationId: 'sync-rate-blocked',
            targetChatId: targetChatId,
            type: NotificationType.sync,
          );

          when(
            () => mockTemplates.format(blockedNotification),
          ).thenReturn(formattedMessage);

          await notificationService.send(blockedNotification);

          verify(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).called(10);
          verify(
            () => mockLogger.logConnection('Notification rate limited: sync'),
          ).called(1);
        },
      );

      test(
        'does not send when rate limited (even with valid channel)',
        () async {
          const targetChatId = 503;
          const formattedMessage = 'Rate blocked test';

          for (var i = 0; i < 10; i++) {
            final notification = createTestNotification(
              notificationId: 'system-$i',
              targetChatId: targetChatId,
              type: NotificationType.system,
            );

            when(
              () => mockTemplates.format(notification),
            ).thenReturn(formattedMessage);
            when(
              () => mockMessageService.sendText(targetChatId, formattedMessage),
            ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

            await notificationService.send(notification);
          }

          clearInteractions(mockMessageService);

          final blockedNotification = createTestNotification(
            notificationId: 'system-blocked',
            targetChatId: targetChatId,
            type: NotificationType.system,
          );

          when(
            () => mockTemplates.format(blockedNotification),
          ).thenReturn(formattedMessage);

          await notificationService.send(blockedNotification);

          verifyNever(() => mockMessageService.sendText(any(), any()));
          verifyNever(() => mockMessageService.sendSilent(any(), any()));
        },
      );

      test('rate limits are independent per notification type', () async {
        const targetChatId = 504;
        const formattedMessage = 'Independent rate test';

        for (var i = 0; i < 10; i++) {
          final notification = createTestNotification(
            notificationId: 'shift-independent-$i',
            targetChatId: targetChatId,
            type: NotificationType.shift,
          );

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

          await notificationService.send(notification);
        }

        final saleNotification = createTestNotification(
          notificationId: 'sale-not-limited',
          targetChatId: targetChatId,
          type: NotificationType.sale,
        );

        when(
          () => mockTemplates.format(saleNotification),
        ).thenReturn(formattedMessage);

        await notificationService.send(saleNotification);

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(11);
      });
    });

    group('sendBatch()', () {
      test('sends all notifications in batch', () async {
        const targetChatId = 600;
        const formattedMessage = 'Batch message';

        final notifications = List.generate(
          3,
          (i) => createTestNotification(
            notificationId: 'batch-$i',
            targetChatId: targetChatId,
          ),
        );

        for (final notification in notifications) {
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
        }
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.sendBatch(notifications);

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(3);
      });

      test('sends notifications sequentially with delay', () async {
        const targetChatId = 601;
        const formattedMessage = 'Sequential batch';

        final timestamps = <DateTime>[];

        final notifications = List.generate(
          2,
          (i) => createTestNotification(
            notificationId: 'seq-batch-$i',
            targetChatId: targetChatId,
          ),
        );

        for (final notification in notifications) {
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
        }
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async {
          timestamps.add(DateTime.now());
          return createMockMessage(chatId: targetChatId);
        });

        await notificationService.sendBatch(notifications);

        expect(timestamps.length, 2);
        expect(timestamps[1].isAfter(timestamps[0]), isTrue);
      });

      test('handles empty batch', () async {
        await notificationService.sendBatch([]);

        verifyNever(() => mockMessageService.sendText(any(), any()));
        verifyNever(() => mockMessageService.sendSilent(any(), any()));
      });

      test('respects rate limiting in batch', () async {
        const targetChatId = 602;
        const formattedMessage = 'Batch rate limit';

        final notifications = List.generate(
          15,
          (i) => createTestNotification(
            notificationId: 'batch-system-$i',
            targetChatId: targetChatId,
            type: NotificationType.system,
          ),
        );

        for (final notification in notifications) {
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
        }
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.sendBatch(notifications);

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(10);
        verify(
          () => mockLogger.logConnection('Notification rate limited: system'),
        ).called(5);
      });
    });

    group('sendCritical()', () {
      test('sends to posAlerts channel', () async {
        const alertsChatId = 700;
        final notification = createTestNotification(
          title: 'Critical Alert',
          type: NotificationType.error,
          priority: NotificationPriority.critical,
        );
        const formattedMessage = 'CRITICAL: Something bad happened';

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: alertsChatId));

        await notificationService.sendCritical(notification);

        verify(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).called(1);
        verify(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).called(1);
      });

      test('ignores isEnabled flag', () async {
        const alertsChatId = 701;
        final notification = createTestNotification(
          title: 'Critical while disabled',
        );
        const formattedMessage = 'Critical message';

        notificationService.disable();

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: alertsChatId));

        await notificationService.sendCritical(notification);

        verify(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).called(1);
      });

      test('ignores rate limiting', () async {
        const alertsChatId = 702;
        const formattedMessage = 'Critical bypasses rate limit';

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: alertsChatId));

        for (var i = 0; i < 50; i++) {
          final notification = createTestNotification(
            notificationId: 'critical-$i',
            title: 'Critical $i',
          );
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);

          await notificationService.sendCritical(notification);
        }

        verify(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).called(50);
      });

      test('does nothing when alerts channel is not registered', () async {
        final notification = createTestNotification(title: 'No channel');

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(null);

        await notificationService.sendCritical(notification);

        verifyNever(() => mockTemplates.format(any()));
        verifyNever(() => mockMessageService.sendText(any(), any()));
      });

      test('logs critical notification on success', () async {
        const alertsChatId = 703;
        final notification = createTestNotification(title: 'Logged Critical');
        const formattedMessage = 'Critical logged';

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: alertsChatId));

        await notificationService.sendCritical(notification);

        verify(
          () => mockLogger.logCritical(
            'Critical notification sent: Logged Critical',
          ),
        ).called(1);
      });

      test('logs critical error when send fails', () async {
        const alertsChatId = 704;
        final notification = createTestNotification(title: 'Failed Critical');
        const formattedMessage = 'Critical that fails';
        final exception = Exception('Send failed');

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenThrow(exception);

        await notificationService.sendCritical(notification);

        verify(
          () => mockLogger.logCritical(
            'Failed to send critical notification: $exception',
          ),
        ).called(1);
      });

      test('does not enqueue message when critical send fails', () async {
        const alertsChatId = 705;
        final notification = createTestNotification(
          title: 'No queue for critical',
        );
        const formattedMessage = 'No queue';

        when(
          () => mockChannelRegistry.getChatId(SystemChannelType.posAlerts),
        ).thenReturn(alertsChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(alertsChatId, formattedMessage),
        ).thenThrow(Exception('Network error'));

        await notificationService.sendCritical(notification);

        verifyNever(() => mockMessageQueue.enqueue(any()));
      });
    });

    group('channel routing', () {
      test('routes sale notifications through router', () async {
        const resolvedChatId = 800;
        final notification = createTestNotification(
          type: NotificationType.sale,
          targetChatId: null,
        );
        const formattedMessage = 'Sale notification';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.sale,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

        await notificationService.send(notification);

        verify(
          () => mockRouter.resolveChannel(
            NotificationType.sale,
            mockChannelRegistry,
          ),
        ).called(1);
      });

      test('routes stock notifications through router', () async {
        const resolvedChatId = 801;
        final notification = createTestNotification(
          type: NotificationType.stock,
          targetChatId: null,
        );
        const formattedMessage = 'Stock notification';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.stock,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

        await notificationService.send(notification);

        verify(
          () => mockRouter.resolveChannel(
            NotificationType.stock,
            mockChannelRegistry,
          ),
        ).called(1);
      });

      test('routes error notifications through router', () async {
        const resolvedChatId = 802;
        final notification = createTestNotification(
          type: NotificationType.error,
          targetChatId: null,
        );
        const formattedMessage = 'Error notification';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.error,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

        await notificationService.send(notification);

        verify(
          () => mockRouter.resolveChannel(
            NotificationType.error,
            mockChannelRegistry,
          ),
        ).called(1);
      });

      test('routes fiscal notifications through router', () async {
        const resolvedChatId = 803;
        final notification = createTestNotification(
          type: NotificationType.fiscal,
          targetChatId: null,
        );
        const formattedMessage = 'Fiscal notification';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.fiscal,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

        await notificationService.send(notification);

        verify(
          () => mockRouter.resolveChannel(
            NotificationType.fiscal,
            mockChannelRegistry,
          ),
        ).called(1);
      });

      test('prefers targetChatId over router when both available', () async {
        const explicitChatId = 999;
        const routedChatId = 888;
        final notification = createTestNotification(
          type: NotificationType.cash,
          targetChatId: explicitChatId,
        );
        const formattedMessage = 'Explicit target';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.cash,
            mockChannelRegistry,
          ),
        ).thenReturn(routedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(explicitChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: explicitChatId));

        await notificationService.send(notification);

        verify(
          () => mockMessageService.sendText(explicitChatId, formattedMessage),
        ).called(1);
        verifyNever(() => mockRouter.resolveChannel(any(), any()));
      });
    });

    group('template formatting', () {
      test('formats notification with all fields', () async {
        const targetChatId = 900;
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final notification = NotificationPayload(
          notificationId: 'full-format-test',
          type: NotificationType.sale,
          priority: NotificationPriority.high,
          title: 'New Sale',
          body: 'Sale completed for 1000 KZT',
          posId: 'POS-123',
          storeName: 'Main Store',
          timestamp: timestamp,
          targetChatId: targetChatId,
        );
        const expectedFormat = 'Formatted with all data';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(expectedFormat);
        when(
          () => mockMessageService.sendText(targetChatId, expectedFormat),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        verify(() => mockTemplates.format(notification)).called(1);
      });

      test('passes notification with extra data to templates', () async {
        const targetChatId = 901;
        final notification = NotificationPayload(
          notificationId: 'extra-data-test',
          type: NotificationType.sale,
          title: 'Sale with extra',
          body: 'Extra data included',
          posId: 'POS-456',
          timestamp: DateTime.now(),
          targetChatId: targetChatId,
          extra: {'saleId': '12345', 'amount': 5000, 'currency': 'KZT'},
        );
        const formattedMessage = 'Message with extra data';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);

        final captured = verify(
          () => mockTemplates.format(captureAny()),
        ).captured;
        final capturedNotification = captured.first as NotificationPayload;
        expect(capturedNotification.extra, isNotNull);
        expect(capturedNotification.extra!['saleId'], '12345');
        expect(capturedNotification.extra!['amount'], 5000);
      });
    });

    group('notification types', () {
      final notificationTypes = NotificationType.values;

      for (final type in notificationTypes) {
        test('handles ${type.name} notification type', () async {
          const targetChatId = 1000;
          final notification = createTestNotification(
            notificationId: '${type.name}-test',
            targetChatId: targetChatId,
            type: type,
          );
          const formattedMessage = 'Type test message';

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

          await notificationService.send(notification);

          verify(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).called(1);
        });
      }
    });

    group('notification priorities', () {
      final priorities = NotificationPriority.values;

      for (final priority in priorities) {
        test('handles ${priority.name} priority', () async {
          const targetChatId = 1100;
          final notification = createTestNotification(
            notificationId: '${priority.name}-priority-test',
            targetChatId: targetChatId,
            priority: priority,
          );
          const formattedMessage = 'Priority test message';

          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
          when(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

          await notificationService.send(notification);

          verify(
            () => mockMessageService.sendText(targetChatId, formattedMessage),
          ).called(1);
        });
      }
    });

    group('integration scenarios', () {
      test('send notification flow: format -> route -> send -> log', () async {
        final notification = createTestNotification(
          notificationId: 'integration-flow-1',
          type: NotificationType.shift,
          title: 'Shift Opened',
          targetChatId: null,
        );
        const resolvedChatId = 1200;
        const formattedMessage = 'Shift opened successfully';

        when(
          () => mockRouter.resolveChannel(
            NotificationType.shift,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: resolvedChatId));

        await notificationService.send(notification);

        verifyInOrder([
          () => mockRouter.resolveChannel(
            NotificationType.shift,
            mockChannelRegistry,
          ),
          () => mockTemplates.format(notification),
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
          () => mockLogger.logConnection(
            'Notification sent: shift \u2192 chat=$resolvedChatId',
          ),
        ]);
      });

      test('error flow: format -> route -> fail -> queue -> log', () async {
        final notification = createTestNotification(
          notificationId: 'error-flow-1',
          type: NotificationType.cash,
          title: 'Cash Operation',
          targetChatId: null,
        );
        const resolvedChatId = 1201;
        const formattedMessage = 'Cash operation failed';
        final exception = Exception('Connection lost');

        when(
          () => mockRouter.resolveChannel(
            NotificationType.cash,
            mockChannelRegistry,
          ),
        ).thenReturn(resolvedChatId);
        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
        ).thenThrow(exception);
        when(() => mockMessageQueue.enqueue(any())).thenReturn(null);

        await notificationService.send(notification);

        verifyInOrder([
          () => mockRouter.resolveChannel(
            NotificationType.cash,
            mockChannelRegistry,
          ),
          () => mockTemplates.format(notification),
          () => mockMessageService.sendText(resolvedChatId, formattedMessage),
          () => mockMessageQueue.enqueue(any()),
          () => mockLogger.logError('send', 'Notification queued: $exception'),
        ]);
      });

      test('disable and enable cycle', () async {
        const targetChatId = 1202;
        final notification = createTestNotification(targetChatId: targetChatId);
        const formattedMessage = 'Toggle test';

        when(
          () => mockTemplates.format(notification),
        ).thenReturn(formattedMessage);
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.send(notification);
        verify(() => mockMessageService.sendText(any(), any())).called(1);

        notificationService.disable();
        await notificationService.send(notification);
        verifyNever(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        );

        notificationService.enable();
        await notificationService.send(notification);
        verify(() => mockMessageService.sendText(any(), any())).called(1);
      });

      test('mixed batch with different types and priorities', () async {
        const targetChatId = 1203;
        const formattedMessage = 'Mixed batch';

        final notifications = [
          createTestNotification(
            notificationId: 'mixed-1',
            targetChatId: targetChatId,
            type: NotificationType.sale,
            priority: NotificationPriority.low,
          ),
          createTestNotification(
            notificationId: 'mixed-2',
            targetChatId: targetChatId,
            type: NotificationType.error,
            priority: NotificationPriority.high,
          ),
          createTestNotification(
            notificationId: 'mixed-3',
            targetChatId: targetChatId,
            type: NotificationType.fiscal,
            priority: NotificationPriority.critical,
            isSilent: true,
          ),
        ];

        for (final notification in notifications) {
          when(
            () => mockTemplates.format(notification),
          ).thenReturn(formattedMessage);
        }
        when(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));
        when(
          () => mockMessageService.sendSilent(targetChatId, formattedMessage),
        ).thenAnswer((_) async => createMockMessage(chatId: targetChatId));

        await notificationService.sendBatch(notifications);

        verify(
          () => mockMessageService.sendText(targetChatId, formattedMessage),
        ).called(2);
        verify(
          () => mockMessageService.sendSilent(targetChatId, formattedMessage),
        ).called(1);
      });
    });
  });
}
