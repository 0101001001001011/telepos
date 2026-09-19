import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/esf/esf_settings_store.dart';
import 'package:telepos/data/fiscal/ofd_policy.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';
import 'package:telepos/domain/bonus/bonus_entry_kind.dart';
import 'package:telepos/domain/esf/esf_draft_builder.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_provider.dart';
import 'package:telepos/domain/esf/esf_provider_registry.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show payPrepaymentInsufficientCode;
import 'package:telepos/domain/sale/receipt_line.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';
import 'package:telepos/domain/usecases/wms/serial_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

class SaleUseCaseImpl implements SaleUseCase {
  SaleUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  static const int _pendingSync = 1;

  @override
  Future<void> perform({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required List<ReceiptLine> lines,
    required List<PaymentEntry> payments,
    required Decimal change,
    required bool selectiveOfd,
    String? customerBin,
    int? agentLocalId,
    int? agentServerId,
    List<CustomFieldEntry>? customFields,
    WithdrawalEntry? withdrawal,
    CreditContractDraft? credit,
  }) async {
    final isOfd = await _isOfd(payments, selectiveOfd);

    final shift = await _db.shiftDao.findOpenedShift();
    final userId = shift?.userId ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const saleState = _pendingSync;

    await _db.transaction(() async {
      // Формат завершённого чека — **первым делом и в этой же
      // транзакции** (задача 9). До неё это делал отдельный
      // `SaleCheckoutService.finalize` после `perform`, и был он мёртв:
      // подарок акции не доезжал до проданного чека никогда, а цена
      // единицы оставалась масштаба 10. Разбор — докстринг
      // `SaleUseCase.perform`.
      //
      // Строки правятся **на месте**, по номеру строки: с задачи 7 они
      // лежат в базе с первой команды корзины, и «удалить и вставить»
      // потеряло бы марки, модификаторы и доли гостей.
      for (final line in lines) {
        final id = int.tryParse(line.lineId);
        if (id == null) {
          // Идентификатор строки кассовой корзины — это `SaleProducts.id`
          // числом (`LocalCartService._viewOf`). Не разобрался — значит
          // снимок собран не тем, кем мы думаем, и молчать нельзя: тихий
          // пропуск оставил бы чеку цены корзины ровно тем способом,
          // который эта правка и убирает. Бросок откатывает транзакцию
          // целиком — денег с такого чека не берётся.
          throw StateError(
            'SaleUseCase: строка ${line.lineId} чека $receiptNo/$posId '
            'не называет строку базы',
          );
        }
        await (_db.update(
          _db.saleProducts,
        )..where((sp) => sp.id.equals(id))).write(
          SaleProductsCompanion(
            price: Value(line.price),
            priceBefore: Value(line.priceBefore),
          ),
        );

        // Происхождение скидки — **тем же оборотом, что и цены** (задача
        // 13). Разность `priceBefore − price`, которую строка выше
        // записывает, одинаково выглядит у подарка акции и у уступки
        // кассира, и восстановить её источник потом нечем: корзины, из
        // которой акция считалась, к этому моменту уже не существует.
        //
        // Прежние строки снимаются перед вставкой: повторная попытка
        // оплаты после отказа терминала — обычный путь, а не авария
        // (тем же доводом, что `paymentDao.deleteBySale` в подготовке), и
        // без этого чек копил бы происхождение от каждой попытки.
        await (_db.delete(_db.saleDiscounts)..where(
              (d) =>
                  d.receiptNo.equals(receiptNo) &
                  d.posId.equals(posId) &
                  d.saleProductId.equals(id),
            ))
            .go();
        await _db.saleDiscountDao.recordForLine(
          receiptNo: receiptNo,
          posId: posId,
          saleProductId: id,
          discounts: [
            for (final d in line.discounts)
              (origin: d.origin, sourceId: d.sourceId, amount: d.amount),
          ],
          at: now,
        );
      }

      await ((_db.update(_db.sales))..where(
            (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
          ))
          .write(
            SalesCompanion(
              state: const Value(saleState),
              // Сумма — тем же оборотом, что и состояние.
              //
              // **Честно: эту строку не краснит ни одна проба, и это
              // измерено диверсией, а не предположено.** `Sales.amount`
              // поддерживает каждая команда корзины (задача 7), и на всех
              // путях дерева тут пишется то же число, что уже лежит:
              // снятие строки оставило набор зелёным целиком.
              //
              // Оставлена намеренно. Вызывающий, который сеет строки чека
              // сам и зовёт этот метод с собственной суммой (так делают
              // журналы `test/e2e/` и стенды `test/integration/`),
              // корзинных команд не выполнял вовсе — для него это
              // единственная запись суммы. Убрать её значило бы сделать
              // правду о сумме зависимой от того, кто ещё её писал.
              amount: Value(amount),
              change: Value(change),
              time: Value(now),
              isOfd: Value(isOfd),
              customerBin: Value(customerBin),
              customerLocalId: Value(agentLocalId),
              customerServerId: Value(agentServerId),
              // Владелец имеет только чек в работе (state = 0) — правило
              // смысла `Sales.terminalId`. Завершение продажи — самый
              // частый переход состояния во всей системе (каждая оплата),
              // и до этой правки оно писало `state` в обход и `updateState`,
              // и терминала: чек уходил в «ожидает отправки», унося
              // устаревшего владельца, — а синхронизация между кассами
              // сломана (см. `project_telepos_couchdb_sync_broken`), так
              // что «пока не синхронизирован» может значить «навсегда».
              terminalId: const Value(null),
            ),
          );

      await _db.batch((batch) {
        // `seq` — **номер в этом списке, от нуля**, и ни в коем случае не
        // «максимум + 1» из базы. Уникальный ключ `Payments`
        // `{receiptNo, posId, seq}` защищает от двойного взятия денег
        // только пока номер считается от нуля на каждой попытке:
        // подготовка чека снимает платежи прошлой попытки
        // (`paymentDao.deleteBySale`), оба гонщика получают 0, 1, 2… и
        // сталкиваются. Нумерация, продолжающая прошлую попытку,
        // превратила бы ключ в украшение **молча** — гонщики получили бы
        // разные номера, набор остался бы зелёным, и узнать об этом было
        // бы неоткуда. Оговорка целиком — в докстринге
        // `Payments.uniqueKeys`; сторож — `payment_seq_from_zero_test`.
        for (final (index, p) in payments.indexed) {
          batch.insert(
            _db.payments,
            PaymentsCompanion.insert(
              userId: userId,
              receiptNo: Value(receiptNo),
              posId: Value(posId),
              payeeAccountId: p.payeeAccountId,
              amount: p.amount,
              time: now,
              state: const Value(saleState),
              customerLocalId: Value(p.customerLocalId),
              approvalCode: Value(p.approvalCode),
              cardMask: Value(p.cardMask),
              terminalTransactionId: Value(p.terminalTransactionId),
              kindId: Value(p.kindId),
              seq: Value(index),
              reference: Value(p.reference),
              providerCode: Value(p.providerCode),
            ),
          );
        }
      });

      // ── гашение сертификатов — задача 21 ───────────────────────────
      //
      // **В этой же транзакции, и это главное в задаче.** Гашение,
      // вынесенное наружу, ломается в обе стороны и обе стороны денежные:
      //
      // - списать до продажи — и упавшая продажа оставляет сертификат
      //   погашенным. Покупатель отдал бумажку и не получил товара;
      // - списать после продажи — и упавшее списание оставляет чек
      //   оплаченным сертификатом, у которого остаток не тронут. Товар
      //   отдан, а бумажка снова годна: **подарок, повторяемый
      //   бесконечно**.
      //
      // Здесь же и **настоящий заслон от двойного гашения**:
      // `CertificateDao.redeem` — одна условная инструкция, и ноль
      // затронутых строк означает, что остаток перестал покрывать сумму
      // между раскладкой и этой точкой. Бросок откатывает транзакцию
      // целиком — ни чека, ни строк оплаты, ни списанного товара.
      //
      // Проверка раскладки (`_plan` спрашивает остаток) заслоном **не
      // является** и не притворяется им: между чтением остатка и записью
      // помещается чужая транзакция. Она существует ради слова кассиру —
      // «сертификат просрочен», «на нём ничего не осталось», — а не ради
      // денег.
      //
      // # Оговорка тому, кто будет сводить это с общей ветвью зачёта
      //
      // Задача 23 (предоплата) завела ниже по циклу общую ветвь
      // `isOffset && !isBonus`, и вопрос «не дубль ли это» законный.
      // Ответ: **нет, и вот граница.**
      //
      // Тот цикл отвечает на вопрос «куда двинуть счёт». Этот — на вопрос
      // «на чём уменьшить остаток бумажки», и второго такого вопроса в
      // дереве нет: у предоплаты **своего остатка не существует вовсе**
      // (спека, ярус 6: «ни своей таблицы, ни своего остатка»), она вся
      // помещается в строку `Payments` с документом в `reference`. Свести
      // эти два цикла значило бы попросить общую ветвь гасить то, чего у
      // половины её случаев нет.
      //
      // **Что свести можно и нужно — движение по счёту.** Строка
      // сертификата идёт по общей ветви зачёта ниже без единой правки,
      // если та не переворачивает знак руками: род
      // `AccountType.certificateLiability` объявлен в
      // `AccountPosting.isRedemption`, и `post(+amount)` уменьшает
      // обязательство сам. Ветвь, пишущая знак у себя, разошлась бы с
      // правилом — и это то место, где сведение надо проверить числом, а
      // не чтением.
      for (final p in payments) {
        final number = p.reference;
        if (number == null) continue;
        if (!await _isCertificateKind(p.kindId)) continue;
        final touched = await _db.certificateDao.redeem(
          number: number,
          amount: p.amount,
        );
        if (touched == 0) {
          _logger.warning(
            'SaleUseCase: certificate $number no longer covers ${p.amount} '
            '— receipt $receiptNo/$posId rolled back',
          );
          throw WireRefusal(
            certificateRaceCode,
            'остаток сертификата $number изменился — повторите оплату',
          );
        }
      }

      // ── договор рассрочки — задача 24 ─────────────────────────────
      //
      // **В этой же транзакции, и по тому же доводу, что гашение
      // сертификата.** Договор, заведённый отдельно, ломается в обе
      // стороны, и обе денежные:
      //
      // - завести до продажи — и упавшая продажа вешает на покупателя
      //   долг за товар, которого он не получил;
      // - завести после — и упавшее заведение оставляет чек, оплаченный
      //   рассрочкой, у которой договора нет. Товар отдан, обязательства
      //   нет, а чек при этом **сходится по строкам** — заметить нечем.
      //
      // Ставится **после строк оплаты** намеренно: тело договора обязано
      // совпасть со строкой вида `installment`, и сверка ниже сравнивает
      // не намерение, а записанное.
      if (credit != null) {
        // Номер выдаёт **касса** (шаг 5), и выдаёт его из номера чека:
        // своего счётчика у договора нет и не надо — счётчик чеков
        // (`ReceiptNumbers.withNext`) уже закрепляет номер атомарно, а
        // второй счётчик рядом был бы вторым ответом на вопрос «какой это
        // договор». Номер, введённый руками, повторяется, а по нему ищут
        // погашение.
        final number = CreditContractNumber.of(
          receiptNo: receiptNo,
          posId: posId,
        );

        // **Сверка тела договора со строкой оплаты — не формальность.**
        // Раскладка считает остаток чека и кладёт его дважды: строкой
        // `Payments` и черновиком договора. Разойдись они — и покупатель
        // подписал бы график на одну сумму, а должен был бы другую;
        // «Σ строк оплаты == сумма чека» это не заметит, потому что
        // договор в эту сумму не входит вовсе.
        final installmentLine = payments
            .where((p) => p.kindId == SystemPaymentKindIds.installment)
            .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
        if (installmentLine != credit.principal) {
          throw WireRefusal(
            creditPrincipalInvalidCode,
            'тело договора ${credit.principal} не равно строке рассрочки '
            '$installmentLine в чеке $receiptNo/$posId',
          );
        }

        // График строится **здесь и один раз**, и с этой минуты он
        // подписан: дальше его только читают. Первый срок — через месяц
        // после подписи; прижатие дня к концу месяца делает
        // `InstallmentScheduler` (31 января + месяц это 28 февраля, а не
        // 3 марта).
        final signedAt = DateTime.fromMillisecondsSinceEpoch(now * 1000);
        final schedule = InstallmentScheduler.build(
          principal: credit.principal,
          feeTotal: credit.feeTotal,
          termMonths: credit.termMonths,
          firstDueDate: DateTime(
            signedAt.year,
            signedAt.month + 1,
            signedAt.day,
          ),
          scheme: credit.scheme,
        );

        await _db.creditDao.insertContract(
          number: number,
          agentLocalId: credit.agentLocalId,
          receivableAccountId: credit.receivableAccountId,
          receiptNo: receiptNo,
          posId: posId,
          principal: credit.principal,
          feeTotal: credit.feeTotal,
          downPayment: credit.downPayment,
          termMonths: credit.termMonths,
          scheme: credit.scheme,
          signedAt: now,
          schedule: schedule,
          signedByUserId: userId,
        );

        _logger.info(
          'SaleUseCase: credit contract $number opened for '
          '${credit.principal} over ${credit.termMonths} months '
          '(${credit.scheme.code})',
        );
      }

      if (customFields != null && customFields.isNotEmpty) {
        await _db.batch((batch) {
          for (final cf in customFields) {
            batch.insert(
              _db.saleCustomFields,
              SaleCustomFieldsCompanion(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                customFieldId: Value(cf.customFieldId),
                customFieldItemId: Value(cf.customFieldItemId),
              ),
            );
          }
        });
      }

      if (withdrawal != null) {
        await _db
            .into(_db.saleWithdrawals)
            .insert(
              SaleWithdrawalsCompanion(
                receiptNo: Value(receiptNo),
                posId: Value(posId),
                agentAccountId: Value(withdrawal.agentAccountId),
                amount: Value(withdrawal.amount),
              ),
            );
      }

      final saleProducts = await _db.saleProductDao.findBySale(
        receiptNo,
        posId,
      );
      for (final sp in saleProducts) {
        await _db.productInfoDao.adjustQuantity(sp.ucode, -sp.quantity);

        await _depleteWmsStock(sp.ucode, sp.quantity);

        await _consumeSerials(
          ucode: sp.ucode,
          quantity: sp.quantity,
          receiptNo: receiptNo,
          userId: userId,
        );

        await _depleteDishIngredients(sp.ucode, sp.quantity);
      }

      // Движение, а не остаток: знак по роду счёта выбирает
      // `AccountPosting`, а не эта ветка. Ветка здесь и стояла — и была
      // единственным местом в дереве, которое про бонусный счёт знало;
      // возврат её не имел и списывал бонусы второй раз.
      //
      // Бонусный счёт с задачи 13 двигается **только журналом**: строка
      // `Payments` пишется всё равно (выше, и это не обсуждается — чек,
      // оплаченный бонусом целиком, без неё остался бы без единой строки
      // оплаты, и нарушать ключ гонщику стало бы нечего), а остаток
      // сдвигает запись журнала. Иначе движение существовало бы в двух
      // местах и объяснялось бы только в одном.
      //
      // Запись ложится **внутрь этой же транзакции**: чек, не
      // состоявшийся из-за нарушения ключа платежей, обязан не оставить
      // за собой ни движения бонусов, ни записи о нём
      // (`test/data/sale/payment_claim_race_test.dart`).
      //
      // **Строка обязательства (`PaymentSettlement.deferred`) счёт
      // обычным движением не двигает, и это не оговорка, а весь смысл
      // задачи 14.** До неё долг вообще не имел строки оплаты: он
      // выводился разностью «сумма чека минус сумма платежей», и
      // инвариант «Σ строк оплаты == сумма чека» был нарушен у каждой
      // продажи в долг. Теперь строка есть — но провести её тем же
      // `post(+amount)`, что и наличные, было бы прямой порчей: у счёта
      // рода `agentMain` знак движения не перевёрнут (`AccountPosting`),
      // и долг на 700 дал бы покупателю **+700**, то есть переплату, а
      // не задолженность.
      //
      // Поэтому обязательства из этого цикла исключены, а сумма, на
      // которую двигается счёт покупателя, считается **по недолговым
      // строкам** — ровно тем же выражением `amount − Σ`, что и раньше.
      // Число получается тем же самым: на продаже в долг 1000 с 300
      // наличными это по-прежнему −700. Одна правка меняет форму записи
      // и **не меняет ни одного остатка** — так и задумано.
      //
      // **Зачёт внесённого раньше (`PaymentSettlement.offset`) идёт
      // условной записью, а не `post` — задача 23.** Аванс лежит
      // кредитовым сальдо на расчётном счёте покупателя, и `post(+600)`
      // на нём был бы порчей того же класса, что и у долга, только в
      // другую сторону: знак у рода `agentMain` не перевёрнут, и зачёт
      // **увеличил** бы то, что касса должна покупателю, вместо того
      // чтобы уменьшить.
      //
      // Условность здесь не украшение. Остаток аванса прочитан
      // раскладкой (`LocalPaymentService._plan`) **до** этой транзакции,
      // и в окно между чтением и записью помещается второй чек того же
      // покупателя. Без условия оба зачли бы по 1000 с внесённой тысячи;
      // с условием второй получает названный отказ, и транзакция
      // откатывает его чек целиком — товар не уходит.
      //
      // Бонус сюда не попадает, хотя род расчёта у него тот же
      // (`offset`): его счёт бонусный, и ведает им журнал. Поэтому
      // условие ветви спрашивает **и род расчёта, и род счёта** —
      // `!isBonus && isOffset`, а не один из двух. Спроси оно только род
      // расчёта, и бонус пошёл бы условной записью мимо журнала;
      // спроси только род счёта — под условную запись попали бы
      // наличные на счёте кассы.
      var deferredSum = Decimal.zero;
      for (final p in payments) {
        if (await _isDeferredKind(p.kindId)) {
          deferredSum += p.amount;
          continue;
        }
        final account = await _db.accountDao.findById(p.payeeAccountId);
        if (account != null &&
            !BonusAccountTypes.isBonus(account.type) &&
            await _isOffsetKind(p.kindId)) {
          final claimed = await _db.accountDao.claimCredit(
            p.payeeAccountId,
            p.amount,
          );
          if (!claimed) {
            _logger.warning(
              'SaleUseCase: offset of ${p.amount} refused on account '
              '${p.payeeAccountId} — not enough left, receipt $receiptNo',
            );
            // # Код отказа выбирается по виду — правка слияния задачи 21
            //
            // Ветвь писала один код на всех, и была права: пока сюда
            // входил только аванс, «внесённого аванса не хватило» —
            // точное слово. Сертификат вошёл в ту же ветвь (его вид тоже
            // `offset`, а счёт не бонусный), и на кассе с двумя
            // терминалами эта ветка достижима **без всякого аванса**:
            // счёт обязательства у всех бумажек один, условная запись
            // читает его остаток заново, и два одновременных чека с
            // разными сертификатами дают одному из них ноль затронутых
            // строк.
            //
            // Кассиру тогда говорили бы про аванс, которого он не
            // вносил, и отправляли бы лечить не ту беду — ровно то, ради
            // чего задача 22 развела три кода QR вместо одного. Деньги
            // при этом целы в обоих случаях: транзакция откатывается.
            throw (await _isCertificateKind(p.kindId))
                ? const WireRefusal(
                    certificateRaceCode,
                    'остаток сертификата изменился — повторите оплату',
                  )
                : const WireRefusal(
                    payPrepaymentInsufficientCode,
                    'внесённого аванса не хватило: его уже зачли другим чеком',
                  );
          }
          continue;
        }
        if (account != null && BonusAccountTypes.isBonus(account.type)) {
          await _db.bonusEntryDao.record(
            accountId: p.payeeAccountId,
            kind: BonusEntryKind.redemption,
            amount: p.amount,
            receiptNo: receiptNo,
            posId: posId,
            userId: userId,
            at: now,
          );
          continue;
        }
        await _db.accountDao.post(p.payeeAccountId, p.amount);
      }

      if (agentLocalId != null) {
        final paymentSum =
            payments.fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount) -
            deferredSum;
        final debitAmount = amount - paymentSum;
        await _updateAgentBalance(agentLocalId, -debitAmount);
      }
    });

    _logger.info(
      'SaleUseCase: sale completed receipt=$receiptNo, '
      'amount=$amount, isOfd=$isOfd, payments=${payments.length}, '
      'lines=${lines.length}',
    );

    await _buildAndEnqueueEsf(
      receiptNo: receiptNo,
      posId: posId,
      amount: amount,
      customerBin: customerBin,
      userId: userId,
      time: now,
      change: change,
      isOfd: isOfd,
    );
  }

