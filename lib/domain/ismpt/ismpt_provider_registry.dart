import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/domain/ismpt/noop_ismpt_provider.dart';

enum IsMptBackend {
  none(value: 0, label: 'Без интеграции ИС МПТ', id: 'none'),

  live(value: 1, label: 'ИС МПТ (ismet.kz / Tañba)', id: 'ismpt_live');

  const IsMptBackend({
    required this.value,
    required this.label,
    required this.id,
  });

  final int value;
  final String label;
  final String id;

  static IsMptBackend fromValue(int value) => IsMptBackend.values.firstWhere(
    (t) => t.value == value,
    orElse: () => IsMptBackend.none,
  );

  static IsMptBackend fromId(String? id) => IsMptBackend.values.firstWhere(
    (t) => t.id == id,
    orElse: () => IsMptBackend.none,
  );
}

typedef IsMptServiceBuilder = IsMptService Function();

class IsMptProviderRegistry {
  IsMptProviderRegistry();

  final Map<IsMptBackend, IsMptServiceBuilder> _builders = {};

  void register(IsMptBackend backend, IsMptServiceBuilder builder) {
    _builders[backend] = builder;
  }

  bool isRegistered(IsMptBackend backend) => _builders.containsKey(backend);

  IsMptService resolve(IsMptBackend backend) {
    if (backend == IsMptBackend.none) return const NoOpIsMptProvider();
    final builder = _builders[backend];
    if (builder == null) return const NoOpIsMptProvider();
    return builder();
  }
}
