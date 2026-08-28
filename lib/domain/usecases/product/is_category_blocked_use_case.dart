abstract class IsCategoryBlockedUseCase {
  Future<CategoryBlockResult> isBlocked(int categoryId);

  Future<CategoryBlockResult> isBlockedAt(int categoryId, DateTime checkTime);
}

class CategoryBlockResult {
  const CategoryBlockResult({
    required this.isBlocked,
    this.beginTime,
    this.endTime,
    this.reason,
  });

  final bool isBlocked;

  final String? beginTime;

  final String? endTime;

  final String? reason;

  factory CategoryBlockResult.allowed() =>
      const CategoryBlockResult(isBlocked: false);

  factory CategoryBlockResult.blocked({
    required String beginTime,
    required String endTime,
  }) => CategoryBlockResult(
    isBlocked: true,
    beginTime: beginTime,
    endTime: endTime,
    reason: 'Продажа запрещена с $beginTime до $endTime',
  );

  factory CategoryBlockResult.categoryNotFound() =>
      const CategoryBlockResult(isBlocked: false);
}