  @override
  Future<void> reverseSaleStock({
    required int receiptNo,
    required int posId,
  }) async {
    final saleProducts = await _db.saleProductDao.findBySale(receiptNo, posId);
    for (final sp in saleProducts) {
      if (sp.quantity <= Decimal.zero) continue;
      await _db.productInfoDao.adjustQuantity(sp.ucode, sp.quantity);
    }
  }

  Future<void> _buildAndEnqueueEsf({
    required int receiptNo,
    required int posId,
    required Decimal amount,
    required String? customerBin,
    required int userId,
    required int time,
    required Decimal change,
    required bool isOfd,
  }) async {
    try {
      final bin = customerBin?.trim();
      if (bin == null || bin.isEmpty) return;

      if (!GetIt.I.isRegistered<EsfDraftBuilder>() ||
          !GetIt.I.isRegistered<EsfProviderRegistry>() ||
          !GetIt.I.isRegistered<EsfSettingsStore>()) {
        return;
      }

      final settings = GetIt.I<EsfSettingsStore>().load();
      if (!settings.isEnabled) return;

      final saleRow = await _db.saleDao.findByKey(receiptNo, posId);
      if (saleRow == null) return;
      final saleProducts = await _db.saleProductDao.findBySale(
        receiptNo,
        posId,
      );
      if (saleProducts.isEmpty) return;

      final sale = SaleEntity(
        receiptNo: receiptNo,
        posId: posId,
        userId: userId,
        amount: amount,
        change: change,
        time: time,
        isOfd: isOfd,
        customerBin: bin,
        state: saleRow.state,
      );

      final lines = <EsfLineSpec>[];
      for (final sp in saleProducts) {
        final info = await _db.productInfoDao.findByUcode(sp.ucode);
        final vatRate = info?.vatRate;
        final EsfTaxMode? mode = vatRate == null ? null : EsfTaxMode.vat;
        lines.add(
          EsfLineSpec(
            product: SaleProductEntity(
              ucode: sp.ucode,
              quantity: sp.quantity,
              price: sp.price,
              priceBefore: sp.priceBefore,
            ),
            name: info?.name ?? 'Товар ${sp.ucode}',
            ntin: info?.ntin,
            vatMode: mode,
            vatRatePercent: vatRate != null ? Decimal.fromInt(vatRate) : null,
          ),
        );
      }

      final builder = GetIt.I<EsfDraftBuilder>();
      final guid = 'ESF-$posId-$receiptNo';
      final outcome = builder.buildFromSale(
        sale: sale,
        lines: lines,
        settings: settings,
        idempotencyKey: guid,
        accountingNumber: '$posId-$receiptNo',
      );

      if (!outcome.built) {
        _logger.info(
          'ЭСФ skipped for receipt=$receiptNo: '
          '${outcome.skipReason?.name}',
        );
        return;
      }

      final provider = GetIt.I<EsfProviderRegistry>().resolve(settings);
      final result = await provider.submit(outcome.invoice!);
      _logger.info(
        'ЭСФ draft enqueued for receipt=$receiptNo: '
        'queued=${result.queued} success=${result.success}',
      );
    } catch (e, stackTrace) {
      _logger.warning('ЭСФ post-sale hook error: $e', e, stackTrace);
    }
  }

