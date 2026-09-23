import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';

void main() {
  group('NavDestinations', () {
    group('allForMode', () {
      test('retail returns 11 items', () {
        final items = NavDestinations.allForMode(OperatingMode.retail);
        expect(items.length, 11);
      });

      test('retail has 8 primary items', () {
        final primary = NavDestinations.allForMode(
          OperatingMode.retail,
        ).where((d) => d.isPrimary).toList();
        expect(primary.length, 8);
      });

      test('retail primary order: sale, refund, shift, history', () {
        final primary = NavDestinations.primaryForMode(OperatingMode.retail);
        expect(primary[0].route, '/sale');
        expect(primary[1].route, '/refund');
        expect(primary[2].route, '/shift');
        expect(primary[3].route, '/history');
      });

      test('retail secondary contains agent', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.retail,
        );
        expect(secondary.any((d) => d.route == '/agent'), true);
      });

      test('restaurant returns 11 items', () {
        final items = NavDestinations.allForMode(OperatingMode.restaurant);
        expect(items.length, 11);
      });

      test('restaurant has 8 primary items', () {
        final primary = NavDestinations.primaryForMode(
          OperatingMode.restaurant,
        );
        expect(primary.length, 8);
      });

      test('restaurant primary: tables, orders, sale, shift, history', () {
        final primary = NavDestinations.primaryForMode(
          OperatingMode.restaurant,
        );
        expect(primary[0].route, '/tables');
        expect(primary[1].route, '/orders');
        expect(primary[2].route, '/sale');
        expect(primary[3].route, '/shift');
        expect(primary[4].route, '/history');
      });

      test('restaurant secondary does not contain supply', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.restaurant,
        );
        expect(secondary.any((d) => d.route == '/supply'), false);
      });

      test('service returns 11 items', () {
        final items = NavDestinations.allForMode(OperatingMode.service);
        expect(items.length, 11);
      });

      test('service has 8 primary items', () {
        final primary = NavDestinations.primaryForMode(OperatingMode.service);
        expect(primary.length, 8);
      });

      test('service primary: queue, intake, sale, shift, history', () {
        final primary = NavDestinations.primaryForMode(OperatingMode.service);
        expect(primary[0].route, '/service-queue');
        expect(primary[1].route, '/service-intake');
        expect(primary[2].route, '/sale');
        expect(primary[3].route, '/shift');
        expect(primary[4].route, '/history');
      });

      test('service secondary does not contain supply', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.service,
        );
        expect(secondary.any((d) => d.route == '/supply'), false);
      });
    });

    group('primaryForMode', () {
      test('retail has 8 primary items', () {
        expect(NavDestinations.primaryForMode(OperatingMode.retail).length, 8);
      });

      test('restaurant has 8 primary items', () {
        expect(
          NavDestinations.primaryForMode(OperatingMode.restaurant).length,
          8,
        );
      });

      test('service has 8 primary items', () {
        expect(NavDestinations.primaryForMode(OperatingMode.service).length, 8);
      });
    });

    group('secondaryForMode', () {
      test('retail secondary has agent, settings, sync', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.retail,
        );
        final routes = secondary.map((d) => d.route).toList();
        expect(routes, contains('/agent'));
        expect(routes, contains('/settings'));
        expect(routes, contains('/sync'));
      });

      test('restaurant secondary has agent, settings, sync', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.restaurant,
        );
        final routes = secondary.map((d) => d.route).toList();
        expect(routes, contains('/agent'));
        expect(routes, contains('/settings'));
        expect(routes, contains('/sync'));
      });

      test('service secondary has agent, settings, sync', () {
        final secondary = NavDestinations.secondaryForMode(
          OperatingMode.service,
        );
        final routes = secondary.map((d) => d.route).toList();
        expect(routes, contains('/agent'));
        expect(routes, contains('/settings'));
        expect(routes, contains('/sync'));
      });
    });

    // Подпись пункта меню больше не хранится в `NavDestination`: поле
    // `label` было русским словом и жило только запасным значением на
    // случай отсутствующего словаря (2026-09-22). Проба смотрит маршрут —
    // то, чем пункт меню и опознаётся.
    group('fromRoute', () {
      test('resolves /sale for retail', () {
        final dest = NavDestinations.fromRoute('/sale', OperatingMode.retail);
        expect(dest, isNotNull);
        expect(dest!.route, '/sale');
      });

      test('resolves /tables for restaurant', () {
        final dest = NavDestinations.fromRoute(
          '/tables',
          OperatingMode.restaurant,
        );
        expect(dest, isNotNull);
        expect(dest!.route, '/tables');
      });

      test('resolves /service-queue for service', () {
        final dest = NavDestinations.fromRoute(
          '/service-queue',
          OperatingMode.service,
        );
        expect(dest, isNotNull);
        expect(dest!.route, '/service-queue');
      });

      test('returns null for unknown route', () {
        final dest = NavDestinations.fromRoute(
          '/unknown',
          OperatingMode.retail,
        );
        expect(dest, isNull);
      });

      test('resolves /settings for all modes', () {
        for (final mode in OperatingMode.values) {
          final dest = NavDestinations.fromRoute('/settings', mode);
          expect(dest, isNotNull, reason: 'settings not found for $mode');
        }
      });

      test('/tables not found in retail mode', () {
        final dest = NavDestinations.fromRoute('/tables', OperatingMode.retail);
        expect(dest, isNull);
      });
    });

    group('primaryIndexOf', () {
      test('sale is index 0 in retail', () {
        expect(
          NavDestinations.primaryIndexOf('/sale', OperatingMode.retail),
          0,
        );
      });

      test('tables is index 0 in restaurant', () {
        expect(
          NavDestinations.primaryIndexOf('/tables', OperatingMode.restaurant),
          0,
        );
      });

      test('service-queue is index 0 in service', () {
        expect(
          NavDestinations.primaryIndexOf(
            '/service-queue',
            OperatingMode.service,
          ),
          0,
        );
      });

      test('returns 0 for unknown route', () {
        expect(
          NavDestinations.primaryIndexOf('/unknown', OperatingMode.retail),
          0,
        );
      });
    });

    group('indexOf', () {
      test('finds agent in retail secondary', () {
        final idx = NavDestinations.indexOf('/agent', OperatingMode.retail);
        expect(idx, greaterThan(3));
      });

      test('finds settings in restaurant', () {
        final idx = NavDestinations.indexOf(
          '/settings',
          OperatingMode.restaurant,
        );
        expect(idx, greaterThan(4));
      });
    });

    group('defaultRoute', () {
      test('retail default is /sale', () {
        expect(NavDestinations.defaultRoute(OperatingMode.retail), '/sale');
      });

      test('restaurant default is /tables', () {
        expect(
          NavDestinations.defaultRoute(OperatingMode.restaurant),
          '/tables',
        );
      });

      test('service default is /service-queue', () {
        expect(
          NavDestinations.defaultRoute(OperatingMode.service),
          '/service-queue',
        );
      });
    });

    group('backward compatibility', () {
      test('all is same as retail allForMode', () {
        expect(
          NavDestinations.all.length,
          NavDestinations.allForMode(OperatingMode.retail).length,
        );
      });

      test('primary is same as retail primaryForMode', () {
        expect(
          NavDestinations.primary.length,
          NavDestinations.primaryForMode(OperatingMode.retail).length,
        );
      });
    });
  });
}
