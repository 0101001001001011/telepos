import 'package:telepos/domain/entities/restaurant/guest_split_entry.dart';

abstract class SplitBillUseCase {
  Future<void> splitEvenly(int orderId, int guestCount);

  Future<void> splitByItems(int orderId, List<GuestSplitEntry> splits);

  Future<List<GuestSplitEntry>> getSplits(int orderId);
}
