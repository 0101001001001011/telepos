class VersionUtil {
  VersionUtil._();

  static int compare(String v1, String v2) {
    final parsed1 = Version.parse(v1);
    final parsed2 = Version.parse(v2);
    return parsed1.compareTo(parsed2);
  }

  static bool isNewer(String v1, String v2) => compare(v1, v2) > 0;

  static bool isOlder(String v1, String v2) => compare(v1, v2) < 0;

  static bool isEqual(String v1, String v2) => compare(v1, v2) == 0;

  static bool isValid(String version) {
    try {
      Version.parse(version);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class Version implements Comparable<Version> {
  const Version({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.build,
  });

  factory Version.parse(String version) {
    var v = version.trim().toLowerCase();
    if (v.startsWith('v')) v = v.substring(1);

    String? build;
    final plusIndex = v.indexOf('+');
    if (plusIndex != -1) {
      build = v.substring(plusIndex + 1);
      v = v.substring(0, plusIndex);
    }

    String? prerelease;
    final dashIndex = v.indexOf('-');
    if (dashIndex != -1) {
      prerelease = v.substring(dashIndex + 1);
      v = v.substring(0, dashIndex);
    }

    final parts = v.split('.');
    if (parts.isEmpty || parts.length > 3) {
      throw FormatException('Invalid version format: $version');
    }

    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return Version(
      major: major,
      minor: minor,
      patch: patch,
      prerelease: prerelease,
      build: build,
    );
  }

  final int major;

  final int minor;

  final int patch;

  final String? prerelease;

  final String? build;

  bool get isPrerelease => prerelease != null && prerelease!.isNotEmpty;

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);

    if (minor != other.minor) return minor.compareTo(other.minor);

    if (patch != other.patch) return patch.compareTo(other.patch);

    if (isPrerelease && !other.isPrerelease) return -1;
    if (!isPrerelease && other.isPrerelease) return 1;

    if (isPrerelease && other.isPrerelease) {
      return prerelease!.compareTo(other.prerelease!);
    }

    return 0;
  }

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);

  bool operator >(Version other) => compareTo(other) > 0;

  bool operator <(Version other) => compareTo(other) < 0;

  bool operator >=(Version other) => compareTo(other) >= 0;

  bool operator <=(Version other) => compareTo(other) <= 0;

  @override
  String toString() {
    var result = '$major.$minor.$patch';
    if (prerelease != null) result += '-$prerelease';
    if (build != null) result += '+$build';
    return result;
  }
}
