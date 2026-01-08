import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class ApiConfig {
<<<<<<< HEAD
  // Use '10.0.2.2' for Android Emulator, specific IP for physical devices, or your deployed URL
  // static const String baseUrl = "http://10.0.2.2:8000"; // Android Emulator

  // Choose one based on your environment:
  // static const String baseUrl = "http://10.0.2.2:8000";
  static const String baseUrl =
      "http://192.168.1.42:8000"; // Local IP (Physical Device & Emulator usually)
=======
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
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
}
