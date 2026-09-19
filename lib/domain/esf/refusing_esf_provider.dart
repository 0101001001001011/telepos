import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

/// Провайдер ЭСФ, который **ничего не умеет и об этом говорит**.
///
/// Подставляется реестром, когда оператор ЭСФ не выбран либо выбран, но не
/// зарегистрирован; существует ради необнуляемого порта.
///
/// **Контракт: каждый член возвращает названный отказ.** До переименования
/// здесь стоял `NoOpEsfProvider`; лгал он одним членом — [validateConfig]
/// возвращал `null`, то есть «настройки годны», у провайдера, у которого
/// настроек нет вовсе. Экран настроек принимал пустую форму за исправную.
class RefusingEsfProvider implements EsfProvider {
  const RefusingEsfProvider();

  @override
  String get id => 'refusing';

  @override
  EsfCapabilities get capabilities => EsfCapabilities.none;

  @override
  String? validateConfig(EsfSettings config) => _reason;

  @override
  Future<EsfResult> submit(EsfInvoice invoice) async =>
      EsfResult.notConfigured();

  @override
  Future<EsfResult> getStatus(String registrationNumber) async =>
      EsfResult.notConfigured();

  @override
  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason}) async =>
      EsfResult.notConfigured();

  @override
  Future<EsfProviderStatus> providerStatus(EsfSettings config) async =>
      EsfProviderStatus.notConfigured();

  static const String _reason = 'Оператор ЭСФ не настроен';
}
