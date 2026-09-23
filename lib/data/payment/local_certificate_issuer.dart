import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:telepos/core/locale/till_language.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Выпуск и предъявление сертификата на кассе.
///
/// Что здесь делается и чего здесь намеренно нет — в докстринге
/// [CertificateIssuer]. Решение «остаток остаётся на сертификате, сдачи
/// наличными нет» разобрано в [CertificateApplication].
@LazySingleton(as: CertificateIssuer)
class LocalCertificateIssuer implements CertificateIssuer {
  LocalCertificateIssuer({
    required AppDatabase db,
    required Talker logger,
    CertificateSlipPrinter? slips,
  }) : _db = db,
       _logger = logger,
       _slips = slips;

  final AppDatabase _db;
  final Talker _logger;

  /// Печать слипа выпущенной бумажки — решение заказчика 2026-09-16.
  ///
  /// `null` — печати нет, и это **не ошибка**: касса без принтера обязана
  /// выпускать сертификаты так же, а пробы обязательства
  /// (`certificate_ledger_test.dart`) не должны поднимать очередь печати ради
  /// проверки счёта. Разбор — в докстринге [CertificateSlipPrinter].
  final CertificateSlipPrinter? _slips;

  @override
  Future<GiftCertificate> issue({
    required DiscountAuthority by,
    required String number,
    required Decimal nominal,
    String? pin,
    int? expiresAt,
    int? receiptNo,
    int? posId,
    int? userId,
  }) async {
    // Право — **первым**, раньше номера и номинала: разбор порядка и самой
    // дыры в докстринге [CertificateIssuer.issue]. Отказ словом сторожа
    // провода (`WireDenied.forbidden`), а не своим: кассир у прилавка и
    // кассир за планшетом обязаны получить одну причину одним кодом —
    // `saleRefusalKeys` переводит её в «Не разрешено».
    if (!by.permissions.contains(PermissionKeys.opIssueCertificate)) {
      _logger.warning(
        'Certificate: выпуск отказан по праву user=${by.userId} '
        '(${PermissionKeys.opIssueCertificate})',
      );
      throw const WireRefusal(
        WireDenied.forbidden,
        'нет права выпускать сертификаты '
        '(${PermissionKeys.opIssueCertificate})',
      );
    }

    final trimmed = number.trim();
    if (trimmed.isEmpty) {
      throw const WireRefusal(
        certificateUnknownCode,
        'у сертификата нет номера',
      );
    }
    if (nominal <= Decimal.zero) {
      throw WireRefusal(
        certificateNominalInvalidCode,
        'номинал сертификата ($nominal) должен быть больше нуля',
      );
    }

    // Счёт обязательства — **до** вставки: сертификат без счёта завёлся
    // бы, а обязательство кассы не выросло бы ни на тенге, и недостача
    // всплыла бы только при гашении, у другого кассира, в другую смену.
    final liabilityAccountId = await _liabilityAccountId();

    // Проверка на занятый номер здесь — ради **слова**, а не ради
    // защиты: между ней и вставкой есть окно, и закрывает его
    // уникальный ключ таблицы (`catch` ниже). Двухслойность намеренная:
    // первый слой объясняет кассиру, второй не даёт беде случиться.
    if (await _db.certificateDao.byNumber(trimmed) != null) {
      throw WireRefusal(
        certificateDuplicateNumberCode,
        'сертификат $trimmed уже выпущен',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pinHash = (pin == null || pin.isEmpty)
        ? null
        : PinCredential.create(pin);

    late final int id;
    try {
      id = await _db.transaction(() async {
        final inserted = await _db.certificateDao.insertCertificate(
          number: trimmed,
          nominal: nominal,
          issuedAt: now,
          status: CertificateStatus.active,
          pinHash: pinHash,
          expiresAt: expiresAt,
          issuedReceiptNo: receiptNo,
          issuedPosId: posId,
          issuedByUserId: userId,
          liabilityAccountId: liabilityAccountId,
        );

        // **Обязательство берётся в той же транзакции, что и бумажка.**
        // Тот же довод, что у гашения: касса, записавшая сертификат и не
        // записавшая обязательство, отдаст товар за деньги, которых у неё
        // по книгам не было.
        //
        // Движение, а не остаток: знак выбирает `AccountPosting` по роду
        // счёта. У рода `certificateLiability` платёж **уменьшает**
        // остаток (гашение закрывает долг), поэтому выпуск — это движение
        // со знаком минус, и число получается верным: обязательство
        // растёт на номинал.
        await _db.accountDao.post(liabilityAccountId, -nominal);
        return inserted;
      });
    } on SqliteException catch (e) {
      // Уникальный ключ по номеру: вставка пришла второй. Наружу это
      // обязано выйти названным отказом, а не нутром sqlite (I144).
      if (e.extendedResultCode == 2067 || e.resultCode == 19) {
        _logger.warning('Certificate: duplicate number $trimmed');
        throw WireRefusal(
          certificateDuplicateNumberCode,
          'сертификат $trimmed уже выпущен',
        );
      }
      rethrow;
    }

    _logger.info(
      'Certificate: issued $trimmed nominal=$nominal '
      'receipt=$receiptNo expires=$expiresAt',
    );
    final issued = (await _db.certificateDao.byId(id))!;

    // ── слип: отправляется, не ожидается ──────────────────────────────
    //
    // Решение заказчика 2026-09-16: «без печати схема у прилавка не
    // работает, покупатель уходит с пустыми руками». До этой правки выпуск
    // заводил строку и обязательство, а на руки не давал ничего — номер
    // кассир переписывал от руки.
    //
    // `unawaited` здесь и есть правило «оплата не ждёт железа»: деньги за
    // бумажку уже приняты чеком, обязательство уже на счёте, и отказ
    // принтера не имеет права отменить выпуск. Беда печати называется в
    // журнале и ждёт читателя в `CertificateSlipPrinter.takeTroubles`.
    final slips = _slips;
    if (slips != null) {
      unawaited(slips.printIssued(certificate: issued, userId: userId));
    }
    return issued;
  }

  @override
  Future<GiftCertificate> lookup({required String number, String? pin}) async {
    final trimmed = number.trim();
    final found = await _db.certificateDao.byNumber(trimmed);
    // `subject` у трёх исходов подбора — номер бумажки: `pay.complete`
    // несёт их несколько, и замок перебора засчитывает неудачу только тому
    // номеру, что не подошёл (`CertificateThrottle.guard`, пункт 6 A7).
    if (found == null) {
      throw WireRefusal(
        certificateUnknownCode,
        'сертификата $trimmed на этой кассе нет',
        subject: trimmed,
      );
    }

    // ПИН — **до** разговора о сроке и остатке: тот, кто бумажки в руках
    // не держит, не обязан узнать от кассы ни сколько на ней осталось,
    // ни когда она истекает.
    final hash = found.pinHash;
    if (hash != null) {
      // Пусто — «нужен ПИН», а не «не подошёл»: лечится вводом, а не
      // перенабором (докстринг `certificatePinRequiredCode`).
      if (pin == null || pin.trim().isEmpty) {
        throw WireRefusal(
          certificatePinRequiredCode,
          'у сертификата есть ПИН — наберите его',
          subject: trimmed,
        );
      }
      final result = PinCredential.check(pin: pin, stored: hash);
      if (!result.isOk) {
        _logger.warning('Certificate: wrong PIN for $trimmed');
        throw WireRefusal(
          certificatePinWrongCode,
          'ПИН сертификата не подошёл',
          subject: trimmed,
        );
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = found.expiresAt;
    if (found.isLive && expiresAt != null && expiresAt <= now) {
      // **Отметка пишется, а не вычисляется** — разбор в докстринге
      // `CertificateStatus.expired`. Пишется здесь и сейчас, вне всякой
      // транзакции продажи: отказ, брошенный ниже, откатил бы её вместе
      // с транзакцией, и сертификат приходил бы активным на каждой
      // следующей попытке — то есть отметка не значила бы ничего.
      await _db.certificateDao.markExpired(trimmed);
      _logger.info('Certificate: $trimmed expired at $expiresAt');
      throw WireRefusal(
        certificateExpiredCode,
        'срок сертификата $trimmed вышел',
      );
    }

    if (!found.isLive) {
      throw WireRefusal(
        found.status == CertificateStatus.expired
            ? certificateExpiredCode
            : certificateExhaustedCode,
        _explain(found),
      );
    }

    if (found.balance <= Decimal.zero) {
      // Достижимо не только гашением: остаток мог быть обнулён и без
      // перевода состояния, если бы условная запись когда-нибудь
      // разошлась со своим `CASE`. Утверждение об остатке стоит рядом с
      // утверждением о состоянии именно поэтому — они проверяют друг
      // друга.
      throw WireRefusal(
        certificateExhaustedCode,
        'на сертификате $trimmed ничего не осталось',
      );
    }

    return found;
  }

  @override
  Future<void> cancel(String number) async {
    final touched = await _db.certificateDao.cancel(number.trim());
    if (touched == 0) {
      throw WireRefusal(
        certificateUnknownCode,
        'отзывать нечего: сертификата ${number.trim()} нет либо он уже '
        'погашен',
      );
    }
    _logger.info('Certificate: cancelled ${number.trim()}');
  }

  String _explain(GiftCertificate c) => switch (c.status) {
    CertificateStatus.redeemed =>
      'сертификат ${c.number} уже погашен полностью',
    CertificateStatus.expired => 'срок сертификата ${c.number} вышел',
    CertificateStatus.cancelled => 'сертификат ${c.number} отозван',
    CertificateStatus.active => 'сертификат ${c.number} годен',
  };

  /// Счёт обязательства по сертификатам — найти, а при отсутствии завести.
  ///
  /// Заводится **лениво, первым выпуском**, а не миграцией. Довод тот же,
  /// по которому справочник видов хранит род счёта, а не его номер: счёт
  /// принадлежит кассе, а не сети, и заводить его на каждой кассе, где
  /// сертификатов не будет никогда, — значит засорять список счетов
  /// владельца строкой, которой он не просил.
  Future<int> _liabilityAccountId() async {
    final existing = await _db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    if (existing.isNotEmpty) return existing.first.id;

    final id = await _db.accountDao.getNextId();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.accountDao.insertAccount(
      AccountsCompanion(
        id: Value(id),
        type: const Value(AccountType.certificateLiability),
        // Имя — на языке кассы. `TillLanguage` держит именно его:
        // `locale_provider` присваивает сюда язык интерфейса при
        // сборке и при каждой смене. Имя у держателя историческое —
        // он завёлся ради бумаги, — но выбор в нём один на кассу.
        //
        // Здесь стояло зашитое русское имя, и на американской кассе
        // счёт с ним показывался в отчётах. Имя счёта — ДАННЫЕ:
        // человек правит его на экране счетов, поэтому слово
        // выбирается один раз, при заведении, а не при показе.
        name: Value(
          lookupAppLocalizations(
            Locale(TillLanguage.current.languageCode),
          ).accountCertificateLiability,
        ),
        value: Value(Decimal.zero),
        // **Не виден кассе как счёт оплаты**: `PaymentService.accounts`
        // отдаёт видимые счета терминалу, и кассир мог бы выбрать
        // обязательство счётом для безналичной части. Выручка уехала бы
        // в обязательство, а обязательство — в минус.
        visibleToPos: const Value(false),
        updateTime: Value(now),
      ),
    );
    _logger.info('Certificate: liability account $id created');
    return id;
  }
}
