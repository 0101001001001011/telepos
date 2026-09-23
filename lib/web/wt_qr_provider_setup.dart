import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Настройка оплаты по QR из браузера — решение заказчика 2026-09-18.
///
/// # Что здесь закрыто
///
/// Дословно: «это не граница, а пробел — в браузере должно работать то же,
/// что в приложении». Шаг 12 приёмки E0 записывал экран настройки QR как
/// достижимый только с кассы; владелец, у которого вместо кассы планшет,
/// включить оплату по QR не мог ничем — строку `qr_provider_configs` писала
/// либо десктопная сборка, либо дверь стенда.
///
/// Это **вторая реализация того же порта** ([QrProviderSetupRepository]), а
/// не второй путь к настройке: пишет и читает её по-прежнему единственная
/// стойка на кассе, терминал только приносит заявку. Экран и контроллер
/// настройки — те же самые файлы, что на кассе, и различить две сборки они не
/// могут ничем, кроме того, какая реализация лежит в контейнере.
///
/// # Ключ провайдера уезжает отсюда и не возвращается
///
/// [save] — единственный метод, который несёт секрет, и несёт он его **в одну
/// сторону**. Обратно ключ не приходит не потому, что здесь его выбрасывают,
/// а потому, что его нет в ответе: [QrProviderView] поля ключа не имеет
/// вовсе, и касса отвечает на `qr.providerSettings` формой, в которую ключ
/// положить некуда. Экран о ключе знает ровно одно — заведён он или нет
/// ([QrProviderView.keySet]).
///
/// Сторож — `test/backend/qr_setup_secret_test.dart`: он пишет ключ отсюда и
/// просматривает **каждый кадр, отправленный кассой терминалу**, одновременно
/// требуя, чтобы ключ в базе кассы оказался, — иначе поиск был бы зелен и у
/// кассы, которая ключа не сохранила вовсе.
///
/// # Арифметики и правил здесь нет ни строки
///
/// Тот же довод, что у `WtPaymentService`: границы терпения, судьба прежнего
/// ключа при пустом поле, состояние вида оплаты — всё это решает касса. Реши
/// вкладка хоть что-нибудь сама, у настройки появился бы второй свод правил,
/// живущий в браузере.
class WtQrProviderSetup implements QrProviderSetupRepository {
  const WtQrProviderSetup(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом, что у `WtPrepaymentIntakeService` и `WtRefundService._translate`.
  ///
  /// Иначе контроллеру пришлось бы знать два типа исключения: кассовая
  /// реализация того же порта (`QrPaymentDesk`) бросает `WireRefusal`, и
  /// договор обязан быть один на обе. Код при этом не теряется — фразу
  /// словарь находит по нему (`saleRefusalErrorKeyOf`).
  Future<T> _named<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  @override
  Future<QrProviderView> read() =>
      _named(() => _wire.ask(TillOps.qrProviderSettings, null));

  @override
  Future<void> save({
    required String baseUrl,
    required String code,
    required Duration patience,
    String? newApiKey,
    bool clearApiKey = false,
  }) => _named(
    () => _wire.ask(TillOps.qrProviderSave, (
      baseUrl: baseUrl,
      code: code,
      patience: patience,
      newApiKey: newApiKey,
      clearApiKey: clearApiKey,
    )),
  );

  @override
  Future<void> clear() =>
      _named(() => _wire.ask(TillOps.qrProviderClear, null));

  @override
  Future<void> setKindActive(bool active) =>
      _named(() => _wire.ask(TillOps.qrProviderKind, active));
}
