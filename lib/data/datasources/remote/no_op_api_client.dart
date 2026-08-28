import 'api_client.dart';
import 'api_response.dart';

class NoOpApiClient implements ApiClient {
  NoOpApiClient({this.debugLogging = false});

  final bool debugLogging;

  void _log(String method) {
    if (debugLogging) {
      // ignore: avoid_print
      print('[NoOpApiClient] $method called (stub)');
    }
  }

  @override
  bool get connectionAvailable => false;

  @override
  Future<bool> checkConnection() async {
    _log('checkConnection');
    return false;
  }

  @override
  Future<ApiResponse<DateTime>> getServerTime() async {
    _log('getServerTime');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<AuthResult>> login({
    required String username,
    required String password,
    required int posId,
  }) async {
    _log('login');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> logout() async {
    _log('logout');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<bool>> validateToken() async {
    _log('validateToken');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<String>> refreshToken() async {
    _log('refreshToken');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<UserPermissions>> getPermissions(int userId) async {
    _log('getPermissions');
    return ApiResponse.offline();
  }

  @override
  Future<PaginatedApiResponse<ProductDto>> getProducts({
    int page = 1,
    int pageSize = 100,
    DateTime? modifiedSince,
  }) async {
    _log('getProducts');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<ProductDto>> getProduct(int productId) async {
    _log('getProduct');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<ProductDto>> createProduct(ProductDto product) async {
    _log('createProduct');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<ProductDto>> updateProduct(ProductDto product) async {
    _log('updateProduct');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> deleteProduct(int productId) async {
    _log('deleteProduct');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<CategoryDto>>> getCategories() async {
    _log('getCategories');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<ProductDto>>> getProductsByBarcode(
    String barcode,
  ) async {
    _log('getProductsByBarcode');
    return ApiResponse.offline();
  }

  @override
  Future<PaginatedApiResponse<ProductDto>> searchProducts({
    required String query,
    int page = 1,
    int pageSize = 50,
  }) async {
    _log('searchProducts');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<List<ProductPriceDto>>> getProductPrices(
    int priceTypeId,
  ) async {
    _log('getProductPrices');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncProducts({
    DateTime? since,
    int batchSize = 500,
  }) async {
    _log('syncProducts');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<SaleUploadResult>> createSale(SaleDto sale) async {
    _log('createSale');
    return ApiResponse.offline();
  }

  @override
  Future<PaginatedApiResponse<SaleDto>> getSales({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    _log('getSales');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<SaleDto>> getSale({
    required int receiptNo,
    required int posId,
  }) async {
    _log('getSale');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> cancelSale({
    required int receiptNo,
    required int posId,
    String? reason,
  }) async {
    _log('cancelSale');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<SaleDto>>> getSalesByShift(int shiftId) async {
    _log('getSalesByShift');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<SaleItemDto>>> getSaleItems({
    required int receiptNo,
    required int posId,
  }) async {
    _log('getSaleItems');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<PaymentDto>>> getSalePayments({
    required int receiptNo,
    required int posId,
  }) async {
    _log('getSalePayments');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncSales({int batchSize = 100}) async {
    _log('syncSales');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<RefundUploadResult>> createRefund(RefundDto refund) async {
    _log('createRefund');
    return ApiResponse.offline();
  }

  @override
  Future<PaginatedApiResponse<RefundDto>> getRefunds({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    _log('getRefunds');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<RefundDto>> getRefund(int refundId) async {
    _log('getRefund');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> cancelRefund(int refundId, {String? reason}) async {
    _log('cancelRefund');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncRefunds({int batchSize = 100}) async {
    _log('syncRefunds');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<ShiftOpenResult>> openShift(ShiftDto shift) async {
    _log('openShift');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<ShiftCloseResult>> closeShift(ShiftDto shift) async {
    _log('closeShift');
    return ApiResponse.offline();
  }

  @override
  Future<PaginatedApiResponse<ShiftDto>> getShifts({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    _log('getShifts');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<ShiftDto?>> getCurrentShift(int posId) async {
    _log('getCurrentShift');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<ShiftReportDto>> getShiftReport(int shiftId) async {
    _log('getShiftReport');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncShifts() async {
    _log('syncShifts');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<PaginatedApiResponse<AgentDto>> getAgents({
    int page = 1,
    int pageSize = 100,
    DateTime? modifiedSince,
  }) async {
    _log('getAgents');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<AgentDto>> getAgent(int agentId) async {
    _log('getAgent');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<AgentDto>> createAgent(AgentDto agent) async {
    _log('createAgent');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<AgentDto>> updateAgent(AgentDto agent) async {
    _log('updateAgent');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<AgentBalanceDto>> getAgentBalance(int agentId) async {
    _log('getAgentBalance');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncAgents({
    DateTime? since,
    int batchSize = 500,
  }) async {
    _log('syncAgents');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<PaginatedApiResponse<SupplyDto>> getSupplies({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    _log('getSupplies');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<SupplyUploadResult>> createSupply(SupplyDto supply) async {
    _log('createSupply');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SupplyDto>> getSupply(int supplyId) async {
    _log('getSupply');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> cancelSupply(int supplyId, {String? reason}) async {
    _log('cancelSupply');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncSupplies() async {
    _log('syncSupplies');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<FiscalReceiptResult>> registerReceipt(
    FiscalReceiptRequest request,
  ) async {
    _log('registerReceipt');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<FiscalReceiptDto>> getReceipt(String fiscalNo) async {
    _log('getReceipt');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> cancelReceipt(
    String fiscalNo, {
    String? reason,
  }) async {
    _log('cancelReceipt');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<FiscalStatusDto>> getFiscalStatus() async {
    _log('getFiscalStatus');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncFiscalData() async {
    _log('syncFiscalData');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<OfdStatusDto>> getOfdStatus() async {
    _log('getOfdStatus');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<PosConfigDto>> getConfig(int posId) async {
    _log('getConfig');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> updateConfig(PosConfigDto config) async {
    _log('updateConfig');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<PosSettingsDto>> getPosSettings(int posId) async {
    _log('getPosSettings');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<List<PriceTypeDto>>> getPriceTypes() async {
    _log('getPriceTypes');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncConfig() async {
    _log('syncConfig');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<FullSyncResult>> fullSync({
    void Function(double progress)? onProgress,
  }) async {
    _log('fullSync');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<IncrementalSyncResult>> incrementalSync({
    required DateTime since,
    void Function(double progress)? onProgress,
  }) async {
    _log('incrementalSync');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncStatusDto>> getSyncStatus() async {
    _log('getSyncStatus');
    return ApiResponse.ok(
      const SyncStatusDto(
        lastSyncTime: null,
        pendingUploads: 0,
        isInProgress: false,
      ),
    );
  }

  @override
  Future<ApiResponse<void>> resetSync() async {
    _log('resetSync');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<CashOperationResult>> recordInvestment(
    CashOperationDto operation,
  ) async {
    _log('recordInvestment');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<CashOperationResult>> recordExpense(
    CashOperationDto operation,
  ) async {
    _log('recordExpense');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<CashOperationResult>> recordDividend(
    CashOperationDto operation,
  ) async {
    _log('recordDividend');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncCashOperations() async {
    _log('syncCashOperations');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<PaginatedApiResponse<UserDto>> getUsers({
    int page = 1,
    int pageSize = 50,
  }) async {
    _log('getUsers');
    return PaginatedApiResponse.stub();
  }

  @override
  Future<ApiResponse<UserDto>> getUser(int userId) async {
    _log('getUser');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> updateUserPin(
    int userId,
    String encryptedPin,
  ) async {
    _log('updateUserPin');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<SyncResult>> syncUsers() async {
    _log('syncUsers');
    return ApiResponse.ok(SyncResult.error('Offline'));
  }

  @override
  Future<ApiResponse<DailyReportDto>> getDailyReport(DateTime date) async {
    _log('getDailyReport');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<PeriodReportDto>> getPeriodReport({
    required DateTime from,
    required DateTime to,
  }) async {
    _log('getPeriodReport');
    return ApiResponse.offline();
  }

  @override
  Future<ApiResponse<void>> uploadReport(ReportDto report) async {
    _log('uploadReport');
    return ApiResponse.offline();
  }
}
