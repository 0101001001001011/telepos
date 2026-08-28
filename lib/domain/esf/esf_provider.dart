import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

class EsfCapabilities {
  const EsfCapabilities({
    this.supportsSubmit = false,
    this.supportsRevoke = false,
    this.supportsIncoming = false,
    this.requiresEcp = false,
  });

  final bool supportsSubmit;

  final bool supportsRevoke;

  final bool supportsIncoming;

  final bool requiresEcp;

  static const EsfCapabilities none = EsfCapabilities();
}

abstract interface class EsfProvider {
  String get id;

  EsfCapabilities get capabilities;

  String? validateConfig(EsfSettings config);

  Future<EsfResult> submit(EsfInvoice invoice);

  Future<EsfResult> getStatus(String registrationNumber);

  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason});

  Future<EsfProviderStatus> providerStatus(EsfSettings config);
}
