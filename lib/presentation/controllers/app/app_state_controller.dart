import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/enums/operating_mode.dart';
import '../../../core/platform/host_process.dart';
import '../../../core/platform/platform_info.dart';
import 'package:telepos/domain/shift/shift_status.dart';

enum ConnectionStatus { online, offline, syncing }

@immutable
class AppState {
  const AppState({
    this.currentTime = '',
    this.connectionStatus = ConnectionStatus.offline,
    this.posName,
    this.userId,
    this.userName,
    this.userRole,
    this.version = '1.0.0',
    this.freeStorageBytes,
    this.showStorageWarning = false,
    this.permissions = const {},
    this.shift = ShiftStatus.unknown,
    this.operatingMode = OperatingMode.retail,
  });

  final String currentTime;

  final ConnectionStatus connectionStatus;

  final String? posName;

  final int? userId;

  final String? userName;

  final int? userRole;

  final String version;

  final int? freeStorageBytes;

  final bool showStorageWarning;

  final Set<String> permissions;

  /// Смена вошедшего — задача 47, три состояния (разбор в [ShiftStatus]).
  final ShiftStatus shift;

  final OperatingMode operatingMode;

  static const int minFreeStorageBytes = 2 * 1024 * 1024 * 1024;

  double get freeStorageGB =>
      freeStorageBytes != null ? freeStorageBytes! / (1024 * 1024 * 1024) : 0;

  bool get isLowStorage =>
      freeStorageBytes != null && freeStorageBytes! < minFreeStorageBytes;

  String get statusText {
    switch (connectionStatus) {
      case ConnectionStatus.online:
        return 'Online';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.syncing:
        return 'Syncing...';
    }
  }

  bool hasPermission(String permission) => permissions.contains(permission);

  bool get isLoggedIn => userId != null;

  AppState copyWith({
    String? currentTime,
    ConnectionStatus? connectionStatus,
    String? posName,
    bool clearPosName = false,
    int? userId,
    bool clearUserId = false,
    String? userName,
    bool clearUserName = false,
    int? userRole,
    bool clearUserRole = false,
    String? version,
    int? freeStorageBytes,
    bool? showStorageWarning,
    Set<String>? permissions,
    ShiftStatus? shift,
    OperatingMode? operatingMode,
  }) {
    return AppState(
      currentTime: currentTime ?? this.currentTime,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      posName: clearPosName ? null : (posName ?? this.posName),
      userId: clearUserId ? null : (userId ?? this.userId),
      userName: clearUserName ? null : (userName ?? this.userName),
      userRole: clearUserRole ? null : (userRole ?? this.userRole),
      version: version ?? this.version,
      freeStorageBytes: freeStorageBytes ?? this.freeStorageBytes,
      showStorageWarning: showStorageWarning ?? this.showStorageWarning,
      permissions: permissions ?? this.permissions,
      shift: shift ?? this.shift,
      operatingMode: operatingMode ?? this.operatingMode,
    );
  }
}

class AppStateNotifier extends Notifier<AppState> {
  Timer? _timeTimer;
  Timer? _storageTimer;

  @override
  AppState build() {
    _startTimers();

    ref.onDispose(() {
      _timeTimer?.cancel();
      _storageTimer?.cancel();
    });

    return AppState(currentTime: _formatTime(DateTime.now()));
  }

