abstract class TableStatusUseCase {
  Future<void> setFree(int tableId);

  Future<void> setOccupied(int tableId);

  Future<void> setReserved(int tableId);

  Future<void> setDirty(int tableId);
}
