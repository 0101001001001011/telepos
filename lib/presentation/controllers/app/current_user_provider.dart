import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../data/database/app_database.dart';
import 'app_state_controller.dart';

/// Вошедший кассир целиком — для экранов, которым мало `userId`/`userName`
/// из `AppState`.
///
/// Единственный сегодняшний потребитель — `staff_chat_screen.dart`, которому
/// нужен `User.telegramId`, а его в `AuthSession`/`AppState` нет. Этот файл —
/// не `app_state_controller.dart` намеренно: тот импортируется путём входа
/// (`login_controller.dart` → `appStateProvider`), а `lib/presentation/screens/auth`
/// и `lib/presentation/controllers/auth` — под сторожем слоёв (И5), которому
/// `AppDatabase` в этой цепочке запрещена. `staff_chat_screen.dart` под
/// сторожем не стоит, так что здесь чтение базы остаётся прямым, а не через
/// отдельный доменный контракт: два места делать одно и то же ради одного
/// потребителя обошлось бы дороже, чем то, что контракт экономит.
final currentUserProvider = FutureProvider<User?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  if (!GetIt.I.isRegistered<AppDatabase>()) return null;

  final db = GetIt.I<AppDatabase>();
  return db.userDao.findById(userId);
});
