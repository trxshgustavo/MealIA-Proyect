import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meal_ia/core/services/inventory_sync.dart';
import 'package:meal_ia/core/validation/input_validation.dart';
import 'package:meal_ia/ui/screens/main/food_scanner_screen.dart';

void main() {
  test('password rules match the backend before a request is sent', () {
    expect(passwordValidationError('short'), isNotNull);
    expect(passwordValidationError('alllowercase1'), isNotNull);
    expect(passwordValidationError('NoNumbersHere'), isNotNull);
    expect(passwordValidationError('ValidPassword123'), isNull);
  });
  test('API validation details are shown without a runtime type error', () {
    expect(apiErrorMessage([{'msg': 'Invalid password'}], 'Error'), 'Invalid password');
    expect(apiErrorMessage(null, 'Error'), 'Error');
  });
  test('logging in never adds stock already stored on the backend', () async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('[{"name":"arroz","quantity":500,"unit":"g"}]', 200);
      posts++;
      return http.Response('{}', 200);
    });
    await restoreMissingInventory(client: client, baseUrl: 'https://example.com', token: 'test',
      inventory: {'arroz': {'quantity': 500, 'unit': 'g'}});
    expect(posts, 0);
  });

  test('restoring cached items is idempotent across repeated logins', () async {
    final remote = <Map<String, dynamic>>[];
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response(jsonEncode(remote), 200);
      posts++;
      remote.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(request.body, 200);
    });
    for (var n = 0; n < 2; n++) {
      await restoreMissingInventory(client: client, baseUrl: 'https://example.com', token: 'test',
        inventory: {'arroz': {'quantity': 500, 'unit': 'g', 'category': 'Cereales'}});
    }
    expect(posts, 1);
    expect(remote.single['quantity'], 500);
    expect(remote.single['category'], 'Cereales');
  });

  test('a failed inventory read never causes blind stock additions', () async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.method != 'GET') posts++;
      return http.Response('{}', 503);
    });
    await restoreMissingInventory(client: client, baseUrl: 'https://example.com', token: 'test',
      inventory: {'arroz': {'quantity': 500, 'unit': 'g'}});
    expect(posts, 0);
  });

  test('scanner accepts decimal strings and normalizes kg labels', () {
    final food = ScannedFood.fromJson({'alimento': 'Arroz', 'cantidad_estimada': '0.5',
      'unidad_estimada': 'kg', 'calorias': '130', 'proteinas': '2.5'});
    expect(food.quantity, 0.5);
    expect(food.unit, 'Kg');
    expect(food.exactCalories, 130);
    expect(food.exactProteins, 2.5);
  });
}
