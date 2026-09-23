import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

/// Провайдер СНТ, который **ничего не умеет и об этом говорит**.
///
/// Подставляется реестром, когда оператор СНТ не выбран либо выбран, но не
/// зарегистрирован; существует ради необнуляемого порта.
///
/// **Контракт: каждый член возвращает названный отказ.** До переименования
/// здесь стоял `NoOpSntProvider`, и он лгал дважды подряд, в паре:
/// объявлял `canConfirmInbound: true` — и следом [confirmInbound] отвечал
/// `SntResult.ok(status: SntStatus.confirmed)`. То есть **подтверждал
/// входящую накладную, которой никто не видел**: в ИС ЭСФ не уходило ничего,
/// а на кассе документ отмечался принятым. Объявление возможности и было тем,
/// что заводило вызывающего в этот путь.
class RefusingSntProvider implements SntProvider {
  const RefusingSntProvider();

  @override
  String get id => 'refusing';

  @override
  SntCapabilities get capabilities => SntCapabilities.none;

  @override
  String? validateConfig(SntSettings config) => _reason;

  @override
  Future<SntResult> authorize(SntSettings config) async =>
      SntResult.notConfigured();

  @override
  Future<SntResult> submit(SntDocument doc) async => SntResult.notConfigured();

  @override
  Future<SntResult> confirmInbound(SntDocument doc) async =>
      SntResult.notConfigured();

  @override
  Future<SntResult> rejectInbound(SntDocument doc, {String? reason}) async =>
      SntResult.notConfigured();

  @override
  Future<SntResult> revoke(SntDocument doc, {String? reason}) async =>
      SntResult.notConfigured();

  static const String _reason = 'СНТ / Виртуальный склад не настроены';
}
