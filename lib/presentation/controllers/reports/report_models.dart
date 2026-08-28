import 'package:decimal/decimal.dart';

class DashboardKpis {
  const DashboardKpis({
    required this.todayRevenue,
    required this.yesterdayRevenue,
    required this.todaySalesCount,
    required this.avgCheck,
  });

  final Decimal todayRevenue;
  final Decimal yesterdayRevenue;
  final Decimal avgCheck;
  final int todaySalesCount;

  double get changePercent => yesterdayRevenue > Decimal.zero
      ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue).toDouble() * 100
      : 0;
}

class RevenueByDay {
  const RevenueByDay({
    required this.dayTimestamp,
    required this.revenue,
    required this.count,
  });

  final int dayTimestamp;
  final Decimal revenue;
  final int count;
}

class ProductRanking {
  const ProductRanking({
    required this.ucode,
    required this.name,
    required this.revenue,
    required this.qtySold,
  });

  final int ucode;
  final String name;
  final Decimal revenue;
  final Decimal qtySold;
}

class PaymentMethodBreakdown {
  const PaymentMethodBreakdown({
    required this.accountId,
    required this.name,
    required this.accountType,
    required this.total,
  });

  final int accountId;
  final String name;
  final int accountType;
  final Decimal total;
}

class HourlyDistribution {
  const HourlyDistribution({
    required this.hour,
    required this.count,
    required this.revenue,
  });

  final int hour;
  final int count;
  final Decimal revenue;
}

class CashierPerformance {
  const CashierPerformance({
    required this.userId,
    required this.name,
    required this.saleCount,
    required this.revenue,
  });

  final int userId;
  final String name;
  final int saleCount;
  final Decimal revenue;
}

class CategoryPerformance {
  const CategoryPerformance({
    required this.categoryId,
    required this.name,
    required this.revenue,
    required this.qty,
  });

  final int? categoryId;
  final String name;
  final Decimal revenue;
  final Decimal qty;
}

class LowStockItem {
  const LowStockItem({
    required this.ucode,
    required this.name,
    required this.stock,
    required this.sellingPrice,
  });

  final int ucode;
  final String name;
  final Decimal stock;
  final Decimal sellingPrice;
}

class CashFlowItem {
  const CashFlowItem({
    required this.dayTimestamp,
    required this.type,
    required this.total,
  });

  final int dayTimestamp;
  final int type;
  final Decimal total;
}

class RefundTrend {
  const RefundTrend({
    required this.dayTimestamp,
    required this.count,
    required this.total,
  });

  final int dayTimestamp;
  final int count;
  final Decimal total;
}

class CustomerRanking {
  const CustomerRanking({
    required this.localId,
    required this.name,
    required this.revenue,
    required this.saleCount,
  });

  final int localId;
  final String name;
  final Decimal revenue;
  final int saleCount;
}

class SupplierVolume {
  const SupplierVolume({
    required this.localId,
    required this.name,
    required this.supplyCount,
  });

  final int localId;
  final String name;
  final int supplyCount;
}

class StockDepletion {
  const StockDepletion({
    required this.ucode,
    required this.name,
    required this.stock,
    required this.totalSold,
    required this.daysInRange,
  });

  final int ucode;
  final String name;
  final Decimal stock;
  final Decimal totalSold;
  final double daysInRange;

  double get avgDailySales =>
      daysInRange > 0 ? totalSold.toDouble() / daysInRange : 0;

  double get daysUntilOut =>
      avgDailySales > 0 ? stock.toDouble() / avgDailySales : double.infinity;
}
