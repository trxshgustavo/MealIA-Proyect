import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class ApiConfig {
  // CONFIGURACIÓN DE ENTORNO
  // Cambia esta variable para alternar entre desarrollo y producción
  static const bool isDevelopment = true; // true para desarrollo local

  // IPs de Desarrollo
  static const String localIP = "http://127.0.0.1:8000"; // Preferible para Chrome en el mismo PC
  static const String androidEmulatorIP = "http://10.0.2.2:8000"; // Para emulador Android

  // URL de Producción
  static const String productionURL = "https://mealia-proyect-1.onrender.com";

  // URL activa (se selecciona automáticamente)
  static String get baseUrl {
    if (!isDevelopment) return productionURL;

    // Selección automática por plataforma en desarrollo
    if (kIsWeb) {
      // Para Flutter Web normalmente apunta a la IP local
      return localIP;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Emulador Android usa 10.0.2.2 para llegar al host
        return androidEmulatorIP;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // En desktop/iOS es común usar IP local
        return localIP;
      default:
        return localIP;
    }
  }

  // Información de debug
  static String get environmentInfo {
    if (!isDevelopment) return 'Production ($productionURL)';
    return 'Development (${baseUrl})';
  }
}
