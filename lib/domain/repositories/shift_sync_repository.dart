abstract class ShiftSyncRepository {
  Future<Map<String, dynamic>?> getCurrentShift();

  Future<List<Map<String, dynamic>>> getUnsyncedShifts();

  Future<void> markShiftsSynced(List<int> shiftIds);
}
