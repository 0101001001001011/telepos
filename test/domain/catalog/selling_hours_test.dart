/// Часы запрета продажи — включая ночное окно.
///
/// # Что измерено 2026-09-22
///
/// В продукте была таблица `category_restrictions`, DAO и договор
/// `IsCategoryBlockedUseCase` — и ни одного вызова. Запрет объявлен и не
/// работал; в Казахстане, России, Киргизии, Узбекистане и большинстве
/// штатов США ночная продажа алкоголя запрещена законом.
///
/// Внутри самого DAO пряталась вторая беда: он выполнял запрос с учётом
/// РОДИТЕЛЬСКОЙ категории и выбрасывал его результат, возвращая другой, без
/// родителя. То есть запрет на «Алкоголь» не распространился бы на «Пиво».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/catalog/selling_hours.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 9, 22, hour, minute);

  group('разбор записи ЧЧ:ММ', () {
    test('обычные записи', () {
      expect(minutesOfDay('00:00'), 0);
      expect(minutesOfDay('08:00'), 480);
      expect(minutesOfDay('23:59'), 1439);
      expect(minutesOfDay('9:05'), 545);
      expect(minutesOfDay('  08:00  '), 480);
    });

    test('непригодные записи не принимаются молча', () {
      // Принять «25:00» значило бы завести окно, которое не наступит, и
      // владелец узнал бы об этом из ночной продажи, а не из настройки.
      for (final bad in ['25:00', '08:60', '8', '08-00', '', 'ночь', null]) {
        expect(minutesOfDay(bad), isNull, reason: 'принято «$bad»');
      }
    });
  });

  group('окно внутри суток', () {
    final ban = SellingBan.parse('14:00', '16:00')!;

    test('до, внутри и после', () {
      expect(ban.bansAt(at(13, 59)), isFalse);
      expect(ban.bansAt(at(14, 0)), isTrue);
      expect(ban.bansAt(at(15, 30)), isTrue);
      expect(ban.bansAt(at(16, 0)), isFalse);
      expect(ban.bansAt(at(16, 1)), isFalse);
    });

    test('конец окна не включается', () {
      // Запрет «до 16:00» снимается ровно в 16:00. Включи мы эту минуту —
      // касса отказывала бы тогда, когда закон уже разрешает.
      expect(ban.bansAt(at(16, 0)), isFalse);
    });

    test('полночь не пересекает', () => expect(ban.crossesMidnight, isFalse));
  });

  group('ночное окно — главный случай', () {
    final night = SellingBan.parse('23:00', '08:00')!;

    test('пересечение полуночи опознано', () {
      expect(night.crossesMidnight, isTrue);
    });

    test('запрещает всю ночь, по обе стороны полуночи', () {
      // Наивное `begin <= now && now < end` молчало бы здесь целиком — то
      // есть ровно тогда, когда запрет и нужен.
      expect(night.bansAt(at(22, 59)), isFalse);
      expect(night.bansAt(at(23, 0)), isTrue);
      expect(night.bansAt(at(23, 59)), isTrue);
      expect(night.bansAt(at(0, 0)), isTrue);
      expect(night.bansAt(at(3, 30)), isTrue);
      expect(night.bansAt(at(7, 59)), isTrue);
      expect(night.bansAt(at(8, 0)), isFalse);
      expect(night.bansAt(at(12, 0)), isFalse);
    });
  });

  group('пустое окно', () {
    test('начало равно концу — не запрещает ничего', () {
      // Второе прочтение («запрещено круглосуточно») остановило бы продажу
      // у владельца, который стёр часы наполовину.
      final empty = SellingBan.parse('08:00', '08:00')!;
      expect(empty.isEmpty, isTrue);
      for (var h = 0; h < 24; h++) {
        expect(empty.bansAt(at(h, 0)), isFalse, reason: 'час $h');
      }
    });

    test('непригодная половина — окна нет вовсе', () {
      expect(SellingBan.parse('08:00', null), isNull);
      expect(SellingBan.parse(null, '08:00'), isNull);
      expect(SellingBan.parse('ночью', '08:00'), isNull);
    });
  });

  group('несколько окон у одной категории', () {
    test('срабатывает любое, а не только первое', () {
      // Прежняя реализация брала `restrictions.first` и молча теряла
      // остальные: второе окно не работало никогда.
      final windows = [
        SellingBan.parse('23:00', '08:00')!,
        SellingBan.parse('13:00', '14:00')!,
      ];
      expect(activeBan(windows, at(13, 30)), isNotNull);
      expect(activeBan(windows, at(2, 0)), isNotNull);
      expect(activeBan(windows, at(17, 0)), isNull);
    });

    test('называется ИМЕННО то окно, которое запретило', () {
      // Кассиру нужно знать, до какого часа ждать. Назови мы первое окно
      // вместо сработавшего — он ждал бы до восьми утра вместо двух дня.
      final windows = [
        SellingBan.parse('23:00', '08:00')!,
        SellingBan.parse('13:00', '14:00')!,
      ];
      expect(activeBan(windows, at(13, 30))!.label, '13:00–14:00');
      expect(activeBan(windows, at(2, 0))!.label, '23:00–08:00');
    });

    test('пустой список окон не запрещает', () {
      expect(activeBan(const [], at(3, 0)), isNull);
    });
  });
}
