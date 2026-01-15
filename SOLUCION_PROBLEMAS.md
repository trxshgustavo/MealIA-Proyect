# 🔧 Solución de Problemas - Meal.IA

## Problemas Identificados y Soluciones

### 1. ⚠️ Firebase App Check Error (403)

**Problema:**
```
I/flutter: ! APP CHECK ERROR: [firebase_app_check/unknown] com.google.firebase.FirebaseException: Error returned from API. code: 403 body: App attestation failed.
```

**Solución:**

El token de debug que aparece en los logs necesita ser registrado en Firebase Console:

**Token de Debug:** `2d288de4-9352-4b8b-ba12-9800a334d0dc`

**Pasos para solucionarlo:**

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **App Check** en el menú lateral
4. Selecciona tu app Android
5. En la sección **Debug tokens**, haz clic en **Agregar token de depuración**
6. Pega el token: `2d288de4-9352-4b8b-ba12-9800a334d0dc`
7. Guarda los cambios

**Nota:** La app ahora maneja este error de forma no bloqueante, así que funcionará aunque App Check falle. Sin embargo, es recomendable registrar el token para habilitar todas las funciones de Firebase.

---

### 2. 🌐 Error de Conexión al Backend (Connection Timeout)

**Problema:**
```
I/flutter: Error de conexión en Google Sign-In: ClientException with SocketException: Connection timed out (OS Error: Connection timed out, errno = 110), address = 192.168.1.68, port = 52502, uri=http://192.168.1.68:8000/auth/google
```

**Causas posibles:**

1. **El backend no está corriendo**
2. **La IP del backend cambió**
3. **Problema de firewall**
4. **Dispositivo y PC no están en la misma red WiFi**

**Soluciones:**

#### A. Verificar que el backend esté corriendo

1. Abre una terminal en tu PC
2. Navega a la carpeta `backend`:
   ```bash
   cd backend
   ```
3. Inicia el servidor:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0
   ```
   El flag `--host 0.0.0.0` permite conexiones desde otros dispositivos en la red.

4. Verifica que el servidor esté corriendo visitando en tu navegador:
   ```
   http://192.168.1.68:8000/health
   ```
   Deberías ver: `{"status":"ok","message":"Backend is running","version":"1.0.0"}`

#### B. Verificar la IP de tu PC

1. **Windows:**
   ```powershell
   ipconfig
   ```
   Busca "IPv4 Address" en la sección de tu adaptador WiFi/Ethernet.

2. **Actualiza la IP en el código:**
   - Abre: `frontend/meal_ia/lib/core/config/api_config.dart`
   - Cambia `physicalDeviceIP` a tu IP actual:
   ```dart
   static const String physicalDeviceIP = "http://TU_IP_AQUI:8000";
   ```

#### C. Verificar Firewall

1. **Windows:**
   - Abre "Firewall de Windows Defender"
   - Haz clic en "Permitir una aplicación o característica"
   - Busca "Python" y asegúrate de que esté marcado para "Red privada"
   - O crea una regla de entrada para el puerto 8000

2. **Verificar que el puerto 8000 esté abierto:**
   ```powershell
   netstat -an | findstr :8000
   ```

#### D. Verificar que estén en la misma red

- Tu dispositivo Android y tu PC deben estar conectados a la **misma red WiFi**
- No uses datos móviles en el dispositivo mientras pruebas

---

### 3. 📱 Configuración de Red para Desarrollo

**Para desarrollo local, tienes estas opciones:**

#### Opción 1: Usar Emulador Android
- Cambia en `api_config.dart`:
  ```dart
  return androidEmulatorIP; // En lugar de physicalDeviceIP
  ```
- El emulador usa `10.0.2.2` para acceder al host

#### Opción 2: Usar Dispositivo Físico (Recomendado)
- Asegúrate de que la IP en `physicalDeviceIP` sea correcta
- Verifica que el backend esté corriendo con `--host 0.0.0.0`
- Ambos dispositivos en la misma red WiFi

#### Opción 3: Usar Producción
- Cambia `isDevelopment` a `false` en `api_config.dart`
- La app usará: `https://mealia-proyect-1.onrender.com`

---

### 4. ✅ Verificación Rápida

**Checklist antes de probar:**

- [ ] Backend corriendo: `uvicorn main:app --reload --host 0.0.0.0`
- [ ] IP correcta en `api_config.dart`
- [ ] Firewall permite conexiones en puerto 8000
- [ ] Dispositivo y PC en la misma red WiFi
- [ ] Token de Firebase App Check registrado (opcional pero recomendado)

**Test de conexión:**

1. Desde tu PC, abre el navegador y visita:
   ```
   http://TU_IP:8000/health
   ```
2. Deberías ver: `{"status":"ok","message":"Backend is running","version":"1.0.0"}`

3. Si funciona en el navegador pero no en la app, el problema es de red/firewall.

---

### 5. 🐛 Mejoras Implementadas

Se han mejorado los mensajes de error para que sean más informativos:

- **Antes:** "Error de conexión"
- **Ahora:** Mensajes detallados que indican qué verificar (backend corriendo, IP correcta, misma red, etc.)

Los errores de Firebase App Check ahora son no bloqueantes, la app funcionará aunque App Check falle.

---

## 📞 Soporte Adicional

Si después de seguir estos pasos aún tienes problemas:

1. Verifica los logs del backend para ver si recibe las peticiones
2. Verifica los logs de Flutter para ver el error exacto
3. Prueba conectarte desde el navegador del dispositivo a `http://TU_IP:8000/health`
