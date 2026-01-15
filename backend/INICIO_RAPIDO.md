# 🚀 Inicio Rápido - Backend Meal.IA

## ⚡ Inicio Automático (Recomendado)

**Windows:**
```bash
cd backend
run_backend.bat
```

Este script:
- ✅ Activa automáticamente el entorno virtual
- ✅ Verifica e instala dependencias si es necesario
- ✅ Inicia el servidor en `0.0.0.0:8000` (accesible desde la red)

---

## 📋 Inicio Manual

Si prefieres hacerlo manualmente:

### 1. Activar el entorno virtual

**Windows:**
```bash
cd backend
venv\Scripts\activate
```

**Mac/Linux:**
```bash
cd backend
source venv/bin/activate
```

### 2. Instalar dependencias (solo la primera vez)

```bash
pip install -r requirements.txt
```

### 3. Iniciar el servidor

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Importante:** El flag `--host 0.0.0.0` permite que otros dispositivos en tu red se conecten al backend.

---

## ✅ Verificación

Una vez iniciado, deberías ver:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

**Prueba en tu navegador:**
- http://localhost:8000/health
- Deberías ver: `{"status":"ok","message":"Backend is running","version":"1.0.0"}`

**Prueba desde tu dispositivo móvil:**
- http://TU_IP:8000/health
- (Reemplaza TU_IP con la IP de tu PC, ej: `192.168.1.68`)

---

## 🔧 Solución de Problemas

### Error: "uvicorn no se reconoce como comando"

**Causa:** El entorno virtual no está activado.

**Solución:**
1. Usa el script `run_backend.bat` (recomendado)
2. O activa manualmente el entorno virtual antes de ejecutar uvicorn

### Error: "No module named 'uvicorn'"

**Causa:** Las dependencias no están instaladas.

**Solución:**
```bash
pip install -r requirements.txt
```

### Error: "Address already in use"

**Causa:** El puerto 8000 ya está en uso.

**Solución:**
1. Cierra la otra aplicación que usa el puerto 8000
2. O cambia el puerto: `uvicorn main:app --host 0.0.0.0 --port 8001 --reload`

### El servidor inicia pero no puedo conectarme desde el dispositivo

**Verifica:**
1. ✅ El servidor está corriendo con `--host 0.0.0.0` (no solo `127.0.0.1`)
2. ✅ Tu PC y dispositivo están en la misma red WiFi
3. ✅ El firewall de Windows permite conexiones en el puerto 8000
4. ✅ La IP en `api_config.dart` es correcta

---

## 📝 Variables de Entorno

Asegúrate de tener un archivo `.env` en la carpeta `backend/` con:

```env
SECRET_KEY=tu-secret-key-aqui
OPENAI_API_KEY=tu-openai-api-key
GOOGLE_WEB_CLIENT_ID=tu-google-client-id
GOOGLE_ANDROID_CLIENT_ID=tu-google-android-client-id
```

**Nota:** El archivo `.env` no se sube a Git por seguridad.

---

## 🛑 Detener el Servidor

Presiona `Ctrl+C` en la terminal donde está corriendo el servidor.
