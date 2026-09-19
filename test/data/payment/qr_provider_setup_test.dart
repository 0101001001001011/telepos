/// Настройка провайдера QR с экрана кассы — пункт 8 C (2026-09-15).
///
/// Реализация порта — `QrPaymentDesk`, единственный читатель настройки
/// (сторож `qr_secret_never_reaches_terminal_test.dart`). Пробы идут через
/// порт — ровно тем путём, каким пойдёт экран, — а базу читают только для
/// улики, что ключ лёг и не стёрт.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/qr_payment_desk.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';

void main() {
  late AppDatabase db;
  late QrProviderSetupRepository setup;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    setup = QrPaymentDesk(db: db, logger: Talker());
  });
  tearDown(() => db.close());

  Future<String?> storedKey() async =>
      (await db.qrProviderConfigDao.read())?.apiKey;

  test('пустая касса — не настроено, ключа нет, вид выключен', () async {
    final view = await setup.read();
    expect(view.configured, isFalse);
    expect(view.keySet, isFalse);
    expect(view.kindActive, isFalse, reason: 'вид 6 заводится выключенным');
  });

  test('сохранённое читается обратно, ключ — только признаком', () async {
    await setup.save(
      baseUrl: ' https://sbp.example/api ',
      code: 'sbp_bank',
      patience: const Duration(seconds: 240),
      newApiKey: 'sk-live-секрет',
    );
    final view = await setup.read();
    expect(view.configured, isTrue);
    expect(view.baseUrl, 'https://sbp.example/api');
    expect(view.code, 'sbp_bank');
    expect(view.patience, const Duration(seconds: 240));
    expect(view.keySet, isTrue);
    expect(await storedKey(), 'sk-live-секрет');
  });

  test('пересохранение без ключа прежний ключ не стирает', () async {
    await setup.save(
      baseUrl: 'https://a',
      code: 'c',
      patience: const Duration(minutes: 3),
      newApiKey: 'k1',
    );
    await setup.save(
      baseUrl: 'https://b',
      code: 'c',
      patience: const Duration(minutes: 3),
    );
    expect(await storedKey(), 'k1');
    await setup.save(
      baseUrl: 'https://b',
      code: 'c',
      patience: const Duration(minutes: 3),
      newApiKey: '   ',
    );
    expect(await storedKey(), 'k1', reason: 'пробелы — не новый ключ');
    expect((await setup.read()).baseUrl, 'https://b');
  });

  test('ключ стирается только явно', () async {
    await setup.save(
      baseUrl: 'https://a',
      code: 'c',
      patience: const Duration(minutes: 3),
      newApiKey: 'k1',
    );
    await setup.save(
      baseUrl: 'https://a',
      code: 'c',
      patience: const Duration(minutes: 3),
      clearApiKey: true,
    );
    expect(await storedKey(), isNull);
    expect((await setup.read()).keySet, isFalse);
  });

  test('снятие настройки — касса снова «не настроено»', () async {
    await setup.save(
      baseUrl: 'https://a',
      code: 'c',
      patience: const Duration(minutes: 3),
    );
    await setup.clear();
    expect((await setup.read()).configured, isFalse);
  });

  test('вид оплаты QR включается и выключается тем же экраном', () async {
    await setup.setKindActive(true);
    expect((await setup.read()).kindActive, isTrue);
    await setup.setKindActive(false);
    expect((await setup.read()).kindActive, isFalse);
  });
}
