/// Замок перебора сертификатов на кассе **мимо провода** — пункт 5 A7
/// (2026-09-15).
///
/// # Дыра
///
/// `CertificateThrottle` стоял только в обработчиках `pay.certificate` и
/// `pay.complete` (`TillOperations`). Экран оплаты самой кассы зовёт
/// `PaymentService.findCertificate`/`complete` напрямую — `LocalPaymentService`
/// из контейнера (`service_locator.dart`), — и там перебор номеров и ПИНов не
/// ограничивал никто. Хуже: счёт номера у провода и у кассы был бы разным, и
/// пять неудач с планшета не запирали бы номер для кассы.
///
/// # Решение — обёртка контракта, а не вторая реализация замка
///
/// Этот класс — `PaymentService`, который делегирует всё и пропускает две
/// проверки сертификата через **тот же** `CertificateThrottle`, что отдан
/// `TillOperations` (`main.dart` → `ApiServer.certificateThrottle`). Ключ
/// номера у кассы и у провода один.
///
/// Двойного счёта нет: `TillOperations` зовёт эту же обёртку изнутри своего
/// `guard`, а `guard` внутри допущенной попытки не допускает её второй раз
/// (докстринг `CertificateThrottle.guard`, «вложенный вызов»).
///
/// # Кто стучится
///
/// На кассе нет сеанса провода: кассир — тот, кто вошёл на самой кассе
/// ([CashierOnDuty], пишет экран входа). Счёт — по нему, терминала самой
/// кассы в ключах нет; разбор — у класса, «Счёт по кассиру».
library;

import 'package:decimal/decimal.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/domain/auth/cashier_on_duty.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// # Счёт по кассиру (решение заказчика 2026-09-15)
///
/// «Кассы — это разные кассиры, и каждый всегда работает в своей смене, а не
/// в общей». Прежде ключом кассира здесь был общий на всех «место за
/// кассой» (`desktopSeatKey`), а ключом места — терминал самой кассы, тоже
/// общий: кассир A, упёршийся в предел, запирал кассира B в его собственной
/// смене. Теперь:
///
/// - кассир — `u:<userId>` вошедшего на кассе ([CashierOnDuty]), **тот же
///   ключ, что у провода**: один человек с планшета и с кассы упирается в
///   один счёт; повторный вход окна не обнуляет;
/// - терминала самой кассы в ключах нет: за кассой сидят разные кассиры по
///   очереди, и счёт места был бы тем самым общим счётом, от которого
///   отказался заказчик;
/// - номер сертификата — общий для всех кассиров и провода, как и был.
///
/// Никто не вошёл — названный отказ `unauthorized`, а не общий счёт
/// запасным выходом: проверка сертификата без кассира на кассе недостижима
/// штатно, и если она случилась, считать её некому.

class ThrottledPaymentService
    implements PaymentService, QrProviderSetupHost, ReceiptTemplateSetupHost {
  ThrottledPaymentService(
    this._inner, {
    required CertificateThrottle throttle,
    required CashierOnDuty cashier,
  }) : _throttle = throttle,
       _cashier = cashier;

  final PaymentService _inner;
  final CertificateThrottle _throttle;
  final CashierOnDuty _cashier;

  /// Вошедший кассир — или названный отказ (докстринг класса).
  int _requireCashier() {
    final userId = _cashier.userId;
    if (userId == null) {
      throw const WireRefusal(
        'unauthorized',
        'на кассе никто не вошёл — сертификат проверять не от чьего имени',
      );
    }
    return userId;
  }

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) async {
    final userId = _requireCashier();
    return _throttle.guard(
      userId: userId,
      sessionKey: null,
      // Терминала самой кассы в ключах нет — докстринг класса.
      terminalId: null,
      numbers: [number],
      check: () => _inner.findCertificate(number, pin: pin),
    );
  }

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    final numbers = [for (final c in request.certificates) c.number];
    if (numbers.every((n) => n.trim().isEmpty)) {
      return _inner.complete(terminalId, request, meta);
    }
    final userId = _requireCashier();
    return _throttle.guard(
      userId: userId,
      sessionKey: null,
      terminalId: null,
      numbers: numbers,
      check: () => _inner.complete(terminalId, request, meta),
    );
  }

  // ── всё прочее — без замка ────────────────────────────────────────────

  @override
  Future<List<PaymentAccount>> accounts() => _inner.accounts();

  @override
  Future<bool> sellsInDebt() => _inner.sellsInDebt();

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) =>
      _inner.findLoyalty(phone);

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) =>
      _inner.reserveBonus(customerId, amount);

  @override
  Future<Decimal> prepaymentBalance(int customerId) =>
      _inner.prepaymentBalance(customerId);

  @override
  Future<String?> qrUnavailableReason() => _inner.qrUnavailableReason();

  /// Настройка провайдера QR — насквозь, как и всё, что не сертификат.
  ///
  /// Обёртка обязана пробрасывать порт, а не отвечать `null`: под контрактом
  /// `PaymentService` в контейнере стоит **она**, и молчаливый `null` здесь
  /// означал бы кассу, у которой настройка QR по проводу «не поддерживается»
  /// ровно потому, что рядом включили замок перебора сертификатов. Замок и
  /// настройка провайдера не имеют друг к другу отношения.
  ///
  /// Обёрнутая реализация может не быть [QrProviderSetupHost] (браузерная
  /// половина, подделка в пробе) — тогда `null` честен: стойки нет, и
  /// операция откажет названной причиной.
  @override
  QrProviderSetupRepository? get qrProviderSetup => switch (_inner) {
    final QrProviderSetupHost host => host.qrProviderSetup,
    // Образцом, а не `is` с продвижением: [QrProviderSetupHost] не
    // наследник `PaymentService`, и продвижения по такой проверке в Dart
    // нет вовсе — `inner.qrProviderSetup` не собралось бы.
    _ => null,
  };

  /// Шаблон чека — насквозь, тем же приёмом и по тому же доводу, что
  /// настройка QR выше: замок перебора сертификатов не имеет отношения к
  /// тексту чека, и молчаливый `null` здесь означал бы кассу, у которой
  /// шаблон по проводу «не поддерживается» ровно потому, что рядом включили
  /// замок.
  @override
  ReceiptTemplateSetupRepository? get receiptTemplates => switch (_inner) {
    final ReceiptTemplateSetupHost host => host.receiptTemplates,
    _ => null,
  };

  @override
  Future<QrTender> startQr(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) => _inner.startQr(terminalId, amount, meta);

  @override
  Future<QrTender> pollQr(int terminalId, String intentKey) =>
      _inner.pollQr(terminalId, intentKey);

  @override
  Future<QrTender> cancelQr(int terminalId, String intentKey) =>
      _inner.cancelQr(terminalId, intentKey);

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) => _inner.chargeCard(terminalId, amount, meta);

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) => _inner.hardwareTroubles(terminalId, receiptNo);
}
