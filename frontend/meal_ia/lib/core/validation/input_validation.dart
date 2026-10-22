String? passwordValidationError(String? value) {
  if (value == null || value.length < 8 ||
      !RegExp(r'[A-Z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Usa al menos 8 caracteres, una mayúscula y un número';
  }
  return null;
}

String apiErrorMessage(dynamic detail, String fallback) {
  if (detail is String && detail.isNotEmpty) return detail;
  if (detail is List) {
    final messages = detail.whereType<Map>().map((item) => item['msg'])
        .whereType<String>().toList();
    if (messages.isNotEmpty) return messages.join('\n');
  }
  return fallback;
}
