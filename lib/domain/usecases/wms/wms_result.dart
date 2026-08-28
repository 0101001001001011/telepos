class WmsResult {
  const WmsResult({required this.success, this.id, this.errorMessage});

  final bool success;

  final int? id;

  final String? errorMessage;

  factory WmsResult.ok([int? id]) => WmsResult(success: true, id: id);

  factory WmsResult.failed(String message) =>
      WmsResult(success: false, errorMessage: message);
}
