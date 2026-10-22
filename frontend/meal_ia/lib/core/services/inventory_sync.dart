import 'dart:convert';
import 'package:http/http.dart' as http;

/// Restore cached items only when they are absent on the server.
/// POST adds quantities, so existing items must never be replayed on login.
Future<void> restoreMissingInventory({
  required http.Client client,
  required String baseUrl,
  required String token,
  required Map<String, Map<String, dynamic>> inventory,
}) async {
  if (inventory.isEmpty) return;
  final headers = {'Authorization': 'Bearer $token'};
  final response = await client.get(Uri.parse('$baseUrl/inventory'), headers: headers)
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) return;
  final remote = jsonDecode(utf8.decode(response.bodyBytes)) as List;
  final existing = remote.map((item) => (item['name'] as String).trim().toLowerCase()).toSet();
  for (final entry in inventory.entries) {
    final name = entry.key.trim().toLowerCase();
    if (existing.contains(name)) continue;
    final saved = await client.post(Uri.parse('$baseUrl/inventory'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, ...entry.value}),
    ).timeout(const Duration(seconds: 20));
    if (saved.statusCode != 200) {
      throw StateError('No se pudo restaurar el inventario (${saved.statusCode})');
    }
    existing.add(name);
  }
}
