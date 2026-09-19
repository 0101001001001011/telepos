import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/http_qr_payment_provider.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/data/payment/qr_payment_coordinator.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Стойка QR на кассе — **единственное место, где настройка провайдера
/// становится разговором с провайдером**.
///
/// # Что было до неё
///
/// `QrPaymentCoordinator` и `HttpQrPaymentProvider` были написаны целиком
/// и не имели ни одного производителя: их не создавал ни `main.dart`, ни
/// DI, ни `lib/web/`. Провайдеру нужны адрес и ключ, а давать их было
/// некому — таблицы под них не существовало. Эта стойка — и тот, кто
/// даёт, и единственный, кто читает.
///
/// # Настройка читается на каждом обращении
///
/// Не при подъёме: оператор меняет адрес провайдера на живой кассе, и
/// касса, запомнившая старый до перезапуска, слала бы деньги покупателя
/// по адресу, которого больше нет. Провайдер пересобирается, только когда
/// настройка **изменилась** — HTTP-клиент дорогой, а чтение одной строки
/// базы нет.
///
/// # Ключ не покидает этот класс
///
/// Наружу стойка отдаёт координатор и терпение — и ни одного поля
/// настройки. Разбор, почему это граница, — в докстринге
/// `QrProviderSettings`.
/// Стойка QR — и единственный читатель настройки провайдера.
///
/// С 2026-09-15 она же — [QrProviderSetupRepository], порт экрана настройки
/// QR на кассе (пункт 8 C). Не второй класс рядом: сторож
/// `qr_secret_never_reaches_terminal_test.dart` требует, чтобы
/// `qrProviderConfigDao` читал ровно один файл, — второй читатель был бы
/// вторым путём для ключа.
class QrPaymentDesk implements QrProviderSetupRepository {
  QrPaymentDesk({
    required AppDatabase db,
    required Talker logger,
    http.Client Function()? httpClient,
    DateTime Function()? now,
    Duration pollEvery = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 10),
  }) : _db = db,
       _logger = logger,
       _httpClient = httpClient,
       _now = now ?? DateTime.now,
       _pollEvery = pollEvery,
       _timeout = timeout;

  final AppDatabase _db;
  final Talker _logger;
  final http.Client Function()? _httpClient;
  final DateTime Function() _now;
  final Duration _pollEvery;
  final Duration _timeout;

  QrProviderSettings? _settings;
  HttpQrPaymentProvider? _provider;
  QrPaymentCoordinator? _coordinator;

  DateTime now() => _now();

  // ── настройка с экрана кассы (пункт 8 C, 2026-09-15) ──────────────────

  @override
  Future<QrProviderView> read() async {
    final settings = await _db.qrProviderConfigDao.read();
    final kind = await PaymentKindCatalogImpl(
      _db,
    ).byId(SystemPaymentKindIds.qr);
    return QrProviderView(
      configured: settings != null && settings.isComplete,
      baseUrl: settings?.baseUrl ?? '',
      code: settings?.code ?? '',
      keySet: settings?.apiKey != null,
      patience: settings?.patience ?? QrProviderSettings.defaultPatience,
      kindActive: kind?.isActive ?? false,
    );
  }

  @override
  Future<void> save({
    required String baseUrl,
    required String code,
    required Duration patience,
    String? newApiKey,
    bool clearApiKey = false,
  }) async {
    final typed = newApiKey?.trim() ?? '';
    final previous = await _db.qrProviderConfigDao.read();
    final apiKey = clearApiKey
        ? null
        : (typed.isNotEmpty ? typed : previous?.apiKey);
    final settings = QrProviderSettings(
      baseUrl: baseUrl.trim(),
      code: code.trim(),
      apiKey: apiKey,
      patience: patience,
    );
    await _db.qrProviderConfigDao.save(settings, at: _now());
    // Разговор с прежним провайдером держать нельзя: следующий `open`
    // соберёт клиента заново по новой настройке.
    _drop();
    // `toString` настройки ключа не печатает.
    _logger.info('QR: provider settings saved from the till screen $settings');
  }

  @override
  Future<void> clear() async {
    await _db.qrProviderConfigDao.clear();
    _drop();
    _logger.info('QR: provider settings cleared from the till screen');
  }

  @override
  Future<void> setKindActive(bool active) async {
    // Правка **заведённой** строки, а не посев системного вида заново:
    // оператор мог переименовать вид или сменить счёт, и выключатель не
    // имеет права вернуть это к поставке.
    final kind =
        await PaymentKindCatalogImpl(_db).byId(SystemPaymentKindIds.qr) ??
        SystemPaymentKinds.byId(SystemPaymentKindIds.qr);
    await _db.paymentKindDao.put(kind.copyWith(isActive: active));
    _logger.info('QR: payment kind ${active ? 'enabled' : 'disabled'}');
  }

  /// Координатор под текущую настройку. `null` — провайдер не заведён.
  Future<QrDesk?> open() async {
    final settings = await _db.qrProviderConfigDao.read();
    if (settings == null || !settings.isComplete) {
      _drop();
      return null;
    }
    if (_coordinator == null || settings != _settings) {
      _drop();
      final provider = HttpQrPaymentProvider(
        baseUrl: settings.baseUrl,
        code: settings.code,
        apiKey: settings.apiKey,
        client: _httpClient?.call(),
        timeout: _timeout,
      );
      _provider = provider;
      _settings = settings;
      _coordinator = QrPaymentCoordinator(
        db: _db,
        provider: provider,
        patience: settings.patience,
        pollEvery: _pollEvery,
        now: _now,
      );
      // В журнал — `toString` настройки, который ключа не печатает.
      _logger.info('QR: provider ready $settings');
    }
    return (coordinator: _coordinator!, patience: settings.patience);
  }

  /// Вернуть [amount] по намерению [providerIntentId] — задача 26.
  ///
  /// Провайдер берётся под **текущую** настройку, как и у оплаты. Нет
  /// настройки — отказ значением [qrNotConfiguredCode], а не исключение:
  /// возврат обязан назвать кассиру, что вернуть нечем.
  Future<QrProviderReply<QrIntentState>> refund({
    required String providerIntentId,
    required Decimal amount,
    required String refundKey,
  }) async {
    final desk = await open();
    final provider = _provider;
    if (desk == null || provider == null) {
      return const QrProviderReply.refused(
        QrRefusal(qrNotConfiguredCode, 'провайдер QR на кассе не настроен'),
      );
    }
    return provider.reverse(providerIntentId, amount, refundKey: refundKey);
  }

  /// То же, что [open], но отсутствие настройки — **названный отказ**.
  Future<QrDesk> require() async {
    final desk = await open();
    if (desk == null) {
      throw const WireRefusal(
        qrNotConfiguredCode,
        'провайдер QR на кассе не настроен',
      );
    }
    return desk;
  }

  /// Сдаться по намерениям, которых **никто больше не спрашивает**.
  ///
  /// Вкладка, показавшая код, могла закрыться посреди ожидания — и тогда
  /// некому позвать круг, в котором касса сдалась бы по терпению. Код при
  /// этом жив у провайдера, и покупатель может заплатить по нему через
  /// полчаса за уже закрытый наличными чек. Поэтому перед каждым новым
  /// кодом и при подъёме касса сама отменяет всё, чьё терпение вышло.
  Future<void> sweepStale(QrDesk desk) async {
    final now = _now();
    for (final intent in await _db.paymentIntentDao.unresolved()) {
      if (intent.abandonedAt != null) continue;
      if (now.isBefore(intent.createdAt.add(desk.patience))) continue;
      _logger.info(
        'QR: intent ${intent.intentKey} outlived patience unattended — '
        'cancelling',
      );
      await desk.coordinator.abandon(intent.id, why: QrGiveUp.patience);
    }
  }

  /// Разбор при подъёме кассы — **то, ради чего координатор умеет
  /// `reconcile`**: подтверждение, пришедшее, пока касса была выключена,
  /// лежит у провайдера, и спросить про него надо до первого чека.
  ///
  /// Без настройки разбирать нечем; возвращаются деньги без чека из базы,
  /// чтобы вызывающий мог хотя бы назвать их число.
  Future<List<PaymentIntent>> reconcile() async {
    final desk = await open();
    if (desk == null) return _db.paymentIntentDao.orphanMoney();
    await sweepStale(desk);
    final orphans = await desk.coordinator.reconcile();
    if (orphans.isNotEmpty) {
      _logger.warning('QR: ${orphans.length} paid intent(s) without receipt');
    }
    return orphans;
  }

  void _drop() {
    _provider?.close();
    _provider = null;
    _coordinator = null;
    _settings = null;
  }
}

/// Координатор и терпение кассы — всё, что стойка отдаёт наружу.
typedef QrDesk = ({QrPaymentCoordinator coordinator, Duration patience});
