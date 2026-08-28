import 'package:telepos/domain/ismpt/ismpt_models.dart';

class IsMptCapabilities {
  const IsMptCapabilities({
    this.supportsVerify = false,
    this.supportsAcceptance = false,
    this.supportsWithdrawal = false,
    this.supportsAggregation = false,
    this.supportsTransfer = false,
    this.supportsRemarking = false,
  });

  final bool supportsVerify;

  final bool supportsAcceptance;

  final bool supportsWithdrawal;

  final bool supportsAggregation;

  final bool supportsTransfer;

  final bool supportsRemarking;

  static const IsMptCapabilities none = IsMptCapabilities();
}

abstract interface class IsMptService {
  String get id;

  IsMptCapabilities get capabilities;

  Future<IsMptResult> authorize();

  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  });

  Future<IsMptResult> submitDocument(IsMptDocRequest req);

  Future<IsMptStatus> getStatus();
}
