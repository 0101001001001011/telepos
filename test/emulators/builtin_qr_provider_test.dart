/// Встроенный эмулятор провайдера QR — насквозь до кассы.
///
/// # Почему без `TestWidgetsFlutterBinding`
///
/// Под ним всякий `HttpClient` отвечает 400, не выходя в сеть, — а здесь
/// проверяется ровно выход в сеть: касса идёт к эмулятору своим
/// `HttpQrPaymentProvider`. Проба, поднявшая виджетное окружение, была бы
/// зелёной при любом эмуляторе и при любом продукте (измерено на соседних
/// пробах этого дерева).
///
/// # Чего эти пробы НЕ доказывают
///
/// Что деньги списаны: банка здесь нет, и подтверждение приходит от пульта
/// эмулятора, а не от покупателя. Что настоящий провайдер отвечает такими же
/// словами — форма протокола выдумана, см. докстринг эмулятора. Доказывается
/// одно, но важное: **выключатель на экране настроек и адрес, который он
/// называет, ведут к живому собеседнику, с которым продукт разговаривает
/// своим кодом** — сборкой запроса, разбором ответа, разбором состояний.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/settings/builtin_emulator_settings.dart';
import 'package:telepos/data/payment/http_qr_payment_provider.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';
import 'package:telepos/emulators/builtin_emulator_host.dart';

void main() {
  group('Встроенный провайдер QR', () {
    test('боевой диапазон — тот же порт, с которого его запускают руками', () {
      expect(
        BuiltinEmulatorHost.defaultPortRanges[BuiltinEmulatorKind.qrProvider],
        (8890, 8899),
        reason:
            '8890 написан и в README стенда, и в докстринге '
            'QrProviderSettings.baseUrl: вписанный когда-то вручную адрес '
            'обязан вести туда же, куда и встроенный',
      );
    });

    test('поднятый адрес — ссылка, и по ней отвечает провайдер', () async {
      final host = BuiltinEmulatorHost(
        // Свой диапазон, а не боевой: проба, дерущаяся с машиной за
        // фиксированный номер, меряет машину, а не продукт.
        portRanges: {BuiltinEmulatorKind.qrProvider: (18890, 18899)},
      );
      addTearDown(host.stopAll);

      final address = await host.start(BuiltinEmulatorKind.qrProvider);
      expect(
        address.baseUrl,
        'http://${address.host}:${address.port}',
        reason: 'в настройку провайдера вписывается ссылка целиком, не хост',
      );

      // Касса идёт к эмулятору СВОИМ провайдером: своей сборкой запроса,
      // своим разбором ответа, своим разбором состояния. Подставь мы сюда
      // подделку `QrPaymentProvider` — проверка перестала бы говорить
      // что-либо о настоящем провайдере.
      final provider = HttpQrPaymentProvider(
        baseUrl: address.baseUrl!,
        code: 'sbp_builtin',
        timeout: const Duration(seconds: 5),
      );
      addTearDown(provider.close);

      final created = await provider.create(
        intentKey: 'builtin-1',
        amount: Decimal.parse('1500.00'),
      );
      expect(
        created.isOk,
        isTrue,
        reason: 'отказ: ${created.refusal?.code} ${created.refusal?.message}',
      );
      expect(created.value!.status, QrIntentStatus.pending);

      // Покупатель платит — **действием пульта**, а не продукта.
      await _control(address, '/_emul/pay', {
        'intentId': created.value!.providerIntentId,
      });

      final polled = await provider.poll(created.value!.providerIntentId);
      expect(polled.isOk, isTrue);
      expect(
        polled.value!.status,
        QrIntentStatus.paid,
        reason:
            'это и есть «всё в комплексе»: ничего не установлено, а оплата по '
            'коду прошла весь путь кассы до подтверждения',
      );
    });

    test('погашенный эмулятор отвечает отказом, а не тишиной', () async {
      final host = BuiltinEmulatorHost(
        portRanges: {BuiltinEmulatorKind.qrProvider: (18870, 18879)},
      );
      final address = await host.start(BuiltinEmulatorKind.qrProvider);
      await host.stop(BuiltinEmulatorKind.qrProvider);

      expect(host.isRunning(BuiltinEmulatorKind.qrProvider), isFalse);

      final provider = HttpQrPaymentProvider(
        baseUrl: address.baseUrl!,
        code: 'sbp_builtin',
        timeout: const Duration(seconds: 2),
      );
      addTearDown(provider.close);

      final created = await provider.create(
        intentKey: 'builtin-gone',
        amount: Decimal.parse('10.00'),
      );
      expect(
        created.isOk,
        isFalse,
        reason:
            'касса, оставшаяся с адресом погашенного эмулятора, обязана '
            'честно сказать «связи нет», а не сделать вид, что оплата прошла',
      );
      // **Транзиентный**, а не любой: деньги могли уйти до того, как сокет
      // погас, и хоронить намерение по такому отказу нельзя. Какой именно из
      // двух транзиентных — `qr_network` или `qr_timeout` — решает не
      // продукт, а стек: измерено на Windows, где закрытый порт петли даёт
      // тайм-аут, а не отказ соединения. Требовать здесь одного из двух
      // значило бы мерить операционную систему.
      expect(
        created.refusal!.isTransient,
        isTrue,
        reason: 'названная причина: ${created.refusal!.code}',
      );
    });
  });
}

/// Стук в пульт эмулятора.
Future<void> _control(
  BuiltinEmulatorAddress address,
  String path,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://${address.host}:${address.controlPort}$path'),
    );
    request.write(jsonEncode(body));
    final response = await request.close();
    await response.drain<void>();
  } finally {
    client.close(force: true);
  }
}
