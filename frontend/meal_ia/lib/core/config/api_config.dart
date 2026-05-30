import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // CONFIGURACIÓN DE ENTORNO
  // Cambia esta variable para alternar entre desarrollo y producción
  static const bool isDevelopment = false;

  // IPs de Desarrollo por defecto
  static const String androidEmulatorIP = 'http://10.0.2.2:8000';
  static const String localIP = 'http://127.0.0.1:8000'; 

  // URL de Producción
  static const String productionURL = "https://mealia-proyect-1.onrender.com";

  // URL activa (se selecciona automáticamente)
  static String get baseUrl {
    if (!isDevelopment) return productionURL;

    // Si el usuario configuró una IP en el .env, usarla primero
    final envUrl = dotenv.env['BACKEND_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // Selección automática por plataforma en desarrollo
    if (kIsWeb) {
      return localIP;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // En Android, asume emulador a menos que BACKEND_URL este en el .env
        return androidEmulatorIP;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return localIP;
      default:
        return localIP;
    }
  }

  // Método para verificar si el backend está disponible
  static Future<bool> checkBackendConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Información de debug
  static String get environmentInfo {
    if (!isDevelopment) return 'Production ($productionURL)';
    return 'Development ($baseUrl)';
  }
}
