abstract class RestoreProductInfoUseCase {
  Future<bool> restore(int ucode, {required int userId});

  Future<bool> restoreByBarcode(int barcode, {required int userId});
}
