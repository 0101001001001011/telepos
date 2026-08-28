import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

class NoOpEsfProvider implements EsfProvider {
  const NoOpEsfProvider();

  @override
  String get id => 'noop';

  @override
  EsfCapabilities get capabilities => EsfCapabilities.none;

  @override
  String? validateConfig(EsfSettings config) => null;

  @override
  Future<EsfResult> submit(EsfInvoice invoice) async =>
      EsfResult.unsupported('submit');

  @override
  Future<EsfResult> getStatus(String registrationNumber) async =>
      EsfResult.unsupported('getStatus');

  @override
  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason}) async =>
      EsfResult.unsupported('revoke');

  @override
  Future<EsfProviderStatus> providerStatus(EsfSettings config) async =>
      EsfProviderStatus.notConfigured();
}
