import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

class SntCapabilities {
  const SntCapabilities({
    this.canSubmit = false,
    this.canConfirmInbound = false,
    this.canRevoke = false,
    this.queriesLiveBalance = false,
  });

  final bool canSubmit;

  final bool canConfirmInbound;

  final bool canRevoke;

  final bool queriesLiveBalance;

  static const SntCapabilities none = SntCapabilities();
}

abstract interface class SntProvider {
  String get id;

  SntCapabilities get capabilities;

  String? validateConfig(SntSettings config);

  Future<SntResult> authorize(SntSettings config);

  Future<SntResult> submit(SntDocument doc);

  Future<SntResult> confirmInbound(SntDocument doc);

  Future<SntResult> rejectInbound(SntDocument doc, {String? reason});

  Future<SntResult> revoke(SntDocument doc, {String? reason});
}
