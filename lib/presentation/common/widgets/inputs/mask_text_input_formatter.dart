import 'package:flutter/services.dart';

/// Форматирование ввода по маске вида `+7 (###) ###-##-##`.
///
/// Вынесено из виджета MaskField, который навязывал полю собственную рамку с
/// зашитыми цветом и радиусом. В сгруппированном списке рамку задаёт секция, а
/// маска — это поведение ввода, а не оформление, и жить они должны порознь.

class MaskTextInputFormatter extends TextInputFormatter {
  MaskTextInputFormatter({required this.mask});

  final String mask;
  String _unmaskedText = '';

  String getUnmaskedText() => _unmaskedText;

  String _extractUserDigits(String text) {
    final buffer = StringBuffer();
    int textIndex = 0;
    for (int i = 0; i < mask.length && textIndex < text.length; i++) {
      final maskChar = mask[i];
      final textChar = text[textIndex];
      if (maskChar == '#') {
        if (RegExp(r'\d').hasMatch(textChar)) {
          buffer.write(textChar);
        }
        textIndex++;
      } else {
        if (textChar == maskChar) {
          textIndex++;
        }
      }
    }
    while (textIndex < text.length) {
      final ch = text[textIndex];
      if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
      textIndex++;
    }
    return buffer.toString();
  }

  String _applyMask(String userDigits) {
    final buffer = StringBuffer();
    int digitIndex = 0;

    for (int i = 0; i < mask.length && digitIndex < userDigits.length; i++) {
      final maskChar = mask[i];
      if (maskChar == '#') {
        buffer.write(userDigits[digitIndex]);
        digitIndex++;
      } else {
        buffer.write(maskChar);
      }
    }

    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      _unmaskedText = '';
      return newValue;
    }

    final maxUserDigits = '#'.allMatches(mask).length;
    final oldUserDigits = _extractUserDigits(oldValue.text);
    final isDeleting = newValue.text.length < oldValue.text.length;

    String userDigits;
    if (isDeleting) {
      userDigits = oldUserDigits.isNotEmpty
          ? oldUserDigits.substring(0, oldUserDigits.length - 1)
          : '';
    } else {
      final newAllDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
      final oldAllDigits = oldValue.text.replaceAll(RegExp(r'[^\d]'), '');

      final addedCount = newAllDigits.length - oldAllDigits.length;
      if (addedCount > 0) {
        final added = newAllDigits.substring(newAllDigits.length - addedCount);
        userDigits = oldUserDigits + added;
      } else {
        userDigits = oldUserDigits;
      }

      if (userDigits.length > maxUserDigits) {
        userDigits = userDigits.substring(0, maxUserDigits);
      }
    }

    _unmaskedText = userDigits;
    final maskedText = _applyMask(userDigits);

    return TextEditingValue(
      text: maskedText,
      selection: TextSelection.collapsed(offset: maskedText.length),
    );
  }
}

class InputMasks {
  InputMasks._();

  static const phoneKZ = '+7 (###) ###-##-##';

  static const phoneRU = '+7 (###) ###-##-##';

  static const phoneKG = '+996 (###) ###-###';

  static const phoneUZ = '+998 (##) ###-##-##';

  static const binKZ = '### ### ### ###';

  static const innRU10 = '## ## ### ###';
  static const innRU12 = '## ## ### ### ##';

  static const date = '##.##.####';

  static const time = '##:##';

  static const cardNumber = '#### #### #### ####';
}
