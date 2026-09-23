import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/certificate_slip_printer.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

/// Выпуск подарочного сертификата у прилавка — **дыра 1 ревизии
/// 2026-09-19**, закрытая экраном.
///
/// # Что было измерено до этого экрана
///
/// `grep ProductType lib/presentation/` — ноль совпадений; ключ
/// `pay.certificateIssue` не звал ни один файл презентационного слоя.
/// То есть выпуск работал **целиком**: своя операция провода, своя
/// проверка права, своя запись обязательства, своя печать слипа, две
/// дюжины проб — и ни одной двери, в которую мог бы войти кассир. Это не
/// «неудобно», а мёртвый код, выглядящий живым: у продукта возможности не
/// было вовсе.
///
/// # Почему отдельный экран, а не шаг оплаты и не карточка товара
///
/// Три места взвешены; разбор целиком — в докстринге
/// `AppRoutes.certificateIssue`. Коротко:
///
/// - **карточка товара с родом `giftCertificate`** — редактор каталога, а
///   не место у прилавка: выпуск оттуда завёл бы бумажке остаток до того,
///   как за неё заплатили;
/// - **шаг оплаты** — выпуск встал бы после взятых денег, внутри экрана,
///   уже показавшего успех, и отказ выпуска (занятый номер достижим
///   опечаткой) пришлось бы либо проглотить, либо откатить оплату с уже
///   выданным фискальным признаком. Провод этой ловушки избегает
///   намеренно: `pay.certificateIssue` — отдельная операция, а не поле
///   `pay.complete`;
/// - **свой маршрут** — повторяет ту же границу, что провод: деньги берёт
///   чек, бумажку заводит отдельное действие. Номер чека кассир называет
///   сам, тем же необязательным полем, каким его называет кадр.
///
/// # Экран не берёт денег и не знает о них ничего
///
/// Ни одной строки оплаты здесь не появляется, и это не упрощение, а
/// **смысл** разделения: продажа сертификата — обычный чек с обычной
/// строкой товара рода `giftCertificate`, пробитый до прихода сюда.
/// Единственное денежное число экрана — номинал, и оно едет `Decimal`.
///
/// # Право спрашивается перед вызовом, а не прячет кнопку
///
/// **Дверей три**, и ни одна не «видимость»:
///
/// 1. маршрут в карте `PermissionKeys.routeToPermissionKey` —
///    `op.issueCertificate`; `redirect` не пустит сюда без ключа, даже по
///    адресу, набранному руками;
/// 2. [_issue] спрашивает то же право **перед вызовом выпуска** и
///    отказывает словами, оставаясь на месте;
/// 3. сам выпуск (`CertificateIssuer.issue`) спрашивает его из
///    обязательного довода полномочий — ревизия второго фронта 2026-09-19.
///
/// Третья дверь — единственная, которую нельзя обойти, открыв этот экран
/// мимо `redirect` (диалогом, `MaterialPageRoute` из соседнего экрана) или
/// позвав `GetIt.I<CertificateIssuer>()` откуда-нибудь ещё. Прежняя
/// редакция этого докстринга называла её несделанной и оценивала в «15
/// файлов проб»; вышло 17 файлов и 98 мест вызова, и ни одного нового
/// решения — довод, ключ и код отказа уже были.
///
/// Вторая при этом не снята и снята не будет: она называет причину словами
/// словаря, не дожидаясь круга к базе, и пишет отказанную попытку в
/// журнал — ровно то, что владелец захочет увидеть.
///
/// Кнопка при этом на месте и нажимается: спрятанная кнопка правом не
/// является (I162), а исчезнувшая ещё и не объясняет кассиру, почему.
///
/// # Чего этот экран НЕ доказывает
///
/// - **Что отзыв бумажки закрыт правом.** `CertificateIssuer.cancel`
///   довода полномочий не принимает: его по-прежнему держат маршрут и
///   экран. Названо, а не сделано.
/// - **Что слип напечатался.** Печать отправляется и не ожидается
///   (правило дерева «деньги не ждут железа»): успех здесь значит «выпуск
///   состоялся», а бумажку ищет [_reprint] и очередь печати.
/// - **Что кассир не выпишет бумажку без чека.** Номер чека необязателен
///   намеренно — так же, как в кадре провода. Связь «выпуск ↔ оплата»
///   этим экраном не устанавливается вовсе и остаётся на кассире.
class CertificateIssueScreen extends ConsumerStatefulWidget {
  const CertificateIssueScreen({super.key, this.homeRoute});

