# Verificación y publicación de MealIA

## Correcciones

- La recuperación de inventario ya no vuelve a sumar cantidades existentes al iniciar sesión.
- Unidades compatibles se convierten antes de sumar; unidades incompatibles se rechazan.
- Categorías y datos nutricionales sobreviven a la recarga del inventario.
- Una sesión rechazada por el backend no abre la pantalla principal.
- El acceso por contraseña no mezcla una cuenta del backend con otra sesión de Firebase.
- Tokens de Google deben pertenecer a un cliente OAuth configurado y tener correo verificado.
- Los menús semanales se reemplazan en una transacción: una respuesta incompleta de IA no borra los planes guardados. Los planes fuera de esos siete días se conservan.
- Escáneres permiten cargar una imagen y muestran errores si la cámara no está disponible.
- Imágenes de comidas extra se envían como bytes, compatibles con navegadores.
- Solo configuración pública permitida se empaqueta en la app; las claves de IA permanecen en el servidor.
- Suscripciones deshabilitadas hasta implementar la verificación de recibos en el servidor. No se concede Premium desde una petición del cliente.

## Backend

Desde la raíz, en un entorno virtual:

```sh
pip install -r requirements.txt
pip install pytest
python -m pytest -q backend/tests
```

Las pruebas usan una base de datos temporal en memoria, cuentas ficticias y respuestas de IA simuladas. No modifican cuentas ni datos de producción.

Copiar `backend/.env.example` a `backend/.env`, configurar SECRET_KEY y las integraciones necesarias. Las contraseñas requieren ocho caracteres, una mayúscula y un número. Los identificadores OAuth públicos del proyecto actual tienen valores por defecto. Para usar otra configuración, definir `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_ANDROID_CLIENT_ID` e `GOOGLE_IOS_CLIENT_ID` según las plataformas usadas. El alias anterior `GOOGLE_CLIENT_ID` sigue siendo válido para web.

## App y compilación web

Flutter 3.44.0 / Dart 3.12.0:

```sh
cd frontend/meal_ia
flutter pub get
flutter analyze
flutter test
bash tool/build_web.sh
```

El script instala la versión de Flutter fijada si no hay SDK, prepara la configuración pública y genera `build/web`. Para desarrollo nativo, completar los campos públicos de la plataforma en `.env` y ejecutar `python3 tool/prepare_client_env.py` antes de compilar. Nunca poner claves privadas en assets.

En Render, el servicio web estático existente usa:

- Root Directory: `frontend/meal_ia`
- Build Command: `bash tool/build_web.sh`
- Publish Directory: `build/web`

Cualquier dominio nuevo debe agregarse a `CORS_ORIGINS` del backend y a Firebase Authentication si se usará Google Sign-In.

## Pendiente de verificación externa

- Confirmar configuración de clientes OAuth y App Check de cada plataforma.
- Probar cámara, permisos, selección de fotos y teclado en un iPhone físico.
- Verificar la base persistente y el respaldo antes de redesplegar el backend. SQLite en el almacenamiento efímero de Render no garantiza conservar datos entre despliegues.
- Configurar cuentas de tiendas y verificación de compras antes de habilitar pagos.
