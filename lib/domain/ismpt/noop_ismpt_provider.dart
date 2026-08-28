import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';

class NoOpIsMptProvider implements IsMptService {
  const NoOpIsMptProvider();

  @override
  String get id => 'ismpt_noop';

  @override
  IsMptCapabilities get capabilities => IsMptCapabilities.none;

  @override
  Future<IsMptResult> authorize() async => IsMptResult.notConfigured();

  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) async => IsMptVerifyResult.unsupported();

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async =>
      IsMptResult.unsupported(req.type.name);

  @override
  Future<IsMptStatus> getStatus() async => IsMptStatus.notConfigured();
}
