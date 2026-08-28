import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

abstract interface class EsfSoapTransport {
  bool get canSign;

  Future<EsfResult> importInvoice(EsfInvoice invoice, EsfSettings settings);

  Future<EsfResult> statusByRegistration(String registrationNumber);

  Future<EsfResult> revoke(
    EsfInvoice invoice,
    EsfSettings settings, {
    String? reason,
  });
}

class KgdEsfProvider implements EsfProvider {
  const KgdEsfProvider({this.transport, this.settings});

  final EsfSoapTransport? transport;

  final EsfSettings? settings;

  @override
  String get id => 'kgd_esf';

  @override
  EsfCapabilities get capabilities => const EsfCapabilities(
    supportsSubmit: true,
    supportsRevoke: true,
    supportsIncoming: true,
    requiresEcp: true,
  );

  @override
  String? validateConfig(EsfSettings config) {
    if (config.supplierBin == null || config.supplierBin!.isEmpty) {
      return 'Не указан БИН поставщика';
    }
    if (config.supplierBin!.length != 12) {
      return 'БИН поставщика должен содержать 12 цифр';
    }
    return null;
  }

  bool get _canSign => transport?.canSign ?? false;

  @override
  Future<EsfResult> submit(EsfInvoice invoice) async {
    if (!_canSign) {
      return EsfResult.accountRequired();
    }
    return transport!.importInvoice(invoice, _settingsHint);
  }

  @override
  Future<EsfResult> getStatus(String registrationNumber) async {
    if (!_canSign) return EsfResult.accountRequired();
    return transport!.statusByRegistration(registrationNumber);
  }

  @override
  Future<EsfResult> revoke(EsfInvoice invoice, {String? reason}) async {
    if (!_canSign) return EsfResult.accountRequired();
    return transport!.revoke(invoice, _settingsHint, reason: reason);
  }

  @override
  Future<EsfProviderStatus> providerStatus(EsfSettings config) async {
    final configured = config.isEnabled && config.hasSupplierRequisites;
    if (!configured) return EsfProviderStatus.notConfigured();
    if (!_canSign) {
      return const EsfProviderStatus(
        configured: true,
        canSubmit: false,
        reason:
            'Требуется ЭЦП НУЦ РК и профиль ИС ЭСФ — выписка недоступна (черновики сохраняются)',
      );
    }
    return const EsfProviderStatus(configured: true, canSubmit: true);
  }

  EsfSettings get _settingsHint => settings ?? EsfSettings.disabled();
}
