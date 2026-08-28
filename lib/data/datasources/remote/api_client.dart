import 'api_response.dart';

abstract class ApiClient {
  bool get connectionAvailable;

  Future<bool> checkConnection();

  Future<ApiResponse<DateTime>> getServerTime();

  Future<ApiResponse<AuthResult>> login({
    required String username,
    required String password,
    required int posId,
  });

  Future<ApiResponse<void>> logout();

  Future<ApiResponse<bool>> validateToken();

  Future<ApiResponse<String>> refreshToken();

  Future<ApiResponse<UserPermissions>> getPermissions(int userId);

  Future<PaginatedApiResponse<ProductDto>> getProducts({
    int page = 1,
    int pageSize = 100,
    DateTime? modifiedSince,
  });

  Future<ApiResponse<ProductDto>> getProduct(int productId);

  Future<ApiResponse<ProductDto>> createProduct(ProductDto product);

  Future<ApiResponse<ProductDto>> updateProduct(ProductDto product);

  Future<ApiResponse<void>> deleteProduct(int productId);

  Future<ApiResponse<List<CategoryDto>>> getCategories();

  Future<ApiResponse<List<ProductDto>>> getProductsByBarcode(String barcode);

  Future<PaginatedApiResponse<ProductDto>> searchProducts({
    required String query,
    int page = 1,
    int pageSize = 50,
  });

  Future<ApiResponse<List<ProductPriceDto>>> getProductPrices(int priceTypeId);

  Future<ApiResponse<SyncResult>> syncProducts({
    DateTime? since,
    int batchSize = 500,
  });

  Future<ApiResponse<SaleUploadResult>> createSale(SaleDto sale);

