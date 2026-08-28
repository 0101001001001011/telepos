/// Правило «что попадает в лист» и правило «когда об этом кричать».
///
/// Проверяется здесь именно **перекос** обеих функций: они не сравнивают два
/// набора, они спрашивают «чего не хватает в листе», и обратное направление
/// обязано молчать. Симметричная реализация прошла бы половину этих проверок и
/// на живой кассе перевыпускала бы лист при каждом отключении VPN, роняя
/// приколотый отпечаток у всех открытых страниц.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/pki/certificate_addresses.dart';

void main() {
  group('addressesOutsideCertificate', () {
    test('лист называет всё, на чём касса отвечает — молчит', () {
      expect(
        addressesOutsideCertificate(
          live: <String>['192.168.1.31', '10.8.10.23'],
          certified: <String>['192.168.1.31', '10.8.10.23'],
        ),
        isEmpty,
      );
    });

    test('адрес уехал по DHCP — назван новый, не старый', () {
      // Ровно измеренный отказ: касса была на .30, стала на .31, лист держит
      // .30 и рукопожатие по .31 падает.
      expect(
        addressesOutsideCertificate(
          live: <String>['192.168.1.31'],
          certified: <String>['192.168.1.30'],
        ),
        <String>['192.168.1.31'],
      );
    });

    test('лишний адрес в листе — не событие', () {
      // Обратное направление. Вчерашний адрес в листе никому не мешает, а
      // перевыпуск ради него оборвал бы живые сессии.
      expect(
        addressesOutsideCertificate(
          live: <String>['192.168.1.30'],
          certified: <String>['192.168.1.30', '192.168.1.29', '10.8.10.23'],
        ),
        isEmpty,
      );
    });

    test('лист пуст — непокрыт каждый адрес машины', () {
      // Состояние кассы до 0.4.0: в листе только имена. Проверка обязана
      // назвать всё, иначе дефект остаётся невидимым ровно так, как был.
      expect(
        addressesOutsideCertificate(
          live: <String>['192.168.1.210', '10.8.10.23'],
          certified: const <String>[],
        ),
        <String>['192.168.1.210', '10.8.10.23'],
      );
    });

    test('машина без сети — непокрытых нет, а не «всё сломано»', () {
      expect(
        addressesOutsideCertificate(
          live: const <String>[],
          certified: <String>['192.168.1.30'],
        ),
        isEmpty,
      );
    });

    test('порядок не важен, важен состав', () {
      expect(
        addressesOutsideCertificate(
          live: <String>['10.8.10.23', '192.168.1.31'],
          certified: <String>['192.168.1.31', '10.8.10.23'],
        ),
        isEmpty,
      );
    });
  });

  group('namesOutsideCertificate', () {
    test('регистр имени не считается расхождением', () {
      // Имя берётся из `Platform.localHostname`, который на Windows отдаёт его
      // как записано в системе — `DESKTOP-N89SRFH`, — а в лист уходит в нижнем
      // регистре. Сравнение с учётом регистра перевыпускало бы лист на каждом
      // подъёме, и каждый подъём менял бы отпечаток.
      expect(
        namesOutsideCertificate(
          live: <String>['localhost', 'DESKTOP-N89SRFH.local'],
          certified: <String>['localhost', 'desktop-n89srfh.local'],
        ),
        isEmpty,
      );
    });

    test('кассу переименовали — новое имя названо', () {
      expect(
        namesOutsideCertificate(
          live: <String>['localhost', 'till-4.local'],
          certified: <String>['localhost', 'till-3.local'],
        ),
        <String>['till-4.local'],
      );
    });

    test('старое имя в листе — не событие', () {
      expect(
        namesOutsideCertificate(
          live: <String>['localhost'],
          certified: <String>['localhost', 'till-3.local'],
        ),
        isEmpty,
      );
    });
  });

  group('certificateAddresses', () {
    test('ни один адрес не петля и не link-local', () async {
      // На настоящих интерфейсах этой машины. Проверяется не длина списка —
      // она зависит от машины, — а то, что в лист не попадает адрес, по
      // которому касса заведомо недостижима: `127.0.0.1` отправил бы терминал
      // искать кассу внутри себя, `169.254/16` означает «DHCP не ответил».
      final addresses = await certificateAddresses();
      for (final address in addresses) {
        expect(address.startsWith('127.'), isFalse, reason: address);
        expect(address.startsWith('169.254.'), isFalse, reason: address);
      }
    });

    test('только IPv4 в точечной записи — двоеточий нет', () async {
      // IPv6 решено не класть (см. доку функции). Проверка ловит день, когда
      // источник списка начнёт отдавать v6, а решение об этом принято не будет.
      final addresses = await certificateAddresses();
      for (final address in addresses) {
        expect(address, isNot(contains(':')), reason: address);
        expect(address.split('.'), hasLength(4), reason: address);
      }
    });
  });
}
