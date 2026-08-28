abstract class AgentValidationService {
  BinValidation validateBin(String bin);

  bool isIndividual(String bin);

  bool isLegalEntity(String bin);

  bool validatePhone(int phone);
}

class BinValidation {
  const BinValidation._({
    required this.isValid,
    this.type,
    this.error,
    this.birthDate,
  });

  final bool isValid;

  final BinType? type;

  final String? error;

  final DateTime? birthDate;

  factory BinValidation.validIndividual({DateTime? birthDate}) =>
      BinValidation._(
        isValid: true,
        type: BinType.individual,
        birthDate: birthDate,
      );

  factory BinValidation.validLegalEntity() =>
      const BinValidation._(isValid: true, type: BinType.legalEntity);

  factory BinValidation.invalid(String error) =>
      BinValidation._(isValid: false, error: error);
}

enum BinType { individual, legalEntity }
