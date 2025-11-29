# MEAL.IA - Guía de Desarrollo Interno

Este documento describe cómo configurar y ejecutar el proyecto MEAL.IA en un entorno de desarrollo local.

## 1. Prerrequisitos

Asegúrate de tener instalado lo siguiente:
* [Git](https://git-scm.com/)
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (para el frontend)
* [Python 3.9+](https://www.python.org/downloads/) (para el backend)
* [PostgreSQL](https://www.postgresql.org/download/) (para la base de datos)
* Un editor de código (ej: VS Code)

## 2. Configuración Inicial

1.  **Clonar el repositorio** (si es necesario):
    ```bash
    git clone [URL-DE-TU-REPO-GIT]
    cd MealIA
    ```
2.  **Crear la Base de Datos**:
    * Abre `pgAdmin` o tu cliente de PostgreSQL.
    * Crea una nueva base de datos llamada `meal_ia_db`.
    * (Opcional) Ejecuta el script `database/init_db.sql` para crear las tablas.

## 3. Ejecutar el Backend (FastAPI)

1.  **Navega a la carpeta backend**:
    ```bash
    cd backend
    ```
2.  **Crea y activa el entorno virtual**:
    ```bash
    # Crear (solo la primera vez)
    python -m venv venv

    # Activar (cada vez que trabajes)
    # Windows (CMD/PowerShell)
    venv\Scripts\activate
    # Mac/Linux (Git Bash)
    source venv/bin/activate
    ```
3.  **Instala las dependencias**:
    *Aún no hemos creado este archivo, pero es una buena práctica hacerlo:*
    ```bash
    # Corre esto para crear el archivo:
    pip freeze > requirements.txt

    # (La próxima vez, solo necesitarás correr):
    # pip install -r requirements.txt
    ```
4.  **Crea tu archivo `.env`**:
    * Crea un archivo `.env` en la carpeta `backend/`.
    * Añade tu cadena de conexión (¡no subir a Git!):
        `DATABASE_URL="postgresql://tu_usuario:tu_contraseña@localhost:5432/meal_ia_db"`
5.  **Inicia el servidor**:
    ```bash
    uvicorn main:app --reload
    ```
    El backend estará corriendo en `http://127.0.0.1:8000`

## 4. Ejecutar el Frontend (Flutter)

1.  **Navega a la carpeta del frontend**:
    ```bash
    # Desde la raíz del proyecto
    cd frontend/meal_ia
    ```
2.  **Obtén las dependencias de Flutter**:
    ```bash
    flutter pub get
    ```
3.  **Ejecuta la aplicación**:
    * Asegúrate de tener un emulador corriendo o un dispositivo conectado.
    ```bash
    flutter run
    ```