import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/core/net/loopback.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/hardware/kaspi_pos/payment_terminal_journal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/app/theme/app_typography.dart';

/// Что касса отправила за деньгами и что ей ответили: провайдер QR и терминал
/// оплаты на одной вкладке.
///
/// # Почему оба собеседника вместе, а не двумя вкладками
///
/// Вопрос у наладчика один: «берёт ли касса безналичные деньги». Какой именно
/// канал отвечает — код на телефоне или карта в терминале — он выясняет уже
/// по ответу, а не до вопроса. Две вкладки заставили бы гадать, в какую
/// смотреть, ровно в тот момент, когда у него очередь в зале.
///
/// # Данные берутся там, где они уже лежат
///
/// Половина QR — это **строки намерений** (`payment_intents`, схема v43). Они
/// заведены не ради экрана: намерение переживает перезагрузку, потому что
/// деньги покупателя её переживают. Экран ничего не заводит, он читает.
///
/// Половина терминала — журнал в памяти ([PaymentTerminalJournal]), и это
/// единственное, что пришлось завести: до него касса звала сокет и забывала,
/// и жалоба «карта не прошла» не имела ни одного следа.
///
/// # Граница знания кассы названа на самом экране
///
/// Под каждой половиной стоит строка о том, **чего касса не знает**: тел
/// запросов к провайдеру она не хранит, а обмены с терминалом теряет при
/// перезапуске и не видит операций, проведённых с самого терминала. Это не
/// оговорка для приличия: пустая половина без такой строки читается как «денег
/// не брали», что неправда.
///
/// # Пометка эмулятора — по адресу провайдера, а не по выключателю
///
/// Плашка зажигается, когда **адрес провайдера** смотрит на петлю. Не когда
/// включён встроенный эмулятор: касса, направленная на эмулятор, запущенный
/// руками из командной строки, ничем не отличается и обязана быть помечена так
/// же. Довод целиком — на [isLoopbackUrl].
///
/// # Чего эта вкладка НЕ доказывает
///
/// Что деньги списаны. Одобрение — это слово собеседника: провайдера или
/// терминала. Банк за ними стоит свой, и касса его не видит ни в каком режиме.
class PaymentDiagnosticsTab extends StatefulWidget {
  const PaymentDiagnosticsTab({super.key});

  @override
  State<PaymentDiagnosticsTab> createState() => _PaymentDiagnosticsTabState();
}

class _PaymentDiagnosticsTabState extends State<PaymentDiagnosticsTab> {
  late Future<_Snapshot> _snapshot = _read();

