import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class ApiConfig {
  // CONFIGURACIÓN DE ENTORNO
  // Cambia esta variable para alternar entre desarrollo y producción
  static const bool isDevelopment = true; // true para desarrollo local

  // Set to true if testing on a physical Android device connected to local network
  static const bool usePhysicalDevice = true;

  // IPs de Desarrollo
  static const String localIP =
      "http://127.0.0.1:8000"; // Preferible para Chrome/Windows
  static const String androidEmulatorIP =
      "http://10.0.2.2:8000"; // Para emulador Android
  static const String physicalDeviceIP =
      "http://192.168.1.42:8000"; // Tu IP local para dispositivo físico

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

  // Información de debug
  static String get environmentInfo {
    if (!isDevelopment) return 'Production ($productionURL)';
    return 'Development ($baseUrl)';
  }
}