  /// Куда уводит стрелка «назад», когда стека переходов нет вовсе.
  ///
  /// `null` — десктопная касса: экран живёт в оболочке, соседи по сетке
  /// «Дополнительно» ведут себя так же, и `AppBar` сам решает, показывать
  /// ли стрелку.
  ///
  /// Не `null` — браузерная вкладка: у неё оболочки нет, и вкладка,
  /// открытая прямо по адресу `#/certificate-issue`, осталась бы на экране
  /// навсегда. Дом называет **таблица маршрутов**, а не экран: у
  /// десктопной таблицы он другой, и `/terminal-home` в ней не объявлен
  /// вовсе. Тот же приём, что у `TerminalDiagnosticsScreen`.
  final String? homeRoute;

  @override
  ConsumerState<CertificateIssueScreen> createState() =>
      _CertificateIssueScreenState();
}

class _CertificateIssueScreenState
    extends ConsumerState<CertificateIssueScreen> {
  final _number = TextEditingController();
  final _nominal = TextEditingController();
  final _pin = TextEditingController();
  final _days = TextEditingController();
  final _receipt = TextEditingController();

  final _slipNumber = TextEditingController();
  final _slipPin = TextEditingController();

  bool _issuing = false;
  bool _printing = false;

  /// Готовая фраза словаря либо причина кассы, годная к показу как есть.
  String? _issueError;
  String? _issueDone;
  String? _slipError;
  String? _slipDone;

  CertificateIssuer get _certificates => GetIt.I<CertificateIssuer>();

  @override
  void dispose() {
    _number.dispose();
    _nominal.dispose();
    _pin.dispose();
    _days.dispose();
    _receipt.dispose();
    _slipNumber.dispose();
    _slipPin.dispose();
    super.dispose();
  }

  /// Деньги разбираются `Decimal`, и только им.
  ///
  /// Запятая приводится к точке до разбора: кассир набирает её на цифровой
  /// клавиатуре чаще точки, а `Decimal.tryParse('5000,00')` — это `null`,
  /// то есть «номинал не назван» вместо пяти тысяч.
  Decimal? _parseMoney(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return Decimal.tryParse(text);
  }

  Future<void> _issue() async {
    final l10n = AppLocalizations.of(context)!;

    // ── право: перед вызовом, а не вместо кнопки ────────────────────────
    //
    // Маршрут уже проверен `redirect`-ом, и эта проверка второй дверью
    // выглядит лишней ровно до того дня, когда экран откроют откуда-нибудь
    // ещё — диалогом, вкладкой, `MaterialPageRoute` из соседнего экрана.
    // Ровно так мимо проверки прошли `/telegram-setup` и восемь
    // `settings.*`-маршрутов (докстринг `_routePermissions`).
    if (!ref.read(hasPermissionProvider(PermissionKeys.opIssueCertificate))) {
      talker.warning(
        'Certificate: выпуск отказан по праву — у кассира нет '
        '${PermissionKeys.opIssueCertificate}',
      );
      setState(() {
        _issueDone = null;
        _issueError = l10n.certificateIssueNotPermitted;
      });
      return;
    }

    final number = _number.text.trim();
    if (number.isEmpty) {
      setState(() {
        _issueDone = null;
        _issueError = l10n.certificateIssueNumberRequired;
      });
      return;
    }

    final nominal = _parseMoney(_nominal.text);
    if (nominal == null || nominal <= Decimal.zero) {
      setState(() {
        _issueDone = null;
        _issueError = l10n.certificateIssueNominalInvalid;
      });
      return;
    }

    final pin = _pin.text.trim();
    final days = int.tryParse(_days.text.trim());
    final receiptNo = int.tryParse(_receipt.text.trim());

    setState(() {
      _issuing = true;
      _issueError = null;
      _issueDone = null;
    });

    try {
      final issued = await _certificates.issue(
        // Полномочия — **тем же провайдером**, каким их берёт экран продажи
        // (`saleAuthorityProvider`, `AppState` вошедшего). Вторая копия того
        // же выражения рядом разъехалась бы с первой при первой же правке
        // состава полномочий, и разъехалась бы молча — довод записан в самом
        // провайдере.
        //
        // Проверка права **выше** отсюда не уходит: она называет причину
        // словами словаря, не дожидаясь круга к базе, а эта — третья дверь
        // (маршрут → экран → операция) и единственная, которую нельзя
        // обойти, открыв экран мимо `redirect` (I162).
        by: ref.read(saleAuthorityProvider),
        number: number,
        nominal: nominal,
        pin: pin.isEmpty ? null : pin,
        // Срок набирается **днями**, а хранится мгновением. Календарь тут
        // был бы честнее на вид и хуже по делу: у прилавка срок называют
        // «полгода», «год», а не датой, и выбор даты — это ещё один
        // модальный слой между кассиром и очередью.
        expiresAt: days == null || days <= 0
            ? null
            : DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch ~/
                  1000,
        receiptNo: receiptNo,
        userId: ref.read(currentUserIdProvider),
      );

      if (!mounted) return;
      setState(() {
        _issuing = false;
        _issueDone = l10n.certificateIssueDone(
          issued.number,
          issued.nominal.toString(),
        );
        // Номер очищается, номинал — нет: тираж выписывают подряд и на одну
        // и ту же сумму, и заново набирать её значило бы платить за чужую
        // аккуратность. Номер же обязан быть новым — повтор откажет.
        _number.clear();
        _pin.clear();
        // Номер бумажки подставляется в повтор печати: чаще всего слип
        // перепечатывают ровно у той, что сейчас выпущена.
        _slipNumber.text = issued.number;
      });
    } on WireRefusal catch (refusal) {
      if (!mounted) return;
      talker.warning('Certificate: выпуск отказан — ${refusal.code}');
      setState(() {
        _issuing = false;
        // Причина кассы — по-русски и годна к показу: у выпуска нет пути
        // через провод к этому экрану, значит и кода, по которому словарь
        // нашёл бы фразу, тут не образуется. Фраза словаря стоит рядом и
        // называет **что** не вышло, причина — **почему**.
        _issueError = '${l10n.certificateIssueFailed}: ${refusal.message}';
      });
    } catch (e) {
      if (!mounted) return;
      talker.error('Certificate: выпуск не состоялся', e);
      setState(() {
        _issuing = false;
        _issueError = l10n.certificateIssueFailed;
      });
    }
  }

  /// Повтор печати слипа — вторая половина дыры 1.
  ///
  /// # Почему повтор вообще нужен
  ///
  /// Печать слипа отправляется и не ожидается, а её беда живёт в
  /// `CertificateSlipPrinter.takeTroubles()` — списке, который читается
  /// один раз и вытесняется. До этого экрана у кассира не было **ничего**:
  /// `find lib/presentation -iname "*certificat*"` не находил ни файла, и
  /// ненапечатанный слип был виден только в журнале. Покупатель при этом
  /// стоит у прилавка с оплаченным чеком и без бумажки.
  ///
  /// # Почему через `lookup`, а не по таблице
  ///
  /// [CertificateIssuer.lookup] — единственная дверь домена к бумажке, и
  /// она же спрашивает ПИН. Это не бюрократия: слип несёт номер и сумму, и
  /// печатать его тому, кто бумажки в руках не держит, значит выдать чужой
  /// сертификат по одному номеру. Отказ «погашен / отозван / просрочен»
  /// приходит оттуда же и называется словами — перепечатывать слип
  /// погашенной бумажки не для кого.
  ///
  /// # Почему связка съехала из экрана в порт — 2026-09-18
  ///
  /// До этого дня экран сам звал `lookup`, а потом
  /// `CertificateSlipPrinter.printIssued`. Пока экран был один, это было
  /// безобидно; с появлением планшета повторить связку во вкладке значило бы
  /// дать ей печатать обязательство магазина по **своим** полям. Теперь оба
  /// шага живут за [CertificateSlipReprinter], у которого две реализации —
  /// кассовая и провод, — а экран один на обе.
  Future<void> _reprint() async {
    final l10n = AppLocalizations.of(context)!;

    // Порт печати **необязателен**, и это законное состояние сборки, а не
    // ошибка: `LocalCertificateIssuer` принимает слип `null`-ом, а голый
    // процесс кассы очереди печати не поднимает вовсе. Молчание вместо слова
    // отправило бы кассира искать беду в принтере, которого никто не
    // спрашивал.
    if (!GetIt.I.isRegistered<CertificateSlipReprinter>()) {
      setState(() {
        _slipDone = null;
        _slipError = l10n.certificateSlipUnavailable;
      });
      return;
    }

    final number = _slipNumber.text.trim();
    if (number.isEmpty) {
      setState(() {
        _slipDone = null;
        _slipError = l10n.certificateIssueNumberRequired;
      });
      return;
    }

    setState(() {
      _printing = true;
      _slipError = null;
      _slipDone = null;
    });

    try {
      final pin = _slipPin.text.trim();
      final found = await GetIt.I<CertificateSlipReprinter>().reprint(
        number: number,
        pin: pin.isEmpty ? null : pin,
        // Кассир — довод порта, а не поле кадра: кассовая реализация берёт
        // его отсюда, проводная **выбрасывает** и подставляет сеанс
        // (докстринг `WtCertificateSlipReprinter`). Второго места, где имя
        // кассира можно назвать чужим, здесь не заводится.
        userId: ref.read(currentUserIdProvider),
      );
      if (!mounted) return;
      setState(() {
        _printing = false;
        _slipDone = l10n.certificateSlipDone(found.number);
      });
    } on WireRefusal catch (refusal) {
      if (!mounted) return;
      talker.warning('Certificate: слип не перепечатан — ${refusal.code}');
      setState(() {
        _printing = false;
        _slipError = '${l10n.certificateSlipFailed}: ${refusal.message}';
      });
    } catch (e) {
      if (!mounted) return;
      talker.error('Certificate: повтор печати слипа не состоялся', e);
      setState(() {
        _printing = false;
        _slipError = l10n.certificateSlipFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final home = widget.homeRoute;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.certificateIssueTitle),
        leading: home == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.globalBack,
                onPressed: () => context.go(home),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.certificateIssueHint,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('certificate_issue_number'),
              controller: _number,
              enabled: !_issuing,
              decoration: InputDecoration(
                labelText: l10n.certificateIssueNumber,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_issue_nominal'),
              controller: _nominal,
              enabled: !_issuing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.certificateIssueNominal,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_issue_pin'),
              controller: _pin,
              enabled: !_issuing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.certificateIssuePin,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_issue_days'),
              controller: _days,
              enabled: !_issuing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.certificateIssueExpiresDays,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_issue_receipt'),
              controller: _receipt,
              enabled: !_issuing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.certificateIssueReceipt,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_issueError != null) ...[
              const SizedBox(height: 12),
              Text(
                _issueError!,
                key: const Key('certificate_issue_error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (_issueDone != null) ...[
              const SizedBox(height: 12),
              Text(
                _issueDone!,
                key: const Key('certificate_issue_done'),
                style: TextStyle(color: scheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('certificate_issue_submit'),
              onPressed: _issuing ? null : _issue,
              child: Text(l10n.certificateIssueSubmit),
            ),
            const Divider(height: 40),
            Text(
              l10n.certificateSlipTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.certificateSlipHint,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_slip_number'),
              controller: _slipNumber,
              enabled: !_printing,
              decoration: InputDecoration(
                labelText: l10n.certificateSlipNumber,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('certificate_slip_pin'),
              controller: _slipPin,
              enabled: !_printing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.certificateSlipPin,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_slipError != null) ...[
              const SizedBox(height: 12),
              Text(
                _slipError!,
                key: const Key('certificate_slip_error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (_slipDone != null) ...[
              const SizedBox(height: 12),
              Text(
                _slipDone!,
                key: const Key('certificate_slip_done'),
                style: TextStyle(color: scheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('certificate_slip_submit'),
              onPressed: _printing ? null : _reprint,
              child: Text(l10n.certificateSlipSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
