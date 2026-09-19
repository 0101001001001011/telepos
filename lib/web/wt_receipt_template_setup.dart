import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Шаблон чека из браузера — решение заказчика 2026-09-18.
///
/// # Что здесь закрыто
///
/// Дословно: «это не граница, а пробел — в браузере должно работать то же,
/// что в приложении». Шапку, подвал и содержимое чека правили только на
/// кассе: оба экрана шаблона ходили в `AppDatabase` напрямую, а `lib/data/` в
/// браузерную сборку не собирается вовсе. Владелец, у которого вместо кассы
/// планшет, поправить текст чека не мог ничем.
///
/// Это **вторая реализация того же порта**
/// ([ReceiptTemplateSetupRepository]), а не второй путь к шаблону: пишет и
/// читает его по-прежнему единственная касса, терминал только приносит
/// заявку. Экран — тот же файл, что на кассе, и различить две сборки он не
/// может ничем, кроме того, какая реализация лежит в контейнере.
///
/// # Раскладки чека здесь нет ни строки — и это главное свойство
///
/// [preview] отдаёт то, что **сказала касса**, слово в слово. В этом файле
/// нет ни ширины ленты, ни выравнивания, ни кодовой страницы, ни `ESC`, ни
/// `GS` — ничего, из чего чек состоит. Текст чека на экране рождается ровно
/// в одном месте на всё дерево: `ReceiptPrintService.renderSalePreviewText`,
/// которая собирает настоящий поток ESC/POS тем же кодом, каким печатает, и
/// разбирает его обратно.
///
/// Разбор, почему выбрано именно так, а не «касса шлёт байты, вкладка
/// разбирает», — в докстринге `receipt_template_setup.dart`. Коротко: разбор
/// во вкладке был бы **вторым местом, где рождается текст чека на экране**,
/// ровно того рода, из-за которого две раскладки уже разошлись однажды
/// (докстринг `escpos_text_preview.dart`) и предпросмотр показывал не то,
/// что выходило из принтера.
///
/// Сторож — `test/backend/receipt_template_op_test.dart`: он поднимает обе
/// половины провода на настоящей базе и требует, чтобы строка, приехавшая
/// сюда, **совпала посимвольно** с тем, что `renderSalePreviewText` отдаёт
/// на кассе для того же черновика. Рядом продолжает работать
/// `test/unit/hardware/receipt_template_wire_test.dart`, сличающий тот же
/// вызов с бумагой настоящего эмулятора через настоящий сокет. Цепочка
/// сомкнута торцами: вкладка = касса = бумага.
///
/// # Арифметики и правил здесь нет ни строки
///
/// Тот же довод, что у `WtQrProviderSetup`: пустое имя, судьба признака
/// «встроенный», запрет на удаление встроенного шаблона, сброс кэша шаблона
/// в службе печати — всё это решает касса. Реши вкладка хоть что-нибудь
/// сама, у шаблона появился бы второй свод правил, живущий в браузере.
class WtReceiptTemplateSetup implements ReceiptTemplateSetupRepository {
  const WtReceiptTemplateSetup(this._wire);

  final WtDispatcher _wire;

  /// Отказ провода становится [WireRefusal] **с тем же кодом** — тем же
  /// приёмом, что у `WtQrProviderSetup` и `WtPrepaymentIntakeService`.
  ///
  /// Иначе экрану пришлось бы знать два типа исключения: кассовая
  /// реализация того же порта бросает `WireRefusal`, и договор обязан быть
  /// один на обе. Код при этом не теряется — фразу словарь находит по нему
  /// (`saleRefusalErrorKeyOf`).
  Future<T> _named<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }

  @override
  Future<ReceiptTemplateCatalog> read() =>
      _named(() => _wire.ask(TillOps.receiptTemplates, null));

  @override
  Future<void> save({
    int? id,
    required String name,
    required String optionsJson,
  }) => _named(
    () => _wire.ask(TillOps.receiptTemplateSave, (
      id: id,
      name: name,
      optionsJson: optionsJson,
    )),
  );

  @override
  Future<void> select(int id) =>
      _named(() => _wire.ask(TillOps.receiptTemplateSelect, id));

  @override
  Future<void> remove(int id) =>
      _named(() => _wire.ask(TillOps.receiptTemplateDelete, id));

  @override
  Future<String> preview(String optionsJson) =>
      _named(() => _wire.ask(TillOps.receiptTemplatePreview, optionsJson));

  @override
  Future<bool> testPrint() =>
      _named(() => _wire.ask(TillOps.receiptTemplateTestPrint, null));
}