  Future<void> _depleteWmsStock(int ucode, Decimal quantity) async {
    if (quantity <= Decimal.zero) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final pickedBatchIds = <int>{};
    final batches = await _db.batchDao.findActiveByUcode(ucode);
    await _reorderByPickingStrategy(batches);
    if (batches.isNotEmpty) {
      var remaining = quantity;
      for (final b in batches) {
        if (remaining <= Decimal.zero) break;
        final avail = b.currentQuantity;
        if (avail <= Decimal.zero) continue;
        final take = avail < remaining ? avail : remaining;
        await _db.batchDao.adjustQuantity(b.id, -take);
        if (avail - take <= Decimal.zero) {
          await _db.batchDao.updateBatch(
            b.id,
            const BatchesCompanion(isActive: Value(false)),
          );
        }
        pickedBatchIds.add(b.id);
        remaining -= take;
      }
    }

    final cells = await _db.cellStockDao.findByUcode(ucode);
    if (cells.isNotEmpty) {
      cells.sort((a, b) {
        final ap = pickedBatchIds.contains(a.batchId) ? 0 : 1;
        final bp = pickedBatchIds.contains(b.batchId) ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return a.id.compareTo(b.id);
      });
      var remaining = quantity;
      for (final c in cells) {
        if (remaining <= Decimal.zero) break;
        if (c.quantity <= Decimal.zero) continue;
        final take = c.quantity < remaining ? c.quantity : remaining;
        await _db.cellStockDao.upsertStock(
          CellStocksCompanion(
            id: Value(c.id),
            cellId: Value(c.cellId),
            ucode: Value(c.ucode),
            batchId: c.batchId == null
                ? const Value.absent()
                : Value(c.batchId),
            quantity: Value(c.quantity - take),
            reservedQty: Value(c.reservedQty),
            updatedAt: Value(now),
          ),
        );
        remaining -= take;
      }
    }
  }

