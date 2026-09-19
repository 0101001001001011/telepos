import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/services/currency_service.dart';

/// Кассовая реализация [SaleEditTermsReader].
///
/// Настройки перенесены из `LocalSaleCheckoutService.policy` как есть, с теми
/// же умолчаниями; предел — у того же [DiscountPolicy], который отдан
/// `LocalCartService` и которым она отказывает (`service_locator.dart`
/// регистрирует один объект на кассу); символ — у той же [CurrencyService],
/// которой диалог скидки пользовался напрямую до задачи 44.
class LocalSaleEditTerms implements SaleEditTermsReader {
  LocalSaleEditTerms({
    required AppDatabase db,
    required DiscountPolicy discountPolicy,
    required CurrencyService currency,
    required Talker logger,
  }) : _db = db,
       _discountPolicy = discountPolicy,
       _currency = currency,
       _logger = logger;

  final AppDatabase _db;
  final DiscountPolicy _discountPolicy;
  final CurrencyService _currency;
  final Talker _logger;

  @override
  Future<SaleEditTerms> read({required DiscountAuthority by}) async => SaleEditTerms(
    policy: await _policy(),
    cap: await _discountPolicy.capFor(by.roleIndex),
    currencySymbol: _currency.symbol,
  );

  /// Умолчания те же, что стояли у каждого чтения в контроллере и на экране:
  /// правка цены разрешена (`canEditPrice` возвращала `true` и при ошибке
  /// чтения), продажа со скидкой — только по настройке.
  Future<SalePolicy> _policy() async {
    try {
      final pos = await _db.thisPosDao.get();
      if (pos == null) {
        return const SalePolicy(editPrice: true, sellInDiscount: false);
      }
      return SalePolicy(
        editPrice: pos.editPrice,
        sellInDiscount: pos.sellInDiscount,
      );
    } catch (e) {
      _logger.warning('SaleEditTerms: policy read failed: $e');
      return const SalePolicy(editPrice: true, sellInDiscount: false);
    }
  }
}
