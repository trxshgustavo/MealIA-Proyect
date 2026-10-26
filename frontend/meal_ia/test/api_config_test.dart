import 'package:flutter_test/flutter_test.dart';
import 'package:meal_ia/core/config/api_config.dart';

void main() {
  group('ApiConfig tests', () {
    test('productionURL is configured properly', () {
      expect(ApiConfig.productionURL, isNotEmpty);
      expect(ApiConfig.productionURL.startsWith('http'), isTrue);
    });

    test('baseUrl returns a valid URL string', () {
      final url = ApiConfig.baseUrl;
      expect(url, isNotEmpty);
      expect(url.startsWith('http'), isTrue);
    });
  });
}