  Future<void> _reorderByPickingStrategy(List<Batche> batches) async {
    if (batches.length < 2) return;
    var strategy = 'FEFO';
    try {
      if (GetIt.I.isRegistered<WmsConfigUseCase>()) {
        strategy = await GetIt.I<WmsConfigUseCase>().pickingStrategy();
      }
    } catch (_) {
      return;
    }
    switch (strategy) {
      case 'FIFO':
        batches.sort(
          (a, b) => (a.receivedDate ?? 0).compareTo(b.receivedDate ?? 0),
        );
        break;
      case 'LIFO':
        batches.sort(
          (a, b) => (b.receivedDate ?? 0).compareTo(a.receivedDate ?? 0),
        );
        break;
    }
  }

  Future<void> _consumeSerials({
    required int ucode,
    required Decimal quantity,
    required int receiptNo,
    required int userId,
  }) async {
    if (quantity <= Decimal.zero) return;
    try {
      if (!GetIt.I.isRegistered<WmsConfigUseCase>() ||
          !GetIt.I.isRegistered<SerialTrackingUseCase>()) {
        return;
      }
      final enabled = await GetIt.I<WmsConfigUseCase>().isModuleEnabled(
        'serialTracking',
      );
      if (!enabled) return;

      final toConsume = quantity.truncate().toBigInt().toInt();
      if (toConsume <= 0) return;

      final available = await _db.serialDao.findByStatus(0);
      final mine = available.where((s) => s.ucode == ucode).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final serialUc = GetIt.I<SerialTrackingUseCase>();
      final n = toConsume < mine.length ? toConsume : mine.length;
      for (var i = 0; i < n; i++) {
        await serialUc.markAsSold(
          mine[i].id,
          saleId: receiptNo,
          userId: userId,
        );
      }
    } catch (e, st) {
      _logger.warning('Serial consume error (ucode=$ucode): $e', e, st);
    }
  }

