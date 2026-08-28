import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

class NoOpSntProvider implements SntProvider {
  const NoOpSntProvider();

  @override
  String get id => 'noop';

  @override
  SntCapabilities get capabilities =>
      const SntCapabilities(canConfirmInbound: true);

  @override
  String? validateConfig(SntSettings config) => null;

  @override
  Future<SntResult> authorize(SntSettings config) async => SntResult.ok();

  @override
  Future<SntResult> submit(SntDocument doc) async =>
      SntResult.unsupported('submit (требуется ЭЦП и учётная запись ИС ЭСФ)');

  @override
  Future<SntResult> confirmInbound(SntDocument doc) async =>
      SntResult.ok(status: SntStatus.confirmed);

  @override
  Future<SntResult> rejectInbound(SntDocument doc, {String? reason}) async =>
      SntResult.ok(status: SntStatus.rejected);

  @override
  Future<SntResult> revoke(SntDocument doc, {String? reason}) async =>
      SntResult.unsupported('revoke (требуется ЭЦП и учётная запись ИС ЭСФ)');
}
