import 'package:drift/drift.dart' show Value;

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/receipt/receipt_template_sample.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

/// Шаблон чека на самой кассе — та половина порта, у которой есть база и
/// принтер.
///
/// # Здесь нет ни одного нового правила, и это проверяемо
///
/// Каждый метод — ровно тот вызов, который до 2026-09-18 стоял в теле экрана
/// (`receipt_templates_screen.dart`, `receipt_template_editor_screen.dart`).
/// Работа этой правки — снять базу с экрана, а не переписать поведение:
/// экран, ставший другим при переносе, нечем было бы сличить с прежним.
///
/// Единственное, что здесь **добавлено** к прежнему коду экрана, —
/// [ReceiptPrintService.invalidateReceiptOptionsCache] после каждой записи.
/// Прежде его звали два экрана из трёх мест, и забыть его было можно: кэш
/// шаблона живёт в службе печати, и правка без сброса печаталась бы старым
/// текстом до перезапуска кассы. Теперь сброс стоит там же, где запись, и
/// пропустить его нельзя не проявив упорства.
///
/// # Образец чека собирается здесь, а не приходит с экрана
///
/// [preview] берёт реквизиты у `thisPosDao` сам. Разбор — в докстринге
/// [ReceiptTemplateSetupRepository]: собери образец вкладка, у чека появился
/// бы второй источник названия магазина и БИН.
///
/// # `sampleSaleReceiptData` переехал в домен
///
/// Он лежал в `lib/presentation/screens/settings/receipt/` — там, где его
/// собирал экран. Импортировать его отсюда значило бы завести
/// `lib/data/` → `lib/presentation/`, то есть слой наизнанку. Файл чистый
/// (ни виджета, ни контекста), и переезд в `lib/domain/receipt/` не стоил
/// ничего — разбор в его собственном докстринге.
class LocalReceiptTemplateSetup implements ReceiptTemplateSetupRepository {
  const LocalReceiptTemplateSetup({
    required AppDatabase db,
    required ReceiptPrintService printer,
  }) : _db = db,
       _printer = printer;

  final AppDatabase _db;
  final ReceiptPrintService _printer;

  @override
  Future<ReceiptTemplateCatalog> read() async {
    final dao = _db.receiptTemplateDao;
    await dao.seedDefaults();
    final rows = await dao.getAll();
    final width = await _printer.currentPaperWidth();
    return ReceiptTemplateCatalog(
      paperWidthMm: width.mm,
      templates: [
        for (final row in rows)
          ReceiptTemplateRow(
            id: row.id,
            name: row.name,
            builtIn: row.isDefault,
            selected: row.isSelected,
            optionsJson: row.optionsJson,
          ),
      ],
    );
  }

  @override
  Future<void> save({
    int? id,
    required String name,
    required String optionsJson,
  }) async {
    final dao = _db.receiptTemplateDao;
    if (id == null) {
      // Новый шаблон встроенным не бывает и выбранным сам не становится:
      // завести шаблон и начать им печатать — разные решения, и второе
      // делают радиокнопкой в списке. Иначе правка текста «на пробу»
      // молча сменила бы то, что выходит из принтера.
      await dao.insertTemplate(
        ReceiptTemplatesCompanion.insert(
          name: name,
          optionsJson: Value(optionsJson),
        ),
      );
    } else {
      // Ни `isDefault`, ни `isSelected` не пишутся: правка текста не имеет
      // права ни сделать шаблон встроенным, ни переключить печать на себя.
      await dao.updateTemplate(
        id,
        ReceiptTemplatesCompanion(
          name: Value(name),
          optionsJson: Value(optionsJson),
        ),
      );
    }
    _printer.invalidateReceiptOptionsCache();
  }

  @override
  Future<void> select(int id) async {
    await _db.receiptTemplateDao.selectTemplate(id);
    _printer.invalidateReceiptOptionsCache();
  }

  @override
  Future<void> remove(int id) async {
    // Запрет на удаление встроенного держит запрос DAO (`isDefault = false`
    // в `where`), а не проверка здесь: он обязан держаться и для кадра,
    // собранного мимо экрана.
    await _db.receiptTemplateDao.deleteTemplate(id);
    _printer.invalidateReceiptOptionsCache();
  }

  @override
  Future<String> preview(String optionsJson) async {
    return _printer.renderSalePreviewText(
      await _sample(),
      ReceiptOptions.decode(optionsJson),
      paperWidth: await _printer.currentPaperWidth(),
    );
  }

  @override
  Future<bool> testPrint() async {
    // `printSampleReceipt`, а не `printSaleReceipt`: у образца фиксированный
    // `receiptNo` (1024), и по идентификатору он столкнулся бы с настоящим
    // чеком того же номера той же смены — один из двух не напечатался бы.
    return !(await _printer.printSampleReceipt(await _sample())).isRejected;
  }

  /// Реквизиты образца — из `thisPos`, как их брал экран.
  ///
  /// Отказ чтения не отказ операции: без названия магазина образец соберётся
  /// на подставных реквизитах (`sampleSaleReceiptData` подставляет свои), и
  /// владелец увидит раскладку — ровно то, ради чего экран открывают. Пустой
  /// предпросмотр вместо чужого названия магазина был бы хуже.
  Future<SaleReceiptData> _sample() async {
    String store = '';
    String pos = 'POS';
    String? bin;
    try {
      final row = await _db.thisPosDao.get();
      store = row?.companyName ?? '';
      pos = row?.cashBoxName ?? 'POS';
      bin = row?.iinbin;
    } catch (_) {
      // Реквизиты не прочлись — образец соберётся на подставных.
    }
    return sampleSaleReceiptData(storeName: store, posName: pos, binIin: bin);
  }
}