  Future<void> _depleteDishIngredients(int ucode, Decimal quantity) async {
    if (quantity <= Decimal.zero) return;

    final ingredients = await _db.dishIngredientDao.findByDish(ucode);
    if (ingredients.isEmpty) return;

    for (final ing in ingredients) {
      final consumed = ing.netQuantity * quantity;
      if (consumed <= Decimal.zero) continue;
      await _db.productInfoDao.adjustQuantity(ing.ingredientUcode, -consumed);
    }
  }

  /// Нужен ли чеку фискальный документ — **общая политика**, а не своя.
  ///
  /// Тело переехало в `lib/data/fiscal/ofd_policy.dart` задачей 16: тот же
  /// вопрос задаёт себе `LocalPaymentService`, когда фискализует чек, и
  /// два ответа на него означали бы, что фискальный документ и ЭСФ могут
  /// разойтись из-за одной настройки.
  Future<bool> _isOfd(List<PaymentEntry> payments, bool selectiveOfd) =>
      isOfdSale(
        db: _db,
        fiscal: GetIt.I.isRegistered<FiscalService>()
            ? GetIt.I<FiscalService>()
            : null,
        payments: payments,
        selectiveOfd: selectiveOfd,
      );

  /// Строка этого вида — обязательство, а не деньги.
  ///
  /// Спрашивается **справочник**, а не список системных ид: род расчёта
  /// настраивается, и пользовательская «рассрочка от банка», заведённая
  /// оператором со `settlement = deferred`, обязана вести себя как долг,
  /// а не как наличные. Вида, которого в справочнике нет, здесь не
  /// бывает: `PaymentEntry.kindId` обязателен, а пишет его касса.
  Future<bool> _isDeferredKind(int kindId) async {
    final row = await _db.paymentKindDao.rowById(kindId);
    if (row == null) return false;
    return PaymentSettlement.byIndex(row.settlement)?.isDeferredValue ?? false;
  }

