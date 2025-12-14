# 🔐 Archivos de Configuración de Entorno

Este directorio contiene archivos `.env` con variables de entorno sensibles necesarias para ejecutar el proyecto.

## 📁 Archivos

- **`.env`** - Archivo de configuración actual (NO se sube a Git)
- **`.env.example`** - Plantilla de ejemplo con placeholders

## ⚙️ Configuración del Backend

### Variables Requeridas:

1. **OPENAI_API_KEY** (Obligatorio)
   - Obtén tu clave en: https://platform.openai.com/api-keys
   - Ejemplo: `sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

2. **SECRET_KEY** (Obligatorio)
   - Genera una clave aleatoria segura
   - Comando: `openssl rand -hex 32`
   - Esta clave se usa para firmar tokens JWT

3. **GOOGLE_CLIENT_ID** (Requerido para Google Sign-In)
   - Obtén desde: Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration
   - Ejemplo: `123456789012-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com`

4. **SQLALCHEMY_DATABASE_URL** (Opcional)
   - Por defecto usa SQLite local (`mealia.db`)
   - Para PostgreSQL: `postgresql://usuario:contraseña@localhost:5432/meal_ia_db`

## 🚀 Inicio Rápido

1. Copia el archivo de ejemplo:
   ```bash
   cp .env.example .env
   ```

2. Edita `.env` y reemplaza los valores de ejemplo con tus credenciales reales

3. **IMPORTANTE:** Nunca compartas tu archivo `.env` ni lo subas a Git

## 🔍 Verificación

Para verificar que tu configuración es correcta:

```bash
# El entorno virtual (.venv) se activa automáticamente en VS Code
# Si necesitas activarlo manualmente:
.\.venv\Scripts\activate  # Windows (desde la raíz del proyecto)
source .venv/bin/activate  # Mac/Linux (desde la raíz del proyecto)

# Navega al backend e inicia el servidor
cd backend
uvicorn main:app --reload
```

Si ves errores sobre variables faltantes, revisa que todas las variables requeridas estén en tu `.env`.

## 🛡️ Seguridad

- ✅ El archivo `.env` está en `.gitignore`
- ✅ Usa claves únicas y seguras para cada entorno
- ✅ Rota tus claves periódicamente
- ❌ Nunca compartas tus claves en chat, email o repositorios públicos
