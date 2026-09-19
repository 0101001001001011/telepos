import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/esf/refusing_esf_provider.dart';

typedef EsfProviderBuilder = EsfProvider Function(EsfSettings settings);

class EsfProviderRegistry {
  EsfProviderRegistry();

  final Map<EsfOperatorType, EsfProviderBuilder> _builders = {};

  void register(EsfOperatorType type, EsfProviderBuilder builder) {
    _builders[type] = builder;
  }

  bool isRegistered(EsfOperatorType type) => _builders.containsKey(type);

  EsfProvider resolve(EsfSettings settings) {
    if (!settings.isEnabled) {
      return const RefusingEsfProvider();
    }
    final builder = _builders[settings.operatorType];
    if (builder == null) {
      return const RefusingEsfProvider();
    }
    return builder(settings);
  }
}