  /// Строка этого вида — **зачёт внесённого раньше**, а не деньги.
  ///
  /// Спрашивается справочник по тому же доводу, что и у
  /// [_isDeferredKind]: род расчёта настраивается, и пользовательский
  /// «зачёт депозита», заведённый оператором со `settlement = offset`,
  /// обязан вести себя как аванс, а не как наличные.
  Future<bool> _isOffsetKind(int kindId) async {
    final row = await _db.paymentKindDao.rowById(kindId);
    if (row == null) return false;
    return PaymentSettlement.byIndex(row.settlement) ==
        PaymentSettlement.offset;
  }

  /// Сертификатный ли это вид оплаты — **по свойству вида, а не по числу**.
  ///
  /// Спрашивается род счёта-получателя, объявленный справочником, а не
  /// `kindId == SystemPaymentKindIds.certificate`. Довод тот же, что у
  /// фискальной трактовки: вид оплаты — настраиваемая сущность, оператор
  /// вправе завести **свой** вид сертификата (подарочные карты сети,
  /// сертификаты партнёра), и он обязан гаситься тем же кодом. Сравнение с
  /// системным числом объявило бы настраиваемость выдумкой.
  Future<bool> _isCertificateKind(int kindId) async {
    final row = await _db.paymentKindDao.rowById(kindId);
    return row?.payeeAccountType == AccountType.certificateLiability;
  }

  Future<void> _updateAgentBalance(int agentLocalId, Decimal amount) async {
    final agents = await (_db.select(
      _db.agents,
    )..where((a) => a.localId.equals(agentLocalId))).get();

    if (agents.isEmpty) return;
    final agent = agents.first;
    final mainAccountId = agent.mainAccountId;
    if (mainAccountId == null) return;

    final account = await _db.accountDao.findById(mainAccountId);
    if (account == null) return;

    final currentBalance = account.value ?? Decimal.zero;
    final newBalance = currentBalance + amount;

    await ((_db.update(_db.accounts))..where((a) => a.id.equals(mainAccountId)))
        .write(AccountsCompanion(value: Value(newBalance)));
  }
}