  Future<PaginatedApiResponse<SaleDto>> getSales({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResponse<SaleDto>> getSale({
    required int receiptNo,
    required int posId,
  });

  Future<ApiResponse<void>> cancelSale({
    required int receiptNo,
    required int posId,
    String? reason,
  });

  Future<ApiResponse<List<SaleDto>>> getSalesByShift(int shiftId);

  Future<ApiResponse<List<SaleItemDto>>> getSaleItems({
    required int receiptNo,
    required int posId,
  });

  Future<ApiResponse<List<PaymentDto>>> getSalePayments({
    required int receiptNo,
    required int posId,
  });

  Future<ApiResponse<SyncResult>> syncSales({int batchSize = 100});

  Future<ApiResponse<RefundUploadResult>> createRefund(RefundDto refund);

  Future<PaginatedApiResponse<RefundDto>> getRefunds({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResponse<RefundDto>> getRefund(int refundId);

  Future<ApiResponse<void>> cancelRefund(int refundId, {String? reason});

  Future<ApiResponse<SyncResult>> syncRefunds({int batchSize = 100});

  Future<ApiResponse<ShiftOpenResult>> openShift(ShiftDto shift);

  Future<ApiResponse<ShiftCloseResult>> closeShift(ShiftDto shift);

  Future<PaginatedApiResponse<ShiftDto>> getShifts({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResponse<ShiftDto?>> getCurrentShift(int posId);

  Future<ApiResponse<ShiftReportDto>> getShiftReport(int shiftId);

  Future<ApiResponse<SyncResult>> syncShifts();

  Future<PaginatedApiResponse<AgentDto>> getAgents({
    int page = 1,
    int pageSize = 100,
    DateTime? modifiedSince,
  });

  Future<ApiResponse<AgentDto>> getAgent(int agentId);

  Future<ApiResponse<AgentDto>> createAgent(AgentDto agent);

  Future<ApiResponse<AgentDto>> updateAgent(AgentDto agent);

  Future<ApiResponse<AgentBalanceDto>> getAgentBalance(int agentId);

  Future<ApiResponse<SyncResult>> syncAgents({
    DateTime? since,
    int batchSize = 500,
  });

  Future<PaginatedApiResponse<SupplyDto>> getSupplies({
    int page = 1,
    int pageSize = 50,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResponse<SupplyUploadResult>> createSupply(SupplyDto supply);

  Future<ApiResponse<SupplyDto>> getSupply(int supplyId);

  Future<ApiResponse<void>> cancelSupply(int supplyId, {String? reason});

  Future<ApiResponse<SyncResult>> syncSupplies();

  Future<ApiResponse<FiscalReceiptResult>> registerReceipt(
    FiscalReceiptRequest request,
  );

  Future<ApiResponse<FiscalReceiptDto>> getReceipt(String fiscalNo);

  Future<ApiResponse<void>> cancelReceipt(String fiscalNo, {String? reason});

  Future<ApiResponse<FiscalStatusDto>> getFiscalStatus();

  Future<ApiResponse<SyncResult>> syncFiscalData();

  Future<ApiResponse<OfdStatusDto>> getOfdStatus();

  Future<ApiResponse<PosConfigDto>> getConfig(int posId);

  Future<ApiResponse<void>> updateConfig(PosConfigDto config);

  Future<ApiResponse<PosSettingsDto>> getPosSettings(int posId);

  Future<ApiResponse<List<PriceTypeDto>>> getPriceTypes();

  Future<ApiResponse<SyncResult>> syncConfig();

  Future<ApiResponse<FullSyncResult>> fullSync({
    void Function(double progress)? onProgress,
  });

  Future<ApiResponse<IncrementalSyncResult>> incrementalSync({
    required DateTime since,
    void Function(double progress)? onProgress,
  });

  Future<ApiResponse<SyncStatusDto>> getSyncStatus();

  Future<ApiResponse<void>> resetSync();

  Future<ApiResponse<CashOperationResult>> recordInvestment(
    CashOperationDto operation,
  );

  Future<ApiResponse<CashOperationResult>> recordExpense(
    CashOperationDto operation,
  );

  Future<ApiResponse<CashOperationResult>> recordDividend(
    CashOperationDto operation,
  );

  Future<ApiResponse<SyncResult>> syncCashOperations();

  Future<PaginatedApiResponse<UserDto>> getUsers({
    int page = 1,
    int pageSize = 50,
  });

  Future<ApiResponse<UserDto>> getUser(int userId);

  Future<ApiResponse<void>> updateUserPin(int userId, String encryptedPin);

  Future<ApiResponse<SyncResult>> syncUsers();

  Future<ApiResponse<DailyReportDto>> getDailyReport(DateTime date);

  Future<ApiResponse<PeriodReportDto>> getPeriodReport({
    required DateTime from,
    required DateTime to,
  });

  Future<ApiResponse<void>> uploadReport(ReportDto report);
}

class AuthResult {
  const AuthResult({
    required this.token,
    required this.userId,
    this.refreshToken,
    this.expiresAt,
  });

  final String token;
  final int userId;
  final String? refreshToken;
  final DateTime? expiresAt;
}

class UserPermissions {
  const UserPermissions({required this.userId, required this.permissions});

  final int userId;
  final Map<String, bool> permissions;
}

class ProductDto {
  const ProductDto({required this.id, required this.name});
  final int id;
  final String name;
}

class CategoryDto {
  const CategoryDto({required this.id, required this.name});
  final int id;
  final String name;
}

class ProductPriceDto {
  const ProductPriceDto({
    required this.productId,
    required this.priceTypeId,
    required this.price,
  });
  final int productId;
  final int priceTypeId;
  final String price;
}

class SaleDto {
  const SaleDto({required this.receiptNo, required this.posId});
  final int receiptNo;
  final int posId;
}

class SaleItemDto {
  const SaleItemDto({required this.productId, required this.quantity});
  final int productId;
  final String quantity;
}

class PaymentDto {
  const PaymentDto({required this.type, required this.amount});
  final String type;
  final String amount;
}

class SaleUploadResult {
  const SaleUploadResult({required this.receiptNo, required this.synced});
  final int receiptNo;
  final bool synced;
}

class RefundDto {
  const RefundDto({required this.id});
  final int id;
}

class RefundUploadResult {
  const RefundUploadResult({required this.refundId, required this.synced});
  final int refundId;
  final bool synced;
}

class ShiftDto {
  const ShiftDto({required this.id, required this.posId});
  final int id;
  final int posId;
}

class ShiftOpenResult {
  const ShiftOpenResult({required this.shiftId, required this.synced});
  final int shiftId;
  final bool synced;
}

class ShiftCloseResult {
  const ShiftCloseResult({required this.shiftId, required this.synced});
  final int shiftId;
  final bool synced;
}

class ShiftReportDto {
  const ShiftReportDto({required this.shiftId});
  final int shiftId;
}

class AgentDto {
  const AgentDto({required this.id, required this.name});
  final int id;
  final String name;
}

class AgentBalanceDto {
  const AgentBalanceDto({required this.agentId, required this.balance});
  final int agentId;
  final String balance;
}

class SupplyDto {
  const SupplyDto({required this.id});
  final int id;
}

class SupplyUploadResult {
  const SupplyUploadResult({required this.supplyId, required this.synced});
  final int supplyId;
  final bool synced;
}

class FiscalReceiptRequest {
  const FiscalReceiptRequest({required this.receiptNo, required this.posId});
  final int receiptNo;
  final int posId;
}

class FiscalReceiptResult {
  const FiscalReceiptResult({required this.fiscalNo, required this.success});
  final String fiscalNo;
  final bool success;
}

class FiscalReceiptDto {
  const FiscalReceiptDto({required this.fiscalNo});
  final String fiscalNo;
}

class FiscalStatusDto {
  const FiscalStatusDto({
    required this.isConfigured,
    required this.isConnected,
  });
  final bool isConfigured;
  final bool isConnected;
}

class OfdStatusDto {
  const OfdStatusDto({required this.isOnline});
  final bool isOnline;
}

class PosConfigDto {
  const PosConfigDto({required this.posId});
  final int posId;
}

class PosSettingsDto {
  const PosSettingsDto({required this.posId});
  final int posId;
}

class PriceTypeDto {
  const PriceTypeDto({required this.id, required this.name});
  final int id;
  final String name;
}

class CashOperationDto {
  const CashOperationDto({required this.type, required this.amount});
  final String type;
  final String amount;
}

class CashOperationResult {
  const CashOperationResult({required this.id, required this.synced});
  final int id;
  final bool synced;
}

class UserDto {
  const UserDto({required this.id, required this.name});
  final int id;
  final String name;
}

class DailyReportDto {
  const DailyReportDto({required this.date});
  final DateTime date;
}

class PeriodReportDto {
  const PeriodReportDto({required this.from, required this.to});
  final DateTime from;
  final DateTime to;
}

class ReportDto {
  const ReportDto({required this.type});
  final String type;
}

class SyncResult {
  const SyncResult({
    required this.success,
    this.itemsSynced = 0,
    this.errorMessage,
  });

  final bool success;
  final int itemsSynced;
  final String? errorMessage;

  factory SyncResult.ok({int itemsSynced = 0}) {
    return SyncResult(success: true, itemsSynced: itemsSynced);
  }

  factory SyncResult.error(String message) {
    return SyncResult(success: false, errorMessage: message);
  }
}

class FullSyncResult {
  const FullSyncResult({
    required this.success,
    this.products = 0,
    this.agents = 0,
    this.categories = 0,
    this.users = 0,
    this.errorMessage,
  });

  final bool success;
  final int products;
  final int agents;
  final int categories;
  final int users;
  final String? errorMessage;
}

class IncrementalSyncResult {
  const IncrementalSyncResult({
    required this.success,
    this.uploaded = 0,
    this.downloaded = 0,
    this.errorMessage,
  });

  final bool success;
  final int uploaded;
  final int downloaded;
  final String? errorMessage;
}

class SyncStatusDto {
  const SyncStatusDto({
    required this.lastSyncTime,
    required this.pendingUploads,
    required this.isInProgress,
  });

  final DateTime? lastSyncTime;
  final int pendingUploads;
  final bool isInProgress;
}
