import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_sale_edit_terms.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/services/currency_service.dart';

/// Кассовые условия правки строки — задача 44.
///
/// Настройки перенесены из `LocalSaleCheckoutService.policy` (проба «политика
/// кассы читается из настроек» переехала сюда же); предел и валюта — новое.
class _RecordingPolicy implements DiscountPolicy {
  _RecordingPolicy(this.cap);

  final DiscountCap cap;
  int? askedFor;

  @override
  Future<DiscountCap> capFor(int roleIndex) async {
    askedFor = roleIndex;
    return cap;
  }
}

class _StubCurrency implements CurrencyService {
  _StubCurrency(this.symbol);

  @override
  final String symbol;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен');
}

void main() {
  late AppDatabase db;
  late _RecordingPolicy policy;

  Decimal d(String v) => Decimal.parse(v);

  LocalSaleEditTerms reader({String symbol = '₸'}) => LocalSaleEditTerms(
    db: db,
    discountPolicy: policy,
    currency: _StubCurrency(symbol),
    logger: Talker(settings: TalkerSettings(enabled: false)),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    policy = _RecordingPolicy(
      DiscountCap(
        maxPercent: d('12.5'),
        approvalAbove: d('7'),
        source: 'предел роли «Кассир»',
      ),
    );
  });

  tearDown(() => db.close());

  test('настройки кассы читаются из базы, а не выдумываются', () async {
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            editPrice: Value(true),
            sellInDiscount: Value(false),
          ),
        );
    final first = await reader().read(by: DiscountAuthority.none);
    expect(first.policy.editPrice, isTrue);
    expect(first.policy.sellInDiscount, isFalse);

    // Вторая настройка, отличная от первой в обоих полях: одинаковые
    // умолчания прошли бы и с телом, возвращающим константу.
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(
        editPrice: Value(false),
        sellInDiscount: Value(true),
      ),
    );
    final second = await reader().read(by: DiscountAuthority.none);
    expect(second.policy.editPrice, isFalse);
    expect(second.policy.sellInDiscount, isTrue);
  });

  test('касса без строки настроек — умолчания: цена да, скидка нет', () async {
    final terms = await reader().read(by: DiscountAuthority.none);
    expect(terms.policy.editPrice, isTrue);
    expect(terms.policy.sellInDiscount, isFalse);
  });

  test(
    'предел — у DiscountPolicy, для роли из полномочий, без правки',
    () async {
      final terms = await reader().read(
        by: const DiscountAuthority(roleIndex: 2, permissions: {}),
      );
      expect(
        policy.askedFor,
        2,
        reason: 'предел обязан спрашиваться для роли того, кто просит',
      );
      expect(terms.cap.maxPercent, d('12.5'));
      expect(terms.cap.approvalAbove, d('7'));
      expect(terms.cap.source, 'предел роли «Кассир»');
    },
  );

  test('валюта — символ службы валют кассы', () async {
    final som = await reader(symbol: 'сом').read(by: DiscountAuthority.none);
    final tenge = await reader().read(by: DiscountAuthority.none);
    expect(som.currencySymbol, 'сом');
    expect(tenge.currencySymbol, '₸');
  });
}
