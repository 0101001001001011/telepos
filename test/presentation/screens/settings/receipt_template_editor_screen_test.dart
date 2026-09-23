import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/receipt/local_receipt_template_setup.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/receipt_paper_width_source.dart';
import 'package:telepos/domain/receipt/receipt_template_setup.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/receipt/receipt_template_editor_screen.dart';

/// Экран шаблона чека: многострочные шапка и подвал, их оформление и
/// предпросмотр **на ширине привязанного принтера** — из тех же байтов, что
/// уйдут в принтер (`ReceiptPrintService.renderSalePreviewText`).
///
/// # Что изменилось 2026-09-18 и почему проба это пережила
///
/// Экран перестал звать базу и службу печати напрямую: между ним и кассой
/// встал доменный порт [ReceiptTemplateSetupRepository] с двумя реализациями
/// (кассовая и провод) — иначе он не собирался бы под браузер вовсе.
/// Проба ставит **кассовую** реализацию поверх той же настоящей базы и той
/// же настоящей службы печати, что и раньше, и потому по-прежнему меряет
/// байты, а не подделку.
///
/// Вторая перемена видна прямо в тексте: предпросмотр стал асинхронным и
/// собирается с задержкой после последней правки. `pumpAndSettle()` этого
/// **не дожидается** — таймер кадров не планирует, и настройка сходится
/// мгновенно, оставив в рамке прежний текст. Поэтому после каждой правки
/// стоит `pump(_afterDebounce)`: не косметика, а условие того, что проба
/// смотрит на новый предпросмотр, а не на старый.
void main() {
  late AppDatabase db;
  late int templateId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(const ThisPosEntriesCompanion(id: Value(1)));
    await db.receiptTemplateDao.seedDefaults();
    templateId = (await db.receiptTemplateDao.getSelected())!.id;
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<ReceiptPrintService>(
        ReceiptPrintServiceImpl(
          paperWidth: const FixedReceiptPaperWidth(ReceiptPaperWidth.mm80),
        ),
      )
      // Кассовая половина порта — над той же базой и той же службой печати.
      ..registerSingleton<ReceiptTemplateSetupRepository>(
        LocalReceiptTemplateSetup(
          db: db,
          printer: GetIt.I<ReceiptPrintService>(),
        ),
      );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru')],
        home: ReceiptTemplateEditorScreen(
          args: ReceiptTemplateEditorArgs(templateId: templateId),
        ),
      ),
    );
    for (var i = 0; i < 300; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
      if (find
          .byKey(const Key('receipt_template_header'))
          .evaluate()
          .isNotEmpty) {
        return;
      }
    }
    fail('экран шаблона не загрузился');
  }

  /// Чуть дольше задержки предпросмотра (350 мс) — разбор в докстринге.
  const afterDebounce = Duration(milliseconds: 400);

  String previewText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('receipt_template_preview')))
      .data!;

  List<String> previewLines(WidgetTester tester) =>
      previewText(tester).split('\n');

  /// Дождаться **нового** предпросмотра, а не просто «подождать».
  ///
  /// Двух шагов мало, и это измерено: `pumpAndSettle()` возвращается, как
  /// только не осталось запланированных кадров, а ответ приходит `Future`-ом,
  /// кадров не планирующим. Первая редакция этой пробы читала рамку **до**
  /// прихода ответа и падала на прежнем тексте — на том, что был до правки
  /// шапки.
  ///
  /// Поэтому ожидание не по времени, а **по факту смены текста**, и
  /// несменившийся текст — падение с внятной причиной, а не тихое
  /// «подождали и хватит».
  Future<void> awaitNewPreview(WidgetTester tester, String before) async {
    await tester.pump(afterDebounce);
    for (var i = 0; i < 200; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
      if (previewText(tester) != before) return;
    }
    fail('предпросмотр не пересобрался после правки');
  }

  testWidgets('ширина — привязанного принтера; многострочная шапка по центру в '
      'предпросмотре; выравнивание вправо переставляет строку', (tester) async {
    await open(tester);
    expect(find.text('80 мм'), findsOneWidget);
    expect(
      find.byKey(const Key('receipt_template_mandatory_note')),
      findsOneWidget,
    );
    // Выключателей обязательных реквизитов на экране больше нет.
    expect(find.text('Печатать НДС'), findsNothing);
    expect(find.text('Печатать ссылку проверки (QR)'), findsNothing);
    expect(find.text('Печатать БИН/ИИН'), findsNothing);

    final beforeHeader = previewText(tester);
    await tester.enterText(
      find.byKey(const Key('receipt_template_header')),
      'Добро пожаловать!\nВторая',
    );
    await awaitNewPreview(tester, beforeHeader);

    var lines = previewLines(tester);
    expect(lines, contains('${' ' * ((48 - 17) ~/ 2)}Добро пожаловать!'));
    expect(lines, contains('${' ' * ((48 - 6) ~/ 2)}Вторая'));
    final headerAt = lines.indexWhere((l) => l.trim() == 'Вторая');
    final checkAt = lines.indexWhere((l) => l.startsWith('Чек №'));
    expect(
      headerAt,
      lessThan(checkAt),
      reason: 'шапка выше обязательной части',
    );

    final beforeAlign = previewText(tester);
    await tester.tap(find.byIcon(Icons.format_align_right).first);
    await awaitNewPreview(tester, beforeAlign);
    lines = previewLines(tester);
    expect(lines, contains('${' ' * (48 - 6)}Вторая'));
  });
}
