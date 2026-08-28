import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/services/update/update_state.dart';
import 'package:telepos/core/services/update/updater_service.dart';

class UpdateNotifier extends Notifier<UpdateState> {
  late final UpdaterService _updaterService;
  StreamSubscription<UpdateState>? _subscription;

  @override
  UpdateState build() {
    _updaterService = GetIt.I<UpdaterService>();

    _subscription = _updaterService.stateStream.listen((newState) {
      state = newState;
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _updaterService.state;
  }

  Future<void> checkForUpdates() async {
    await _updaterService.checkForUpdates();
  }

  Future<void> downloadUpdate() async {
    await _updaterService.downloadUpdate();
  }

  Future<void> installUpdate() async {
    await _updaterService.installUpdate();
  }

  void skipUpdate() {
    _updaterService.skipUpdate();
  }

  void reset() {
    _updaterService.reset();
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

final isUpdateAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(updateProvider);
  return state.status == UpdateStatus.available ||
      state.status == UpdateStatus.ready;
});
