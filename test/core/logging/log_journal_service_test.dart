library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/logging/log_journal_service.dart';

void main() {
  late Directory tmp;
  late LogJournalService svc;

  String today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return 'app-${n.year}-$m-$d.log';
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('telepos_logs_');
    svc = LogJournalService(logDirectory: tmp.path);
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File mk(String name, String content) {
    final f = File('${tmp.path}${Platform.pathSeparator}$name');
    f.writeAsStringSync(content);
    return f;
  }

  test('listLogs returns only app-*.log, newest first, with sizes', () {
    mk('app-2026-06-10.log', 'a');
    mk('app-2026-06-12.log', 'bb');
    mk('app-2026-06-11.log', 'ccc');
    mk('store.log', 'ignored');
    mk('notes.txt', 'ignored');

    final logs = svc.listLogs();
    expect(logs.map((e) => e.name).toList(), [
      'app-2026-06-12.log',
      'app-2026-06-11.log',
      'app-2026-06-10.log',
    ]);
    expect(logs.firstWhere((e) => e.name == 'app-2026-06-11.log').sizeBytes, 3);
    expect(svc.totalSizeBytes(), 1 + 2 + 3);
  });

  test('exportTo copies every log file into the target (USB) folder', () async {
    mk('app-2026-06-10.log', 'one');
    mk('app-2026-06-11.log', 'two');
    final dest = Directory.systemTemp.createTempSync('telepos_usb_');
    addTearDown(() => dest.deleteSync(recursive: true));

    final n = await svc.exportTo(dest.path);
    expect(n, 2);
    expect(
      File(
        '${dest.path}${Platform.pathSeparator}app-2026-06-10.log',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${dest.path}${Platform.pathSeparator}app-2026-06-11.log',
      ).readAsStringSync(),
      'two',
    );
  });

  test('deleteAllExceptToday keeps the active (today) file only', () async {
    mk('app-2026-06-10.log', 'old');
    mk('app-2026-06-11.log', 'old2');
    mk(today(), 'active');

    final deleted = await svc.deleteAllExceptToday();
    expect(deleted, 2);
    final remaining = svc.listLogs().map((e) => e.name).toList();
    expect(remaining, [today()]);
  });

  test('empty / missing directory is handled gracefully', () async {
    final missing = LogJournalService(
      logDirectory: '${tmp.path}${Platform.pathSeparator}nope',
    );
    expect(missing.listLogs(), isEmpty);
    expect(missing.totalSizeBytes(), 0);
    expect(await missing.exportTo(tmp.path), 0);
  });
}
