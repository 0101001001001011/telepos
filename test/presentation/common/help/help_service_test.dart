import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/common/help/help_service.dart';

void main() {
  group('HelpContent.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'screenId': 'sale',
        'title': 'Продажа',
        'description': 'Описание',
        'sections': [
          {'heading': 'Раздел 1', 'content': 'Текст 1'},
          {'heading': 'Раздел 2', 'content': 'Текст 2'},
        ],
        'tips': ['Совет 1', 'Совет 2'],
        'shortcuts': [
          {'key': 'F1', 'action': 'Справка'},
          {'key': 'Enter', 'action': 'Подтвердить'},
        ],
        'relatedScreens': ['payment', 'refund'],
      };

      final content = HelpContent.fromJson(json);

      expect(content.screenId, 'sale');
      expect(content.title, 'Продажа');
      expect(content.description, 'Описание');
      expect(content.sections, hasLength(2));
      expect(content.sections[0].heading, 'Раздел 1');
      expect(content.sections[0].content, 'Текст 1');
      expect(content.tips, hasLength(2));
      expect(content.tips[0], 'Совет 1');
      expect(content.shortcuts, hasLength(2));
      expect(content.shortcuts[0].key, 'F1');
      expect(content.shortcuts[0].action, 'Справка');
      expect(content.relatedScreens, ['payment', 'refund']);
    });

    test('handles missing optional fields', () {
      final json = {'screenId': 'test', 'title': 'Test', 'description': 'Desc'};

      final content = HelpContent.fromJson(json);

      expect(content.sections, isEmpty);
      expect(content.tips, isEmpty);
      expect(content.shortcuts, isEmpty);
      expect(content.relatedScreens, isEmpty);
    });

    test('handles completely empty JSON', () {
      final content = HelpContent.fromJson({});

      expect(content.screenId, '');
      expect(content.title, '');
      expect(content.description, '');
      expect(content.sections, isEmpty);
      expect(content.tips, isEmpty);
      expect(content.shortcuts, isEmpty);
      expect(content.relatedScreens, isEmpty);
    });

    test('handles null values in JSON', () {
      final json = <String, dynamic>{
        'screenId': null,
        'title': null,
        'description': null,
        'sections': null,
        'tips': null,
        'shortcuts': null,
        'relatedScreens': null,
      };

      final content = HelpContent.fromJson(json);

      expect(content.screenId, '');
      expect(content.title, '');
      expect(content.description, '');
      expect(content.sections, isEmpty);
      expect(content.tips, isEmpty);
      expect(content.shortcuts, isEmpty);
      expect(content.relatedScreens, isEmpty);
    });
  });

  group('HelpSection.fromJson', () {
    test('parses valid JSON', () {
      final section = HelpSection.fromJson({
        'heading': 'Title',
        'content': 'Body',
      });
      expect(section.heading, 'Title');
      expect(section.content, 'Body');
    });

    test('handles empty JSON', () {
      final section = HelpSection.fromJson({});
      expect(section.heading, '');
      expect(section.content, '');
    });
  });

  group('HelpShortcut.fromJson', () {
    test('parses valid JSON', () {
      final shortcut = HelpShortcut.fromJson({'key': 'F1', 'action': 'Help'});
      expect(shortcut.key, 'F1');
      expect(shortcut.action, 'Help');
    });

    test('handles empty JSON', () {
      final shortcut = HelpShortcut.fromJson({});
      expect(shortcut.key, '');
      expect(shortcut.action, '');
    });
  });

  group('HelpService.routeToScreenId', () {
    test('maps standard routes', () {
      expect(HelpService.routeToScreenId('/'), 'splash');
      expect(HelpService.routeToScreenId('/sale'), 'sale');
      expect(HelpService.routeToScreenId('/refund'), 'refund');
      expect(HelpService.routeToScreenId('/payment'), 'payment');
      expect(HelpService.routeToScreenId('/shift'), 'shift');
      expect(HelpService.routeToScreenId('/history'), 'history');
      expect(HelpService.routeToScreenId('/agent'), 'agent');
      expect(HelpService.routeToScreenId('/supply'), 'supply');
      expect(HelpService.routeToScreenId('/cash-operation'), 'cash_operation');
      expect(HelpService.routeToScreenId('/settings'), 'settings');
      expect(
        HelpService.routeToScreenId('/transport-settings'),
        'transport_settings',
      );
      expect(
        HelpService.routeToScreenId('/printer-settings'),
        'printer_settings',
      );
      expect(
        HelpService.routeToScreenId('/fiscal-settings'),
        'fiscal_settings',
      );
      expect(HelpService.routeToScreenId('/sync'), 'sync');
      expect(HelpService.routeToScreenId('/writeoff'), 'writeoff');
      expect(HelpService.routeToScreenId('/inventory'), 'inventory');
      expect(HelpService.routeToScreenId('/additional'), 'additional');
      expect(HelpService.routeToScreenId('/login'), 'login');
      expect(HelpService.routeToScreenId('/initial-setup'), 'initial_setup');
      expect(HelpService.routeToScreenId('/restore-or-new'), 'restore_or_new');
      expect(HelpService.routeToScreenId('/telegram-setup'), 'telegram_auth');
    });

    test('maps restaurant routes', () {
      expect(HelpService.routeToScreenId('/tables'), 'tables');
      expect(HelpService.routeToScreenId('/orders'), 'orders');
    });

    test('maps service routes', () {
      expect(HelpService.routeToScreenId('/service-queue'), 'service_queue');
      expect(HelpService.routeToScreenId('/service-intake'), 'service_intake');
    });

    test('maps dynamic routes', () {
      expect(HelpService.routeToScreenId('/tables/5'), 'table_detail');
      expect(HelpService.routeToScreenId('/tables/123'), 'table_detail');
      expect(
        HelpService.routeToScreenId('/service-queue/42'),
        'service_detail',
      );
    });

    test('handles null and empty', () {
      expect(HelpService.routeToScreenId(null), '');
      expect(HelpService.routeToScreenId(''), '');
    });

    test('strips query parameters', () {
      expect(HelpService.routeToScreenId('/sale?tab=search'), 'sale');
      expect(
        HelpService.routeToScreenId('/tables/5?edit=true'),
        'table_detail',
      );
    });

    test('clearCache does not throw', () {
      HelpService.clearCache();
    });
  });
}
