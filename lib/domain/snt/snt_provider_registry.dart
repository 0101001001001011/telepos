import 'package:telepos/domain/snt/noop_snt_provider.dart';
import 'package:telepos/domain/snt/snt_provider.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

typedef SntProviderBuilder = SntProvider Function(SntSettings settings);

class SntProviderRegistry {
  SntProviderRegistry();

  final Map<SntProviderType, SntProviderBuilder> _builders = {};

  void register(SntProviderType type, SntProviderBuilder builder) {
    _builders[type] = builder;
  }

  bool isRegistered(SntProviderType type) => _builders.containsKey(type);

  SntProvider resolve(SntSettings settings) {
    if (!settings.isActive) {
      return const NoOpSntProvider();
    }
    final builder = _builders[settings.providerType];
    if (builder == null) {
      return const NoOpSntProvider();
    }
    return builder(settings);
  }
}
