import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/utils/version_util.dart';

void main() {
  group('VersionUtil', () {
    group('compare', () {
      test('returns 0 for equal versions', () {
        expect(VersionUtil.compare('1.0.0', '1.0.0'), 0);
        expect(VersionUtil.compare('2.3.4', '2.3.4'), 0);
      });

      test('returns positive when v1 is newer', () {
        expect(VersionUtil.compare('2.0.0', '1.0.0'), greaterThan(0));
        expect(VersionUtil.compare('1.1.0', '1.0.0'), greaterThan(0));
        expect(VersionUtil.compare('1.0.1', '1.0.0'), greaterThan(0));
      });

      test('returns negative when v1 is older', () {
        expect(VersionUtil.compare('1.0.0', '2.0.0'), lessThan(0));
        expect(VersionUtil.compare('1.0.0', '1.1.0'), lessThan(0));
        expect(VersionUtil.compare('1.0.0', '1.0.1'), lessThan(0));
      });

      test('handles prerelease versions', () {
        expect(VersionUtil.compare('1.0.0-alpha', '1.0.0'), lessThan(0));
        expect(VersionUtil.compare('1.0.0', '1.0.0-beta'), greaterThan(0));
        expect(VersionUtil.compare('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
      });
    });

    group('isNewer', () {
      test('returns true when v1 is newer', () {
        expect(VersionUtil.isNewer('2.0.0', '1.0.0'), true);
        expect(VersionUtil.isNewer('1.1.0', '1.0.0'), true);
        expect(VersionUtil.isNewer('1.0.1', '1.0.0'), true);
      });

      test('returns false when v1 is equal or older', () {
        expect(VersionUtil.isNewer('1.0.0', '1.0.0'), false);
        expect(VersionUtil.isNewer('1.0.0', '2.0.0'), false);
      });
    });

    group('isOlder', () {
      test('returns true when v1 is older', () {
        expect(VersionUtil.isOlder('1.0.0', '2.0.0'), true);
        expect(VersionUtil.isOlder('1.0.0', '1.1.0'), true);
        expect(VersionUtil.isOlder('1.0.0', '1.0.1'), true);
      });

      test('returns false when v1 is equal or newer', () {
        expect(VersionUtil.isOlder('1.0.0', '1.0.0'), false);
        expect(VersionUtil.isOlder('2.0.0', '1.0.0'), false);
      });
    });

    group('isEqual', () {
      test('returns true for equal versions', () {
        expect(VersionUtil.isEqual('1.0.0', '1.0.0'), true);
        expect(VersionUtil.isEqual('2.3.4', '2.3.4'), true);
      });

      test('returns false for different versions', () {
        expect(VersionUtil.isEqual('1.0.0', '1.0.1'), false);
        expect(VersionUtil.isEqual('1.0.0', '2.0.0'), false);
      });
    });

    group('isValid', () {
      test('returns true for valid versions', () {
        expect(VersionUtil.isValid('1.0.0'), true);
        expect(VersionUtil.isValid('2.3.4'), true);
        expect(VersionUtil.isValid('1.0'), true);
        expect(VersionUtil.isValid('1'), true);
        expect(VersionUtil.isValid('v1.0.0'), true);
        expect(VersionUtil.isValid('1.0.0-alpha'), true);
        expect(VersionUtil.isValid('1.0.0+build'), true);
      });

      test('returns false for invalid versions', () {
        expect(VersionUtil.isValid('1.2.3.4.5'), false);
      });
    });
  });

  group('Version', () {
    group('parse', () {
      test('parses simple version', () {
        final version = Version.parse('1.2.3');
        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
        expect(version.prerelease, isNull);
        expect(version.build, isNull);
      });

      test('parses version with v prefix', () {
        final version = Version.parse('v1.2.3');
        expect(version.major, 1);
        expect(version.minor, 2);
        expect(version.patch, 3);
      });

      test('parses version with prerelease', () {
        final version = Version.parse('1.0.0-alpha');
        expect(version.major, 1);
        expect(version.minor, 0);
        expect(version.patch, 0);
        expect(version.prerelease, 'alpha');
      });

      test('parses version with build metadata', () {
        final version = Version.parse('1.0.0+build123');
        expect(version.major, 1);
        expect(version.minor, 0);
        expect(version.patch, 0);
        expect(version.build, 'build123');
      });

      test('parses version with both prerelease and build', () {
        final version = Version.parse('1.0.0-beta.1+build.456');
        expect(version.prerelease, 'beta.1');
        expect(version.build, 'build.456');
      });

      test('parses major only', () {
        final version = Version.parse('5');
        expect(version.major, 5);
        expect(version.minor, 0);
        expect(version.patch, 0);
      });

      test('parses major.minor only', () {
        final version = Version.parse('3.7');
        expect(version.major, 3);
        expect(version.minor, 7);
        expect(version.patch, 0);
      });

      test('handles uppercase V prefix', () {
        final version = Version.parse('V1.2.3');
        expect(version.major, 1);
        expect(version.minor, 2);
      });

      test('throws on invalid format', () {
        expect(
          () => Version.parse('1.2.3.4.5'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('isPrerelease', () {
      test('returns true for prerelease versions', () {
        expect(Version.parse('1.0.0-alpha').isPrerelease, true);
        expect(Version.parse('1.0.0-beta.1').isPrerelease, true);
        expect(Version.parse('1.0.0-rc.2').isPrerelease, true);
      });

      test('returns false for release versions', () {
        expect(Version.parse('1.0.0').isPrerelease, false);
        expect(Version.parse('1.0.0+build').isPrerelease, false);
      });
    });

    group('compareTo', () {
      test('compares major versions', () {
        expect(
          Version.parse('2.0.0').compareTo(Version.parse('1.0.0')),
          greaterThan(0),
        );
        expect(
          Version.parse('1.0.0').compareTo(Version.parse('2.0.0')),
          lessThan(0),
        );
      });

      test('compares minor versions', () {
        expect(
          Version.parse('1.2.0').compareTo(Version.parse('1.1.0')),
          greaterThan(0),
        );
        expect(
          Version.parse('1.1.0').compareTo(Version.parse('1.2.0')),
          lessThan(0),
        );
      });

      test('compares patch versions', () {
        expect(
          Version.parse('1.0.2').compareTo(Version.parse('1.0.1')),
          greaterThan(0),
        );
        expect(
          Version.parse('1.0.1').compareTo(Version.parse('1.0.2')),
          lessThan(0),
        );
      });

      test('prerelease is less than release', () {
        expect(
          Version.parse('1.0.0-alpha').compareTo(Version.parse('1.0.0')),
          lessThan(0),
        );
        expect(
          Version.parse('1.0.0').compareTo(Version.parse('1.0.0-alpha')),
          greaterThan(0),
        );
      });

      test('compares prerelease lexicographically', () {
        expect(
          Version.parse('1.0.0-alpha').compareTo(Version.parse('1.0.0-beta')),
          lessThan(0),
        );
        expect(
          Version.parse('1.0.0-beta').compareTo(Version.parse('1.0.0-alpha')),
          greaterThan(0),
        );
      });

      test('equal versions return 0', () {
        expect(Version.parse('1.2.3').compareTo(Version.parse('1.2.3')), 0);
      });
    });

    group('operators', () {
      test('== operator', () {
        expect(Version.parse('1.0.0') == Version.parse('1.0.0'), true);
        expect(Version.parse('1.0.0') == Version.parse('1.0.1'), false);
      });

      test('> operator', () {
        expect(Version.parse('2.0.0') > Version.parse('1.0.0'), true);
        expect(Version.parse('1.0.0') > Version.parse('2.0.0'), false);
      });

      test('< operator', () {
        expect(Version.parse('1.0.0') < Version.parse('2.0.0'), true);
        expect(Version.parse('2.0.0') < Version.parse('1.0.0'), false);
      });

      test('>= operator', () {
        expect(Version.parse('2.0.0') >= Version.parse('1.0.0'), true);
        expect(Version.parse('1.0.0') >= Version.parse('1.0.0'), true);
        expect(Version.parse('1.0.0') >= Version.parse('2.0.0'), false);
      });

      test('<= operator', () {
        expect(Version.parse('1.0.0') <= Version.parse('2.0.0'), true);
        expect(Version.parse('1.0.0') <= Version.parse('1.0.0'), true);
        expect(Version.parse('2.0.0') <= Version.parse('1.0.0'), false);
      });
    });

    group('toString', () {
      test('formats simple version', () {
        expect(Version.parse('1.2.3').toString(), '1.2.3');
      });

      test('formats version with prerelease', () {
        expect(Version.parse('1.0.0-alpha').toString(), '1.0.0-alpha');
      });

      test('formats version with build', () {
        expect(Version.parse('1.0.0+build').toString(), '1.0.0+build');
      });

      test('formats version with both', () {
        expect(
          Version.parse('1.0.0-alpha+build').toString(),
          '1.0.0-alpha+build',
        );
      });
    });

    group('hashCode', () {
      test('equal versions have equal hashCode', () {
        expect(
          Version.parse('1.0.0').hashCode,
          Version.parse('1.0.0').hashCode,
        );
      });
    });
  });
}