  Future<_Snapshot> _read() async {
    // База кассы. У браузерного терминала её нет, и это законное состояние:
    // намерения заводит касса. Пустой список вместо слов выглядел бы как
    // «касса не брала денег по коду» — та же ловушка, что на вкладке
    // фискального оператора.
    final db = GetIt.I.isRegistered<AppDatabase>()
        ? GetIt.I<AppDatabase>()
        : null;
    final setup = GetIt.I.isRegistered<QrProviderSetupRepository>()
        ? GetIt.I<QrProviderSetupRepository>()
        : null;
    final view = setup == null ? null : await setup.read();
    return _Snapshot(
      intents: db == null ? const [] : await db.paymentIntentDao.recent(),
      providerUrl: view?.baseUrl.trim(),
      qrConfigured: view?.configured ?? false,
      till: db != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final journal = PaymentTerminalJournal.shared;

    return FutureBuilder<_Snapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!data.till) {
          return Center(
            key: const ValueKey('payment-diagnostics-unavailable'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.paymentDiagnosticsUnavailable,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final onEmulator =
            data.providerUrl != null && isLoopbackUrl(data.providerUrl!);

        return RefreshIndicator(
          onRefresh: () async => setState(() => _snapshot = _read()),
          child: StreamBuilder<List<PaymentTerminalExchange>>(
            stream: journal.watch(),
            initialData: journal.recent(),
            builder: (context, terminal) {
              final exchanges =
                  terminal.data ?? const <PaymentTerminalExchange>[];
              return ListView(
                key: const ValueKey('payment-diagnostics-list'),
                padding: const EdgeInsets.all(12),
                children: [
                  if (onEmulator)
                    _EmulatorBanner(
                      text: l10n.diagnosticsPaymentEmulatorBanner,
                    ),
                  _Section(
                    title: l10n.paymentDiagnosticsQrSection,
                    note: data.providerUrl == null || data.providerUrl!.isEmpty
                        ? null
                        : l10n.paymentDiagnosticsQrAddress(data.providerUrl!),
                    empty: data.qrConfigured
                        ? l10n.paymentDiagnosticsQrEmpty
                        : l10n.paymentDiagnosticsQrNotConfigured,
                    caveat: l10n.paymentDiagnosticsQrUnknown,
                    children: [
                      for (final intent in data.intents)
                        _IntentCard(intent: intent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: l10n.paymentDiagnosticsTerminalSection,
                    empty: l10n.paymentDiagnosticsTerminalEmpty,
                    caveat: l10n.paymentDiagnosticsTerminalUnknown,
                    children: [
                      for (final exchange in exchanges)
                        _ExchangeCard(exchange: exchange),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Snapshot {
  const _Snapshot({
    required this.intents,
    required this.providerUrl,
    required this.qrConfigured,
    required this.till,
  });

  final List<PaymentIntent> intents;

  /// Адрес провайдера — он же признак эмулятора.
  final String? providerUrl;

  final bool qrConfigured;

  /// Есть ли у этого рабочего места база кассы вообще.
  final bool till;
}

class _EmulatorBanner extends StatelessWidget {
  const _EmulatorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('payment-diagnostics-emulator-banner'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.developer_board, color: AppColors.warning, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.caveat,
    required this.children,
    this.note,
  });

  final String title;
  final String empty;

  /// Чего касса не знает. Стоит всегда, а не только при пустом списке:
  /// граница знания не появляется и не исчезает от числа строк.
  final String caveat;

  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(note!, style: theme.textTheme.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            caveat,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (children.isEmpty)
          Padding(padding: const EdgeInsets.all(8), child: Text(empty))
        else
          ...children,
      ],
    );
  }
}

/// Намерение оплаты по коду: что просили, что ответил провайдер, чем кончилось.
class _IntentCard extends StatelessWidget {
  const _IntentCard({required this.intent});

  final PaymentIntent intent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bad = intent.refusalCode != null || intent.isOrphanMoney;

    final marks = <String>[
      _time(intent.createdAt),
      intent.providerCode,
      intent.status.code,
      if (intent.confirmations > 1)
        l10n.paymentDiagnosticsConfirmations(intent.confirmations),
      if (intent.isPartial)
        l10n.qrPaidPartial(
          intent.paidAmount.toString(),
          intent.amount.toString(),
        ),
      if (intent.isOrphanMoney) l10n.paymentDiagnosticsOrphanMoney,
      if (intent.isPaidAfterGiveUp) l10n.paymentDiagnosticsAfterGiveUp,
    ];

    return Card(
      key: ValueKey('payment-intent-${intent.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('${intent.amount} · ${intent.intentKey}'),
        subtitle: Text(
          marks.join(' · '),
          style: TextStyle(color: bad ? scheme.error : null),
        ),
        children: [
          _Detail(
            label: l10n.paymentDiagnosticsRequest,
            // Запрос показывается тем, что от него осталось в намерении:
            // сумма и ключ идемпотентности. Тела запроса касса не хранит, и
            // это сказано строкой над списком.
            value: '${intent.amount} · ${intent.intentKey}',
          ),
          _Detail(
            label: l10n.paymentDiagnosticsReply,
            value: intent.providerIntentId == null
                ? l10n.paymentDiagnosticsNoReply
                : l10n.paymentDiagnosticsApproval(intent.providerIntentId!),
          ),
          if (intent.qrPayload != null)
            _Detail(label: 'QR', value: intent.qrPayload!),
          if (intent.refusalCode != null)
            _Detail(
              label: l10n.paymentDiagnosticsRefusal(intent.refusalCode!),
              value: intent.refusalMessage ?? '',
              bad: true,
            ),
        ],
      ),
    );
  }
}

/// Обмен с терминалом оплаты: кадр туда, кадр обратно, разбор продукта.
class _ExchangeCard extends StatelessWidget {
  const _ExchangeCard({required this.exchange});

  final PaymentTerminalExchange exchange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: ValueKey('payment-exchange-${exchange.at.microsecondsSinceEpoch}'),
        leading: Icon(
          exchange.approved ? Icons.check_circle_outline : Icons.block,
          color: exchange.approved ? scheme.primary : scheme.error,
        ),
        title: Text(
          '${_operation(l10n, exchange.operation)} · '
          '${exchange.approved ? l10n.paymentDiagnosticsApproved : l10n.paymentDiagnosticsDeclined}',
          style: TextStyle(color: exchange.approved ? null : scheme.error),
        ),
        subtitle: Text('${_time(exchange.at)} · ${exchange.address}'),
        children: [
          _Detail(
            label: l10n.paymentDiagnosticsRequest,
            value: exchange.request,
          ),
          _Detail(
            label: l10n.paymentDiagnosticsReply,
            value: exchange.response ?? l10n.paymentDiagnosticsNoReply,
          ),
          if (exchange.approvalCode != null)
            _Detail(
              label: l10n.paymentDiagnosticsApproval(exchange.approvalCode!),
              value: exchange.transactionId == null
                  ? ''
                  : l10n.paymentDiagnosticsTransaction(exchange.transactionId!),
            ),
          if (exchange.refusal != null)
            _Detail(
              label: l10n.paymentDiagnosticsRefusal(exchange.refusal!),
              value: '',
              bad: true,
            ),
        ],
      ),
    );
  }

  static String _operation(
    AppLocalizations l10n,
    PaymentTerminalOperation operation,
  ) => switch (operation) {
    PaymentTerminalOperation.purchase => l10n.paymentDiagnosticsOpPurchase,
    PaymentTerminalOperation.reversal => l10n.paymentDiagnosticsOpReversal,
    PaymentTerminalOperation.refund => l10n.paymentDiagnosticsOpRefund,
    PaymentTerminalOperation.unknown => l10n.paymentDiagnosticsOpUnknown,
  };
}

/// Строка разбора: подпись и значение **как есть**.
///
/// Кадр и ответ не приглаживаются — тот же довод, что у тела запроса к
/// фискальному оператору: это сверяют с тем, что ждёт прибор.
class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.bad = false});

  final String label;
  final String value;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: bad ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          if (value.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTypography.familyMono,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}:'
    '${at.second.toString().padLeft(2, '0')}';
