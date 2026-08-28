/// Один сторож на все слушатели одной кассы.
///
/// # Почему сборка не в `domain/`
///
/// `WireGuard` (`lib/domain/wire/wire_guard.dart`) ничего не знает ни о
/// базе, ни о `AppDatabase` — состояние настройки он принимает функцией,
/// доводом. Но настоящая касса читает это состояние всегда одним и тем же
/// способом — [readSetupStateOf], а это уже слой `data/`: домену туда ходить
/// нельзя. Поэтому сборка, повторявшаяся дословно в `main.dart`, `wt_stand.dart`
/// и трёх тестовых наборах, живёт здесь, слоем ниже, рядом с `ApiServer`
/// (`api_server.dart`), у которого база уже есть.
library;

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/setup/setup_state_source.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

/// Сторож с настоящим состоянием настройки — той же базы, что видит сама
/// касса. [access] и [sessions] называются доводом, а не собираются здесь:
/// у настоящей кассы это `ApiServer.access` и `SessionRegistry`, у тестов —
/// свой словарь и своя подделка `SessionLookup`.
WireGuard wireGuardForTill({
  required AppDatabase db,
  required Map<String, WireAccess> access,
  required SessionLookup sessions,
}) => WireGuard(
  access: access,
  sessions: sessions,
  isTillConfigured: () async => (await readSetupStateOf(db)).configured,
  // Регрессия фазы 3/4 закрытия долга: терминал самой кассы — законный
  // второй владелец у `TerminalOwnership.same` (см. докстринг в
  // `wire_guard.dart`). `terminalDao.self()` не бросает на ненастроенной
  // кассе — просто отдаёт `null`, ровно то, что здесь и нужно.
  selfTerminalId: () async => (await db.terminalDao.self())?.id,
);
