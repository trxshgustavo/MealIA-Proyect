# Preparación de MealIA para iPhone (pendiente de validar con compilación)

## Requisitos
- Flutter con Dart compatible con el SDK declarado en `pubspec.yaml`.
- macOS + Xcode + CocoaPods para compilar y firmar localmente para iOS, o un servicio de compilación macOS confiable.
- Cuenta de desarrollador y configuración de firma apropiadas para el método de distribución elegido.
- Firebase configurado para la app iOS y su identificador de bundle.

## Configuración local (no subir credenciales)
1. En `frontend/meal_ia`, copia `.env.example` a `.env`.
2. Rellena los identificadores y opciones **de cliente** de Firebase (especialmente `IOS_API_KEY`, `IOS_APP_ID`, `MESSAGING_SENDER_ID`, `PROJECT_ID`, `STORAGE_BUCKET`, `IOS_CLIENT_ID` y `IOS_BUNDLE_ID`).
3. Comprueba que el bundle ID coincide con la app iOS registrada en Firebase.
4. Si las integraciones nativas requieren `GoogleService-Info.plist`, genera/descarga el archivo correspondiente desde el proyecto Firebase y colócalo localmente en `ios/Runner/` (está ignorado por Git).
5. **No** incluyas claves secretas de OpenAI/Gemini, Stripe secret, tokens de servidor ni credenciales de cuentas de servicio en archivos empaquetados como assets de Flutter. Mueve esas operaciones a un backend protegido.
6. Nunca subas el archivo `.env` real al repositorio.

## Verificación antes de publicar
```bash
cd frontend/meal_ia
cp .env.example .env # editar con los valores correctos antes de seguir
flutter pub get       # regenera pubspec.lock tras cambios de dependencias
flutter analyze
flutter test
flutter build ios --no-codesign
```

La compilación iOS debe ejecutarse en macOS; para una distribución instalable posteriormente se necesita la configuración de firma y provisión de Apple. `--no-codesign` no entrega una IPA instalable.

## Pruebas funcionales en iPhone
- Inicio con y sin conexión, sesión expirada y reintento de autenticación.
- Login y registro con Firebase; Google Sign-In y App Check reales.
- Acceso al backend `/health` y flujos de generación de menús.
- Cámara, biblioteca de fotos y permisos iOS.
- Recordatorio de racha a las 22:00 en la zona horaria del dispositivo.
- Revisión de fallos y cierre inesperado en dispositivo físico.

## Estado
Estas son instrucciones para validar los cambios propuestos. No equivalen a una compilación o prueba de dispositivo ya realizada.
