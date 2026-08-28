import 'package:telepos/domain/usecases/agent/agent_validation_service.dart';

class AgentValidationServiceImpl implements AgentValidationService {
  static final _binRegex = RegExp(r'^\d{12}$');

  static const _legalEntityDigits = {'4', '5', '6'};

  @override
  BinValidation validateBin(String bin) {
    final cleanBin = bin.replaceAll(' ', '');

    if (!_binRegex.hasMatch(cleanBin)) {
      return BinValidation.invalid('БИН/ИИН должен содержать ровно 12 цифр');
    }

    if (isLegalEntity(cleanBin)) {
      return BinValidation.validLegalEntity();
    }

    if (isIndividual(cleanBin)) {
      final birthDate = _parseBirthDate(cleanBin);
      return BinValidation.validIndividual(birthDate: birthDate);
    }

    return BinValidation.validIndividual();
  }

  @override
  bool isIndividual(String bin) {
    if (bin.length != 12) return false;

    final fifthDigit = bin[4];
    return !_legalEntityDigits.contains(fifthDigit);
  }

  @override
  bool isLegalEntity(String bin) {
    if (bin.length != 12) return false;

    final fifthDigit = bin[4];
    return _legalEntityDigits.contains(fifthDigit);
  }

  @override
  bool validatePhone(int phone) {
    final phoneStr = phone.toString();

    if (phoneStr.length < 10 || phoneStr.length > 15) {
      return false;
    }

    if (phoneStr.startsWith('7') && phoneStr.length == 11) {
      return true;
    }

    if (phoneStr.startsWith('996') && phoneStr.length == 12) {
      return true;
    }

    if (phoneStr.startsWith('998') && phoneStr.length == 12) {
      return true;
    }

    if (phoneStr.startsWith('993') && phoneStr.length == 11) {
      return true;
    }

    return phoneStr.length >= 10;
  }

  DateTime? _parseBirthDate(String bin) {
    if (bin.length < 6) return null;

    try {
      final yy = int.parse(bin.substring(0, 2));
      final mm = int.parse(bin.substring(2, 4));
      final dd = int.parse(bin.substring(4, 6));

      if (mm < 1 || mm > 12) return null;
      if (dd < 1 || dd > 31) return null;

      int century = 1900;
      if (bin.length >= 7) {
        final centuryDigit = int.parse(bin[6]);
        if (centuryDigit == 3 || centuryDigit == 4) {
          century = 2000;
        } else if (centuryDigit == 5 || centuryDigit == 6) {
          century = 2100;
        }
      } else {
        final currentYear = DateTime.now().year;
        if (yy > (currentYear % 100)) {
          century = 1900;
        } else {
          century = 2000;
        }
      }

      final year = century + yy;
      return DateTime(year, mm, dd);
    } catch (_) {
      return null;
    }
  }
}
