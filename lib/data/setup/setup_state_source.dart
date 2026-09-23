/// Откуда касса берёт [SetupState] — один раз и потоком.
///
/// # Зачем отдельный файл
///
/// Читателей у этого состояния два: подписка провода `setup.state` и локальный
/// `StartupStateRepository`, которым пользуется десктопная касса. Третьим был
/// `GET /api/setup/state`, снятый 2026-08-05 вместе с остальными маршрутами
/// данных. Собирали они его по-разному, и разница уже
/// была видна: `readSetupState` считал установку настроенной по непустому
/// `companyName`, а `LocalStartupStateRepository.isConfigured()` — по
/// `ThisPosDao.exists()`, то есть по `companyName != null`. Установка с пустой
/// строкой в этом поле выглядела настроенной для одного читателя и
/// ненастроенной для другого. Здесь определение одно.
///
/// # Почему подписка читает тем же кодом, что и вопрос
///
/// [watchSetupStateOf] не собирает состояние заново — оно зовёт
/// [readSetupStateOf] на каждое изменение таблиц. Подписка и вопрос,
/// читающие по-разному, дали бы два ответа на один вопрос, и разошлись бы они
/// молча. Как устроен сигнал об изменении — `lib/data/database/watch_source.dart`.
library;

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/watch_source.dart';
import 'package:telepos/domain/wire/setup_state.dart';

/// Состояние установки на этот момент.
Future<SetupState> readSetupStateOf(AppDatabase db) async {
  final config = await db.thisPosDao.get();
  return SetupState(
    // Пустая строка — не имя. Тот же признак, что был у `readSetupState`, и
    // теперь единственный: см. доку файла.
    configured: config != null && (config.companyName ?? '').isNotEmpty,
    hasUsers: await db.userDao.hasUsers(),
    companyName: config?.companyName,
    cashBoxName: config?.cashBoxName,
    countryCode: config?.countryCode,
  );
}

/// Состояние установки сейчас и при каждом его изменении.
///
/// Таблиц две, и меняются они независимо: мастер настройки пишет
/// `ThisPosEntries`, заведение кассира — `Users`. Состояние при этом одно, и
/// приходит оно одним значением: половина его была бы утверждением про вторую
/// половину, которого никто не делал.
Stream<SetupState> watchSetupStateOf(AppDatabase db) =>
    watchTables(db, [db.thisPosEntries, db.users], () => readSetupStateOf(db));
