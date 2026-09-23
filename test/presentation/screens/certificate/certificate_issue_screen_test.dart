import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/data/payment/local_certificate_slip_reprinter.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/certificate/certificate_issue_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Экран выпуска сертификата — **дыра 1 ревизии 2026-09-19**.
///
/// # Что именно проверяется, и почему это не «экран рисуется»
///
/// Всё, что здесь утверждается, — утверждения о **вызове выпуска**, а не о
/// пикселях: состоялся ли он, с каким номиналом и каким типом, и —
/// главное — **не состоялся ли он там, где права нет**. Проба, которая
/// проверяла бы только наличие кнопки, была бы зелёной и на экране, не
/// связанном с выпуском ничем, — ровно тем дефектом, каким дыра и жила:
/// код был написан, право объявлено, пробы зелены, а двери не было.
///
/// # Чем каждая проба краснеет (диверсии проведены)
///
/// - «без права выпуск не зовётся» — снять проверку права в
///   `_issue()`: `issued` становится непустым, а отказа на экране нет.
/// - «номинал едет `Decimal`» — заменить `Decimal.parse` на разбор
///   `double` в экране: тип аргумента перестаёт быть `Decimal`.
/// - «отказ кассы показывается словами» — проглотить `WireRefusal`
///   молчанием: ключ `certificate_issue_error` не находится.
/// - «повтор печати зовёт печать той бумажки, что нашлась» — убрать
///   `printIssued`: список напечатанного пуст.
/// - «повтор печати без порта называет причину» — снять развилку
///   `isRegistered`: падает резолв `GetIt`, а не показывается фраза.
/// - «полномочия доезжают до выпуска» — подставить в вызове
///   `DiscountAuthority.none` вместо `saleAuthorityProvider`: набор прав в
///   доводе пуст, `userId` — `null`.
///
/// # Чего эти пробы НЕ доказывают
///
/// - **Что обязательство кассы выросло.** Здесь стоит поддельный выпуск;
///   счёт `certificateLiability` проверяет `certificate_ledger_test.dart`.
/// - **Что слип напечатался.** Печать отправляется и не ожидается; здесь
///   проверяется только то, что её попросили, и о той бумажке.
/// - **Что `LocalCertificateIssuer` откажет без права.** Здесь стоит
///   подделка, и она не читает ни прав, ни базы. С ревизии второго фронта
///   2026-09-19 настоящий выпуск право читает — доказано
///   `test/data/payment/certificate_issue_rights_test.dart` поверх
///   настоящей базы. Здесь доказано другое и тоже нужное: экран **довозит**
///   до выпуска действующие полномочия вошедшего, а не своё умолчание.
void main() {
  late _FakeIssuer issuer;
  late _FakeSlips slips;

  setUp(() {
    // Экран пишет отказ по праву в журнал: отказанная попытка выпуска —
    // ровно то, что владелец захочет увидеть, и молчать о ней нельзя.
    // Журнал в пробе настоящий, но никем не читается.
    installLogger(Talker());
    issuer = _FakeIssuer();
    slips = _FakeSlips();
    GetIt.I.registerSingleton<CertificateIssuer>(issuer);
    // Повтор печати идёт через **порт** (решение заказчика 2026-09-18), а не
    // двумя шагами из экрана: во вкладке второй такой связки быть не может.
    // Под портом здесь стоит настоящий `LocalCertificateSlipReprinter` над
    // подделками выпуска и печати — то есть проба по-прежнему мерит то же
    // самое: что нашлось, то и ушло в печать.
    GetIt.I.registerSingleton<CertificateSlipReprinter>(
      LocalCertificateSlipReprinter(certificates: issuer, slips: slips),
    );
  });

  tearDown(GetIt.I.reset);

  Future<void> pump(
    WidgetTester tester, {
    required Set<String> permissions,
  }) async {
    // Окно высокое намеренно: экран — один `ListView`, и поля повтора
    // печати на кассовом планшете лежат ниже сгиба. `ListView` не строит
    // того, чего не видно, и проба, не развернувшая окно, «не находила» бы
    // поля, которые на самом деле есть.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            () => MockAppStateNotifier(
              AppState(permissions: permissions, userId: 7),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ru')],
          locale: Locale('ru'),
          home: CertificateIssueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillIssue(
    WidgetTester tester, {
    String number = 'C-1',
    String nominal = '5000',
  }) async {
    await tester.enterText(
      find.byKey(const Key('certificate_issue_number')),
      number,
    );
    await tester.enterText(
      find.byKey(const Key('certificate_issue_nominal')),
      nominal,
    );
  }

  testWidgets(
    'без права op.issueCertificate кнопка на месте, но выпуск не зовётся '
    'вовсе и причина названа',
    (tester) async {
      await pump(tester, permissions: {PermissionKeys.navSale});
      await fillIssue(tester);

      await tester.tap(find.byKey(const Key('certificate_issue_submit')));
      await tester.pumpAndSettle();

      expect(
        issuer.issued,
        isEmpty,
        reason:
            'спрятанная кнопка правом не является, но и открытая не имеет '
            'права звать выпуск: обязательство берётся из ничего (I162)',
      );
      expect(
        find.byKey(const Key('certificate_issue_error')),
        findsOneWidget,
        reason: 'отказ показан на месте нажатия, а не молчанием',
      );
      expect(find.byKey(const Key('certificate_issue_done')), findsNothing);
    },
  );

  testWidgets('с правом выпуск зовётся, и номинал едет Decimal, а не double', (
    tester,
  ) async {
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );
    // Дробный номинал намеренно: `5000.005` в двойной точности не
    // представим точно, и подмена типа была бы видна третьим знаком.
    await fillIssue(tester, number: 'C-7', nominal: '5000.005');

    await tester.tap(find.byKey(const Key('certificate_issue_submit')));
    await tester.pumpAndSettle();

    expect(issuer.issued, hasLength(1));
    expect(issuer.issued.single.number, 'C-7');
    expect(
      issuer.issued.single.nominal,
      Decimal.parse('5000.005'),
      reason: 'деньги только Decimal — P18,S3, третий знак значащий (I159)',
    );
    expect(
      issuer.issued.single.userId,
      7,
      reason: 'кассир берётся из сеанса: слип подписан его именем',
    );
    expect(find.byKey(const Key('certificate_issue_done')), findsOneWidget);
  });

  testWidgets('полномочия доезжают до выпуска, а не остаются на экране', (
    tester,
  ) async {
    // Ревизия второго фронта 2026-09-19: право читает **сама операция**, и
    // экран обязан довезти до неё действующие полномочия вошедшего. Без
    // этой пробы экран, подставляющий `DiscountAuthority.none`, проходил бы
    // все прочие: подделка выпуска прав не читает, а настоящая касса
    // отказала бы такому вызову — то есть файл был бы зелен ровно на том
    // дереве, где кассир выпустить ничего не может.
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );
    await fillIssue(tester);

    await tester.tap(find.byKey(const Key('certificate_issue_submit')));
    await tester.pumpAndSettle();

    final by = issuer.issued.single.by;
    expect(
      by.permissions,
      contains(PermissionKeys.opIssueCertificate),
      reason: 'то самое право, которым касса и решает',
    );
    expect(
      by.userId,
      7,
      reason: 'аудит пишет вошедшего, а не того, кем себя назвал экран',
    );
  });

  testWidgets('запятая в номинале — те же деньги, а не «номинал не назван»', (
    tester,
  ) async {
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );
    await fillIssue(tester, nominal: '1200,50');

    await tester.tap(find.byKey(const Key('certificate_issue_submit')));
    await tester.pumpAndSettle();

    expect(issuer.issued.single.nominal, Decimal.parse('1200.50'));
  });

  testWidgets('нулевой номинал до кассы не доходит', (tester) async {
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );
    await fillIssue(tester, nominal: '0');

    await tester.tap(find.byKey(const Key('certificate_issue_submit')));
    await tester.pumpAndSettle();

    expect(issuer.issued, isEmpty);
    expect(find.byKey(const Key('certificate_issue_error')), findsOneWidget);
  });

  testWidgets('отказ кассы показывается словами, а не молчанием', (
    tester,
  ) async {
    issuer.refuseWith = const WireRefusal(
      certificateDuplicateNumberCode,
      'сертификат C-1 уже выпущен',
    );
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );
    await fillIssue(tester);

    await tester.tap(find.byKey(const Key('certificate_issue_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('certificate_issue_error')), findsOneWidget);
    expect(
      find.textContaining('уже выпущен'),
      findsOneWidget,
      reason:
          'занятый номер достижим опечаткой, и лечится он другим номером — '
          'кассир обязан прочесть, чем именно отказано',
    );
  });

  testWidgets(
    'повтор печати слипа: найденная бумажка уходит в печать той же, что '
    'нашлась',
    (tester) async {
      await pump(
        tester,
        permissions: {
          PermissionKeys.navSale,
          PermissionKeys.opIssueCertificate,
        },
      );

      await tester.enterText(
        find.byKey(const Key('certificate_slip_number')),
        'C-42',
      );
      await tester.tap(find.byKey(const Key('certificate_slip_submit')));
      await tester.pumpAndSettle();

      expect(issuer.lookedUp, ['C-42']);
      expect(slips.printed, ['C-42']);
      expect(find.byKey(const Key('certificate_slip_done')), findsOneWidget);
    },
  );

  testWidgets('повтор печати без порта печати называет причину, а не падает', (
    tester,
  ) async {
    GetIt.I.unregister<CertificateSlipReprinter>();
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );

    await tester.enterText(
      find.byKey(const Key('certificate_slip_number')),
      'C-42',
    );
    await tester.tap(find.byKey(const Key('certificate_slip_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('certificate_slip_error')), findsOneWidget);
    expect(
      issuer.lookedUp,
      isEmpty,
      reason: 'без печати искать бумажку незачем — и её ПИН спрашивать тоже',
    );
  });

  testWidgets('повтор печати отказ кассы («погашен») показывает словами', (
    tester,
  ) async {
    issuer.lookupRefusal = const WireRefusal(
      certificateExhaustedCode,
      'на сертификате C-9 ничего не осталось',
    );
    await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opIssueCertificate},
    );

    await tester.enterText(
      find.byKey(const Key('certificate_slip_number')),
      'C-9',
    );
    await tester.tap(find.byKey(const Key('certificate_slip_submit')));
    await tester.pumpAndSettle();

    expect(slips.printed, isEmpty);
    expect(find.textContaining('ничего не осталось'), findsOneWidget);
  });
}

/// Поддельный выпуск: помнит доводы вызова и умеет отказать.
///
/// Именно поддельный, а не настоящий с базой: проверяется **путь от кассира
/// до выпуска**, и настоящая запись обязательства здесь ничего не добавила
/// бы к утверждению, а отняла бы у него ясность — падение сошло бы за отказ
/// экрана.
class _FakeIssuer implements CertificateIssuer {
  /// [DiscountAuthority] помнится вместе с прочими доводами — ревизия
  /// второго фронта 2026-09-19. Без него проба «экран дошёл до выпуска»
  /// осталась бы верной и у экрана, отдающего `DiscountAuthority.none`:
  /// подделка прав не читает, а настоящая касса отказала бы такому вызову по
  /// праву — то есть файл был бы зелен ровно на том дереве, где кассир
  /// выпустить ничего не может.
  final List<
    ({String number, Decimal nominal, int? userId, DiscountAuthority by})
  >
  issued = [];
  final List<String> lookedUp = [];

  WireRefusal? refuseWith;
  WireRefusal? lookupRefusal;

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
    final refusal = refuseWith;
    if (refusal != null) throw refusal;
    issued.add((number: number, nominal: nominal, userId: userId, by: by));
    return _certificate(number, nominal);
  }

  @override
  Future<GiftCertificate> lookup({required String number, String? pin}) async {
    final refusal = lookupRefusal;
    if (refusal != null) throw refusal;
    lookedUp.add(number);
    return _certificate(number, Decimal.fromInt(5000));
  }

  @override
  Future<void> cancel(String number) async {}

  GiftCertificate _certificate(String number, Decimal nominal) =>
      GiftCertificate(
        id: 1,
        number: number,
        nominal: nominal,
        balance: nominal,
        status: CertificateStatus.active,
        issuedAt: 0,
      );
}

class _FakeSlips implements CertificateSlipPrinter {
  final List<String> printed = [];

  @override
  Future<void> printIssued({
    required GiftCertificate certificate,
    int? userId,
    int? refundLocalId,
    String? sourceNumber,
  }) async {
    printed.add(certificate.number);
  }

  @override
  List<CertificateSlipTrouble> takeTroubles() => const [];

  @override
  Future<void> get pending => Future<void>.value();
}
