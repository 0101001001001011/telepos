import 'package:telepos/domain/entities/auth/identification_result.dart';

abstract class RoleIdentificationService {
  Future<IdentificationResult> identify(String code);
}
