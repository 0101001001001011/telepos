import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/noop_fiscal_provider.dart';

typedef FiscalProviderBuilder =
    FiscalProvider Function(FiscalSettings settings);

class FiscalProviderRegistry {
  FiscalProviderRegistry();

  final Map<FiscalOperatorType, FiscalProviderBuilder> _builders = {};

  void register(FiscalOperatorType type, FiscalProviderBuilder builder) {
    _builders[type] = builder;
  }

  bool isRegistered(FiscalOperatorType type) => _builders.containsKey(type);

  FiscalProvider resolve(FiscalSettings settings) {
    if (settings.operatorType == FiscalOperatorType.none) {
      return const NoOpFiscalProvider();
    }
    final builder = _builders[settings.operatorType];
    if (builder == null) {
      return const NoOpFiscalProvider();
    }
    return builder(settings);
  }
}
