import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_state_source.dart';
import 'package:telepos/domain/startup/startup_state_repository.dart';
import 'package:telepos/domain/wire/setup_state.dart';

/// Reads startup state straight from the local database — the binding a
/// desktop till or the appliance uses.
///
/// Сборка состояния живёт в [watchSetupStateOf]
/// (`lib/data/setup/setup_state_source.dart`), а не здесь: её читает ещё
/// подписка провода `setup.state`, и раньше эти читатели расходились в том,
/// что считать настроенной установкой. См. доку того файла.
class LocalStartupStateRepository implements StartupStateRepository {
  LocalStartupStateRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<SetupState> watch() => watchSetupStateOf(_db);
}
