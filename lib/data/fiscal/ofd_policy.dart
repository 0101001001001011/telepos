/// Нужен ли этому чеку фискальный документ.
///
/// **Извлечено из `SaleUseCaseImpl._isOfd` задачей 16** и не переписано:
/// тело ниже — то же самое, что стояло там, до последней ветки `default`.
/// Причина извлечения названа точно: с задачи 16 фискализацию исполняет
/// `LocalPaymentService` (там же, где печать и ящик), а признак `isOfd`
/// по-прежнему нужен `SaleUseCaseImpl` — для ЭСФ. Скопировать политику в
/// два места значило бы завести два ответа на один вопрос: настройка
/// `ThisPos.ofdSyncType` меняется в одном экране, а расходиться начали бы
/// фискальный чек и ЭСФ.
library;

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/payment_kind_resolver_impl.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

/// Режимы `ThisPos.ofdSyncType`.
///
/// `0` — фискализовать всё; `1` — по признаку чека (выборочно); `2` —
/// только безналичные чеки целиком; всё прочее — как `0`.
Future<bool> isOfdSale({
  required AppDatabase db,
  required FiscalService? fiscal,
  required List<PaymentEntry> payments,
  required bool selectiveOfd,
}) async {
  if (fiscal == null) return false;
  if (!await fiscal.isEnabled()) return false;

  final thisPos = await db.thisPosDao.get();
  final ofdSyncType = thisPos?.ofdSyncType ?? 0;

  switch (ofdSyncType) {
    case 0:
      return true;
    case 1:
      return selectiveOfd;
    case 2:
      if (payments.isEmpty) return false;
      // **Вид оплаты, а не род счёта** — задача 14. До неё «безналичный
      // чек» означало «все строки лежат на счёте рода `customBank`», и
      // это было одним из десяти мест, выводивших вид из счёта.
      // Разъезжалось оно с остальными: чек, оплаченный картой на счёт
      // кассы (умолчание экрана, когда банковских счетов не видно),
      // считался наличным и в ОФД не уезжал.
      //
      // Спрашивается **фискальная трактовка**, потому что вопрос здесь
      // фискальный: «этот чек безналичный с точки зрения оператора».
      //
      // Довод «бонус безналичным чек не делает» стоял здесь до ревизии
      // 2026-09-19 и был верен ровно наполовину: бонус и правда не
      // безналичные деньги, но из этого выводилось, что чек с бонусной
      // строкой оператору не уезжает **вовсе**, — а это уже неправда про
      // картовую часть того же чека.
      final resolver = PaymentKindResolver(db);
      // **Настройки зачёта — тем же сторожем, что у продажи и возврата.**
      // `effectiveTreatment` отвечает не полем справочника, а полем с
      // поправкой на «деньги уже фискализованы»: зачёт аванса при
      // включённом чеке приёма перестаёт быть наличными и становится
      // зачётом. Без этого вопроса чек «карта + зачёт аванса» решался бы
      // по устаревшей букве справочника — наличной строкой, которой в нём
      // нет.
      final offsetSettings = await db.thisPosDao.offsetFiscalSettings();
      final lines = <FiscalTreatment>[];
      for (final p in payments) {
        final kind = await resolver.resolve(
          kindId: p.kindId,
          payeeAccountId: p.payeeAccountId,
        );
        // **Вид определить нечем — не довод ни за, ни против** (ревизия
        // 2026-09-19). Раньше такая строка уводила чек мимо оператора:
        // `kind == null → return false`. Это ровно то молчание, которое
        // здесь и чинится, только по другой причине — «не знаю» выдавалось
        // за «наличный чек». Строка выпадает из состава; если живых
        // безналичных денег в чеке больше нет, чек и так не уедет.
        //
        // Предел назван: продажа с таким видом на этой кассе невозможна
        // (`LocalPaymentService._requireKindActive` отказывает), так что
        // сюда доезжают только строки с чужой кассы или до v41.
        if (kind == null) continue;
        lines.add(offsetSettings.effectiveTreatment(kind));
      }
      // **Состав чека, а не каждая строка по отдельности** — ревизия
      // 2026-09-19, и разбор целиком в [FiscalTreatment.receiptIsCashless].
      // Коротко: «все строки безналичны» означало, что гашение
      // сертификата, бонус и долг **уводят чек мимо оператора**, хотя ни
      // одна из этих строк не наличные деньги. Чек «карта + сертификат»
      // не уезжал вовсе: деньги взяты, документа нет, кассир видит
      // обычную продажу.
      return FiscalTreatment.receiptIsCashless(lines);
    default:
      return true;
  }
}