  void _startTimers() {
    _timeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _updateTime();
    });

    _storageTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkStorage();
    });

    Future.microtask(() {
      _checkStorage();
    });
  }

  void _updateTime() {
    state = state.copyWith(currentTime: _formatTime(DateTime.now()));
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _checkStorage() async {
    if (kIsWeb) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final freeBytes = await _queryFreeStorageBytes(directory.path);

      if (freeBytes == null) {
        return;
      }

      state = state.copyWith(
        freeStorageBytes: freeBytes,
        showStorageWarning: freeBytes < AppState.minFreeStorageBytes,
      );
    } catch (e) {}
  }

  /// Свободное место на диске рядом с базой.
  ///
  /// `PlatformInfo`/`runProcess` вместо `Platform`/`Process.run` напрямую —
  /// тот же приём, что уже применён в `lib/data/database/database_connection.dart`
  /// и `lib/core/logging/setup_log_sink.dart`: `dart:io` не может быть
  /// импортирован в файле, до которого дотягивается путь входа
  /// (`login_controller.dart` → `appStateProvider`), а `PlatformInfo`/
  /// `host_process.dart` прячут его за условным импортом, который сторож
  /// слоёв заведомо не разбирает (см. `_exploreDownward` в
  /// `test/architecture/layering_test.dart` — условный импорт вне области
  /// проверки специально, чтобы не наказывать именно этот приём).
  Future<int?> _queryFreeStorageBytes(String path) async {
    try {
      if (PlatformInfo.isWindows) {
        final drive = path.length >= 2 && path[1] == ':'
            ? path.substring(0, 2)
            : 'C:';
        final result = await runProcess('powershell', [
          '-NoProfile',
          '-Command',
          "(Get-PSDrive -Name '${drive[0]}').Free",
        ]);
        if (result.exitCode == 0) {
          final value = int.tryParse(result.stdout.trim());
          if (value != null && value >= 0) return value;
        }
        return null;
      }

      if (PlatformInfo.isLinux || PlatformInfo.isMacOS) {
        final result = await runProcess('df', ['-k', path]);
        if (result.exitCode == 0) {
          final lines = const LineSplitter()
              .convert(result.stdout)
              .where((l) => l.trim().isNotEmpty)
              .toList();
          if (lines.length >= 2) {
            final cols = lines.last.trim().split(RegExp(r'\s+'));
            if (cols.length >= 4) {
              final availKb = int.tryParse(cols[3]);
              if (availKb != null && availKb >= 0) return availKb * 1024;
            }
          }
        }
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void setPosInfo({String? name}) {
    state = state.copyWith(posName: name, clearPosName: name == null);
  }

  void setUserInfo({
    int? id,
    String? name,
    int? role,
    Set<String>? permissions,
  }) {
    state = state.copyWith(
      userId: id,
      clearUserId: id == null,
      userName: name,
      clearUserName: name == null,
      userRole: role,
      clearUserRole: role == null,
      permissions: permissions,
    );
  }

  @visibleForTesting
  void setTestUser({required int userId, String? userName}) {
    state = state.copyWith(userId: userId, userName: userName ?? 'Test User');
  }

  void setShift(ShiftStatus shift) {
    state = state.copyWith(shift: shift);
  }

  void setConnectionStatus(ConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }

  void dismissStorageWarning() {
    state = state.copyWith(showStorageWarning: false);
  }

  void setOperatingMode(OperatingMode mode) {
    state = state.copyWith(operatingMode: mode);
  }

  void logout() {
    state = state.copyWith(
      clearUserId: true,
      clearUserName: true,
      clearUserRole: true,
      permissions: const {},
      // Вышедший — смену больше никто не спрашивал (задача 47).
      shift: ShiftStatus.unknown,
    );
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);

final currentTimeProvider = Provider<String>((ref) {
  return ref.watch(appStateProvider.select((s) => s.currentTime));
});

final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  return ref.watch(appStateProvider.select((s) => s.connectionStatus));
});

final userNameProvider = Provider<String?>((ref) {
  return ref.watch(appStateProvider.select((s) => s.userName));
});

final posNameProvider = Provider<String?>((ref) {
  return ref.watch(appStateProvider.select((s) => s.posName));
});

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  return ref.watch(appStateProvider.select((s) => s.hasPermission(permission)));
});

final currentUserIdProvider = Provider<int?>((ref) {
  return ref.watch(appStateProvider.select((s) => s.userId));
});

final shiftStatusProvider = Provider<ShiftStatus>((ref) {
  return ref.watch(appStateProvider.select((s) => s.shift));
});

final operatingModeProvider = Provider<OperatingMode>((ref) {
  return ref.watch(appStateProvider.select((s) => s.operatingMode));
});

// `currentUserProvider` (полная запись `User` вошедшего) переехал в
// `current_user_provider.dart`, в этом же каталоге. Не здесь: этот файл
// импортируется путём входа (`login_controller.dart`), а тот провайдер
// читает `AppDatabase` напрямую — держать его тут значило бы вернуть в
// охраняемый каталог ровно то нарушение И5, ради которого сторож заведён.
// `login_controller.dart` этому провайдеру не пользуется вовсе: имя, роль и
// id вошедшего уже приезжают в `AuthSession` и лежат в `AppState.userId`/
// `userName`/`userRole` — см. `currentUserIdProvider`/`userNameProvider`
// выше.
