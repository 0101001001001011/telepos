import 'package:drift/native.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/currency_service_impl.dart';
import 'package:telepos/domain/services/currency_service.dart';

/// Служба валюты для проб, рисующих экраны с деньгами.
///
/// # Зачем
///
/// 2026-09-22 из экранов убраны 52 зашитых `₸`: знак валюты берётся у кассы
/// (`tillCurrencySymbol`). Развилки «а если службы нет» намеренно НЕ
/// заведено: на кассе она есть всегда, а пустой знак у денежного поля
/// выглядел бы оплошностью вёрстки, а не отсутствием настройки.
///
/// Значит проба, рисующая такой экран, обязана собрать тот же граф, что и
/// касса. Это не поблажка среде, а наоборот: среда перестаёт быть добрее
/// продукта — экран без службы валюты падает и в пробе, и на кассе.
///
/// Служба берётся **настоящая** (`CurrencyServiceImpl`), а не заглушка: она
/// читает страну и валюту из `this_pos_entries`, и подменять это чтение
/// значило бы проверять не то.
void registerTillCurrency({AppDatabase? db, Talker? logger}) {
  if (GetIt.I.isRegistered<CurrencyService>()) return;
  final database =
      db ??
      (GetIt.I.isRegistered<AppDatabase>()
          ? GetIt.I<AppDatabase>()
          : AppDatabase.forTesting(NativeDatabase.memory()));
  GetIt.I.registerSingleton<CurrencyService>(
    CurrencyServiceImpl(
      db: database,
      logger:
          logger ??
          (GetIt.I.isRegistered<Talker>() ? GetIt.I<Talker>() : Talker()),
    ),
  );
}
