import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';

void setupMockGetIt() {
  final getIt = GetIt.I;

  if (getIt.isRegistered<Talker>()) return;

  getIt.registerSingleton<Talker>(Talker());
}

void tearDownMockGetIt() {
  final getIt = GetIt.I;
  getIt.reset();
}

Future<AppDatabase> setupIntegrationGetIt() async {
  final getIt = GetIt.I;

  if (!getIt.isRegistered<Talker>()) {
    getIt.registerSingleton<Talker>(Talker());
  }

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  if (!getIt.isRegistered<AppDatabase>()) {
    getIt.registerSingleton<AppDatabase>(db);
  }

  return db;
}

Future<void> tearDownIntegrationGetIt() async {
  final getIt = GetIt.I;

  if (getIt.isRegistered<AppDatabase>()) {
    final db = getIt<AppDatabase>();
    await db.close();
  }

  await getIt.reset();
}
