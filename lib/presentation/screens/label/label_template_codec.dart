import 'dart:convert';

import 'package:telepos/hardware/label_printer/label_printer_service.dart';

class LabelTemplateCodec {
  const LabelTemplateCodec._();

  static List<LabelField> decode(String fieldsJson) {
    try {
      final raw = jsonDecode(fieldsJson);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => LabelField.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encode(List<LabelField> fields) =>
      jsonEncode(fields.map((f) => f.toJson()).toList());
}
