/// Шаблон чека из браузера можно **дойти и нажать** — решение заказчика
/// 2026-09-18.
///
/// # Почему одной пробы провода мало
///
/// `test/backend/receipt_template_op_test.dart` доказывает, что шесть
/// операций работают и что предпросмотр во вкладке есть бумага. Она **не
/// доказывает, что владелец может ими воспользоваться**, — и ровно этот класс
/// дефекта дерево ловило уже четырежды: операции отзыва сеанса были готовы и
/// недостижимы; `pay.certificateIssue` написана и не имеет ни одного
/// вызывающего; `WtPaymentService` был верен и не привязан ни одной строкой;
/// приём аванса работал и не имел экрана в браузере. Каждый раз набор
/// оставался зелёным.
///
/// Здесь по исходникам сверяются звенья цепочки, каждое из которых молчаливо
/// рвётся:
///
/// 1. **точка входа привязывает порт** — без строки экран в браузере скажет
///    «эта касса не хранит шаблонов чека» и формы не построит вовсе;
/// 2. **браузерная таблица объявляет оба маршрута** — список и правку — и
///    ведёт на настоящие экраны, а не на заглушку `WtNotPortedScreen`;
/// 3. **обоим экранам назван дом** — вкладка открывается прямо по адресу,
///    стека переходов у неё нет, и `pop()` в ней не делает ничего;
/// 4. **список ведёт на правку по константе маршрута.** Прежде переход
///    склеивался из текущего адреса (`'${uri.path}/edit'`), и такого перехода
///    `browser_routes_test` не видит вовсе: он ищет `context.go/push` по
///    константе или по литералу пути. Склейка прошла бы мимо сторожа и
///    упёрлась бы в «Page Not Found» у кассира.
///
/// Пятое звено — плитку, с которой на маршрут нажимают, — держит
/// `browser_routes_test` («на каждый объявленный маршрут кто-то ведёт»), и
/// повторять его здесь значило бы завести второе место, расходящееся с
/// первым молча.
///
/// # И одно звено, которого у соседей нет: **раскладки чека в браузере нет**
///
/// Проба провода сличает два текста и потому ловит расхождение раскладок
/// **в момент прогона**. Этот сторож запрещает саму возможность: браузерная
/// половина не имеет права ни разбирать байты ESC/POS, ни знать ширину
/// ленты в расчётах. Разбор — в докстринге
/// `lib/domain/receipt/receipt_template_setup.dart`.
@Tags(['architecture'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _entry = 'lib/web/main_web.dart';
const _table = 'lib/app/router/setup_router.dart';
const _home = 'lib/presentation/screens/terminal/terminal_home_screen.dart';
const _list =
    'lib/presentation/screens/settings/receipt/receipt_templates_screen.dart';
const _editor =
    'lib/presentation/screens/settings/receipt/receipt_template_editor_screen.dart';
const _wire = 'lib/web/wt_receipt_template_setup.dart';

/// Комментарии не считаются: ссылка в докстринге ничего не привязывает и
/// никуда не ведёт. Ровно на этом сторожа исходника и слепнут.
String _code(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('сторож смотрит в несуществующий файл $path');
  return file
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
      .join('\n');
}

void main() {
  test('точка входа браузера привязывает порт шаблона чека', () {
    final source = _code(_entry);
    expect(
      source,
      contains('registerLazySingleton<ReceiptTemplateSetupRepository>'),
      reason:
          'Без этой строки оба экрана шаблона не найдут порта в контейнере и '
          'скажут «эта касса не хранит шаблонов чека» — то есть пробел '
          'останется ровно там, где его закрывали. Набор при этом зелен: '
          'экранные пробы регистрируют порт сами.',
    );
    expect(
      source,
      contains('WtReceiptTemplateSetup('),
      reason:
          'шаблон обязан быть проводным: `LocalReceiptTemplateSetup` в '
          'браузере не компилируется вовсе (drift), а любая третья '
          'реализация здесь — вторая раскладка чека',
    );
  });

  test('браузерная таблица ведёт на настоящие экраны шаблона', () {
    final source = _code(_table);
    for (final route in ['AppRoutes.receiptTemplates', 'AppRoutes.receiptTemplateEdit']) {
      expect(
        source,
        contains('path: $route'),
        reason:
            'маршрута нет — в браузере это «Page Not Found: GoException» на '
            'плитке, которая стоит на доме терминала',
      );
    }
    // Запись в таблице и **экран** — разные вещи: `/payment` жил в таблице
    // задолго до того, как начал открывать оплату, и вёл на
    // `WtNotPortedScreen`. Сторож, смотрящий на наличие записи, был бы зелен
    // на заглушке.
    expect(source, contains('ReceiptTemplatesScreen('));
    expect(source, contains('ReceiptTemplateEditorScreen('));
    expect(
      source,
      contains('homeRoute: AppRoutes.terminalHome'),
      reason: 'списку не назван дом: вкладка, открытая прямо по адресу, '
          'стека переходов не имеет, и владелец остаётся на экране навсегда',
    );
    expect(
      source,
      contains('homeRoute: AppRoutes.receiptTemplates'),
      reason: 'правке не назван дом — тот же дефект, что у списка',
    );
  });

  test('дом терминала ведёт на шаблон чека', () {
    // Не подмена `browser_routes_test` («на каждый объявленный маршрут
    // кто-то ведёт»), а якорь против его собственной слепоты: тот сторож
    // обходит граф импортов, и опечатка в обходе сделала бы его зелёным на
    // пустом множестве. Здесь названы файл и переход.
    final source = _code(_home);
    expect(source, contains('context.go(AppRoutes.receiptTemplates)'));
    expect(
      source,
      contains('PermissionKeys.settingsPrinter'),
      reason:
          'плитка обязана стоять под тем же ключом, что маршрут и шесть '
          'операций провода: показ под другим правом означал бы кнопку, '
          'которая видна одному, а работает у другого',
    );
  });

  test('список ведёт на правку константой маршрута, а не склейкой адреса', () {
    final source = _code(_list);
    expect(
      source,
      contains('AppRoutes.receiptTemplateEdit'),
      reason:
          'переход, собранный из текущего адреса, `browser_routes_test` не '
          'видит вовсе — он ищет константу или литерал пути, — а кассир '
          'упирается в «Page Not Found»',
    );
    expect(
      source,
      isNot(contains(r'uri.path}/edit')),
      reason: 'склейка адреса вернулась — сторож маршрутов снова слеп',
    );
  });

  test('раскладки чека в браузерной половине нет ни строки', () {
    // Запрет, а не сравнение: проба провода ловит расхождение раскладок в
    // момент прогона, а этот сторож запрещает саму возможность его завести.
    // Текст чека на экране обязан рождаться в одном месте на всё дерево.
    for (final file in [_wire, _editor, _list]) {
      final source = _code(file);
      for (final forbidden in [
        'renderEscPosAsText',
        'escpos_text_preview',
        'ReceiptBuilder',
        'charWidth',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason:
              '$file знает о раскладке чека ($forbidden) — это вторая '
              'раскладка в дереве, ровно та беда, ради которой раскладку '
              'свели к одной (докстринг escpos_text_preview.dart)',
        );
      }
    }
  });
}
