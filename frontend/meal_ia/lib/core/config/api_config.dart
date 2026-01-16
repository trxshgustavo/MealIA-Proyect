import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

class ApiConfig {
  // CONFIGURACIÓN DE ENTORNO
  // Cambia esta variable para alternar entre desarrollo y producción
  static const bool isDevelopment = false; // false para produccion (Render)

  // Set to true if testing on a physical Android device connected to local network
  static const bool usePhysicalDevice = true;

  // IPs de Desarrollo
  static const String localIP =
      "http://127.0.0.1:8000"; // Preferible para Chrome en el mismo PC
  static const String androidEmulatorIP =
      "http://10.0.2.2:8000"; // Para emulador Android
  // Si usas dispositivo físico, cambia esta IP a la de tu PC (ej: 192.168.1.x)
  static const String physicalDeviceIP = "http://192.168.1.68:8000";

  // URL de Producción
  static const String productionURL = "https://mealia-proyect-1.onrender.com";

  // URL activa (se selecciona automáticamente)
  static String get baseUrl {
    if (!isDevelopment) return productionURL;

    // Selección automática por plataforma en desarrollo
    if (kIsWeb) {
      return localIP;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (usePhysicalDevice) {
          return physicalDeviceIP;
        }
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
