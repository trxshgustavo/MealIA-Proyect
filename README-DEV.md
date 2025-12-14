# MEAL.IA - Guía de Desarrollo Interno

Este documento describe cómo configurar y ejecutar el proyecto MEAL.IA en un entorno de desarrollo local.

## 1. Prerrequisitos

Asegúrate de tener instalado lo siguiente:
* [Git](https://git-scm.com/)
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (para el frontend)
* [Python 3.9+](https://www.python.org/downloads/) (para el backend)
* [PostgreSQL](https://www.postgresql.org/download/) (OPCIONAL - por defecto usa SQLite)
* Un editor de código (ej: VS Code)
* Una cuenta de [Firebase](https://firebase.google.com/) (para autenticación)
* Una API Key de [OpenAI](https://platform.openai.com/) (para funcionalidad de IA)

## 2. Configuración Inicial

1.  **Clonar el repositorio** (si es necesario):
    ```bash
    git clone [URL-DE-TU-REPO-GIT]
    cd MealIA-Proyect_fork
    ```

2.  **Configurar Firebase**:
    * Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
    * Habilita **Authentication** con Email/Password y Google Sign-In
    * Descarga los archivos de configuración:
      - `google-services.json` → coloca en `frontend/meal_ia/android/app/`
      - `GoogleService-Info.plist` → coloca en `frontend/meal_ia/ios/Runner/`
    * Configura la aplicación Flutter ejecutando (opcional si ya tienes los archivos):
      ```bash
      flutterfire configure
      ```

3.  **Obtener API Key de OpenAI**:
    * Visita [OpenAI Platform](https://platform.openai.com/api-keys)
    * Crea una nueva API Key
    * Guarda la clave para usarla en el siguiente paso

4.  **Crear la Base de Datos (OPCIONAL - SQLite por defecto)**:
    * Si quieres usar PostgreSQL en lugar de SQLite:
      - Abre `pgAdmin` o tu cliente de PostgreSQL
      - Crea una nueva base de datos llamada `meal_ia_db`
      - (Opcional) Ejecuta el script `database/init_db.sql` para crear las tablas
    * Por defecto, el proyecto usa SQLite (`mealia.db`), que se crea automáticamente

## 3. Ejecutar el Backend (FastAPI)

1.  **Navega a la carpeta backend**:
    ```bash
    cd backend
    ```

2.  **Crear entorno virtual (solo primera vez)**:
    
    El proyecto usa `.venv` en la raíz del workspace. Si no existe, créalo así:
    
    ```bash
    # Desde la raíz del proyecto (MealIA-Proyect_fork/)
    python -m venv .venv
    ```
    
    **Auto-activación en VS Code:**
    - VS Code activará automáticamente `.venv` al abrir nuevas terminales
    - Si no se activa, abre Command Palette (Ctrl+Shift+P) → "Python: Select Interpreter" → elige `.venv`
    
    **Activación manual (si es necesario):**
    ```bash
    # Windows (PowerShell/CMD)
    .\.venv\Scripts\activate
    # Mac/Linux/Git Bash
    source .venv/bin/activate
    ```

3.  **Instala las dependencias**:
    ```bash
    # Instalar desde el archivo requirements.txt del directorio raíz
    pip install -r requirements.txt
    ```
    
    **Dependencias principales incluidas:**
    - FastAPI y Uvicorn (servidor web)
    - SQLAlchemy (ORM para base de datos)
    - OpenAI (integración con ChatGPT)
    - python-dotenv (variables de entorno)
    - python-jose, passlib, bcrypt (autenticación JWT)
    - google-auth (autenticación de Google)
    - psycopg2-binary (conector PostgreSQL, opcional)

4.  **Crea tu archivo `.env`** en la carpeta `backend/`:
    ```bash
    # backend/.env
    
    # Base de datos (opcional - usa SQLite por defecto si no se especifica)
    # Para SQLite (por defecto): no especificar o dejar comentado
    # Para PostgreSQL: descomentar y configurar:
    # SQLALCHEMY_DATABASE_URL="postgresql://tu_usuario:tu_contraseña@localhost:5432/meal_ia_db"
    
    # OpenAI API Key (REQUERIDO)
    OPENAI_API_KEY="tu-openai-api-key-aqui"
    
    # JWT Secret (puedes generar uno aleatorio)
    SECRET_KEY="tu-secreto-jwt-super-seguro-cambiar-esto"
    
    # Google OAuth (para Google Sign-In)
    GOOGLE_CLIENT_ID="tu-google-client-id.apps.googleusercontent.com"
    ```
    
    **IMPORTANTE:** 
    - Nunca subas el archivo `.env` a Git (ya está en `.gitignore`)
    - Cambia `SECRET_KEY` por un valor aleatorio seguro
    - Obtén `GOOGLE_CLIENT_ID` desde Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration

5.  **Inicia el servidor**:
    ```bash
    uvicorn main:app --reload
    ```
    El backend estará corriendo en `http://127.0.0.1:8000`
    
    **Documentación API:** Accede a `http://127.0.0.1:8000/docs` para ver la documentación interactiva de la API

## 4. Ejecutar el Frontend (Flutter)

1.  **Navega a la carpeta del frontend**:
    ```bash
    # Desde la raíz del proyecto
    cd frontend/meal_ia
    ```

2.  **Crea el archivo `.env`** en `frontend/meal_ia/`:
    ```bash
    # frontend/meal_ia/.env
    
    # Firebase Configuration - Obtén estos valores de Firebase Console
    # Web
    WEB_API_KEY=tu-web-api-key
    WEB_APP_ID=tu-web-app-id
    
    # Android
    ANDROID_API_KEY=tu-android-api-key
    ANDROID_APP_ID=tu-android-app-id
    ANDROID_CLIENT_ID=tu-android-client-id
    
    # iOS
    IOS_API_KEY=tu-ios-api-key
    IOS_APP_ID=tu-ios-app-id
    IOS_CLIENT_ID=tu-ios-client-id
    IOS_BUNDLE_ID=com.example.mealIa
    
    # macOS
    MACOS_API_KEY=tu-macos-api-key
    MACOS_APP_ID=tu-macos-app-id
    MACOS_BUNDLE_ID=com.example.mealIa
    
    # Windows
    WINDOWS_API_KEY=tu-windows-api-key
    WINDOWS_APP_ID=tu-windows-app-id
    
    # Compartido
    PROJECT_ID=tu-project-id
    MESSAGING_SENDER_ID=tu-sender-id
    STORAGE_BUCKET=tu-bucket.appspot.com
    AUTH_DOMAIN=tu-project.firebaseapp.com
    ```
    
    **Cómo obtener estos valores:**
    - Ve a Firebase Console → Configuración del proyecto → Tus aplicaciones
    - Para cada plataforma (Web, Android, iOS), copia los valores correspondientes
    - O revisa los archivos `google-services.json` y `GoogleService-Info.plist`

3.  **Obtén las dependencias de Flutter**:
    ```bash
    flutter pub get
    ```

4.  **Configurar URL del Backend** (solo para desarrollo local):
    * Edita `lib/core/config/api_config.dart`
    * Descomenta la línea de desarrollo y comenta la de producción:
    ```dart
    static const String baseUrl = "http://10.0.2.2:8000"; // Para emulador Android
    // static const String baseUrl = "http://127.0.0.1:8000"; // Para iOS/Desktop
    // static const String baseUrl = "https://mealia-proyect-1.onrender.com"; // Production
    ```
    **Notas:**
    - `10.0.2.2` es el localhost para emuladores Android
    - `127.0.0.1` para emuladores iOS o web
    - Para dispositivos físicos, usa la IP de tu computadora en la red local

5.  **Ejecuta la aplicación**:
    * Asegúrate de tener un emulador corriendo o un dispositivo conectado.
    ```bash
    flutter run
    ```

## 5. Solución de Problemas Comunes

### Backend no arranca
- Verifica que el entorno virtual esté activado (`venv` en el prompt)
- Revisa que las variables de entorno en `.env` estén correctamente configuradas
- Confirma que `OPENAI_API_KEY` sea válida

### Frontend no se conecta al backend
- Verifica que el backend esté corriendo en `http://127.0.0.1:8000`
- Revisa la URL en `api_config.dart` según tu plataforma
- Para dispositivos físicos, usa la IP de tu computadora (no localhost)

### Error de Firebase
- Confirma que `google-services.json` (Android) y `GoogleService-Info.plist` (iOS) estén en las carpetas correctas
- Verifica que el archivo `.env` del frontend tenga todas las variables de Firebase
- Ejecuta `flutter clean` y luego `flutter pub get`

### Error de Google Sign-In
- Asegúrate de tener configurado el SHA-1/SHA-256 en Firebase Console (para Android)
- Verifica que `GOOGLE_CLIENT_ID` en backend/.env coincida con el Web Client ID de Firebase

## 6. Estructura del Proyecto

```
MealIA-Proyect_fork/
├── backend/              # API FastAPI
│   ├── main.py          # Punto de entrada
│   ├── models.py        # Modelos de base de datos
│   ├── schemas.py       # Esquemas Pydantic
│   ├── security.py      # Autenticación JWT
│   └── .env            # Variables de entorno (NO subir a Git)
├── frontend/meal_ia/    # Aplicación Flutter
│   ├── lib/
│   │   ├── main.dart   # Punto de entrada
│   │   ├── firebase_options.dart  # Config Firebase
│   │   └── core/config/api_config.dart  # URL del backend
│   └── .env            # Variables Firebase (NO subir a Git)
└── database/
    └── init_db.sql      # Script inicial de BD (opcional)
```

## 7. Próximos Pasos

Una vez que tengas todo funcionando:
1. Explora la API en `http://127.0.0.1:8000/docs`
2. Prueba el registro e inicio de sesión en la app
3. Revisa los logs del backend para depurar problemas
4. Consulta la documentación de [FastAPI](https://fastapi.tiangolo.com/) y [Flutter](https://flutter.dev/docs)