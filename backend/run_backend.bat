@echo off
cd %~dp0
echo ==================================================
echo   MEAL.IA BACKEND SERVER
echo ==================================================
echo.

echo [1/3] Activando entorno virtual...
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
    echo ✓ Entorno virtual activado (venv)
) else if exist ".venv\Scripts\activate.bat" (
    call .venv\Scripts\activate.bat
    echo ✓ Entorno virtual activado (.venv)
) else (
    echo ✗ ERROR: No se encontró el entorno virtual!
    echo.
    echo Por favor, crea un entorno virtual primero:
    echo   python -m venv venv
    echo   venv\Scripts\activate
    echo   pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)

echo.
echo [2/3] Verificando dependencias...
python -c "import uvicorn" 2>nul
if errorlevel 1 (
    echo ✗ uvicorn no está instalado. Instalando dependencias...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ✗ ERROR: No se pudieron instalar las dependencias
        pause
        exit /b 1
    )
    echo ✓ Dependencias instaladas
) else (
    echo ✓ Dependencias OK
)

echo.
echo [3/3] Iniciando servidor...
echo.
echo ==================================================
echo   Servidor corriendo en: http://0.0.0.0:8000
echo   Permite conexiones desde dispositivos en la red
echo   Presiona Ctrl+C para detener
echo ==================================================
echo.
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
if errorlevel 1 (
    echo.
    echo ✗ ERROR: No se pudo iniciar el servidor
    echo Verifica que el puerto 8000 no esté en uso
    pause
)
