# 🔥 Firebase Configuration Guide

Este directorio contiene las variables de entorno necesarias para conectar la aplicación Flutter con Firebase.

## 📁 Archivos

- **`.env`** - Archivo de configuración actual (NO se sube a Git)
- **`.env.example`** - Plantilla de ejemplo con placeholders

## 🎯 ¿Dónde obtener estas credenciales?

### Método 1: Firebase Console (Recomendado)

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Haz clic en el ícono de configuración ⚙️ → **Configuración del proyecto**
4. En la sección **Tus aplicaciones**, verás las apps registradas
5. Para cada plataforma, copia los valores correspondientes

### Método 2: Archivos de configuración

#### Android (`google-services.json`)
```json
{
  "project_info": {
    "project_id": "tu-proyecto",                    → PROJECT_ID
    "firebase_url": "https://tu-proyecto.firebaseio.com",
    "project_number": "123456789012",               → MESSAGING_SENDER_ID
    "storage_bucket": "tu-proyecto.appspot.com"     → STORAGE_BUCKET
  },
  "client": [{
    "client_info": {
      "mobilesdk_app_id": "1:123456789012:android:xxx",  → ANDROID_APP_ID
      "android_client_info": {
        "package_name": "com.example.mealIa"
      }
    },
    "oauth_client": [{
      "client_id": "123456789012-xxx.apps.googleusercontent.com",  → ANDROID_CLIENT_ID
    }],
    "api_key": [{
      "current_key": "AIzaSyXXXXXXXXXXXXXXXXXXXX"    → ANDROID_API_KEY
    }]
  }]
}
```

#### iOS (`GoogleService-Info.plist`)
```xml
<key>API_KEY</key>
<string>AIzaSyXXXXXXXXXXXXXXXXXXXX</string>         → IOS_API_KEY

<key>GOOGLE_APP_ID</key>
<string>1:123456789012:ios:xxx</string>             → IOS_APP_ID

<key>CLIENT_ID</key>
<string>123456789012-xxx.apps.googleusercontent.com</string>  → IOS_CLIENT_ID

<key>BUNDLE_ID</key>
<string>com.example.mealIa</string>                 → IOS_BUNDLE_ID
```

## 📋 Variables Requeridas por Plataforma

| Plataforma | Variables Necesarias |
|------------|---------------------|
| **Web** | `WEB_API_KEY`, `WEB_APP_ID` |
| **Android** | `ANDROID_API_KEY`, `ANDROID_APP_ID`, `ANDROID_CLIENT_ID` |
| **iOS** | `IOS_API_KEY`, `IOS_APP_ID`, `IOS_CLIENT_ID`, `IOS_BUNDLE_ID` |
| **macOS** | `MACOS_API_KEY`, `MACOS_APP_ID`, `MACOS_BUNDLE_ID` |
| **Windows** | `WINDOWS_API_KEY`, `WINDOWS_APP_ID` |
| **Compartido** | `PROJECT_ID`, `MESSAGING_SENDER_ID`, `STORAGE_BUCKET`, `AUTH_DOMAIN` |

## 🚀 Inicio Rápido

1. Copia el archivo de ejemplo:
   ```bash
   cp .env.example .env
   ```

2. Edita `.env` y reemplaza los valores

3. Ejecuta:
   ```bash
   flutter pub get
   flutter run
   ```

## 🔍 Verificación

Para verificar que Firebase está configurado correctamente:

```dart
// El archivo firebase_options.dart debería leer las variables sin errores
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## ⚠️ Problemas Comunes

### Error: "Missing environment variables"
- Verifica que el archivo `.env` exista en `frontend/meal_ia/`
- Confirma que no haya espacios extras en las variables
- Asegúrate de que todas las variables requeridas estén definidas

### Error: "Firebase initialization failed"
- Revisa que `google-services.json` esté en `android/app/`
- Revisa que `GoogleService-Info.plist` esté en `ios/Runner/`
- Ejecuta `flutter clean` y luego `flutter pub get`

### Google Sign-In no funciona en Android
- Configura SHA-1 y SHA-256 en Firebase Console
- Obtén los hashes con: `cd android && ./gradlew signingReport`
- Agrega los hashes en Firebase Console → Configuración del proyecto → SHA certificate fingerprints

## 🛡️ Seguridad

- ✅ El archivo `.env` está en `.gitignore`
- ✅ No compartas tus credenciales de Firebase
- ✅ Usa diferentes proyectos Firebase para desarrollo y producción
- ⚠️ Las API keys de Firebase son seguras para el cliente, pero habilita App Check para protección adicional
