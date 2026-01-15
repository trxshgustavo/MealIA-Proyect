@echo off
setlocal
title Configuracion Maestra de Meal.IA - MODO REPARACION

echo ===================================================
echo      MEAL.IA - SCRIPT MAESTRO DE REPARACION
echo ===================================================
echo.

:: 1. Verificar Permisos de Administrador (Necesario para Firewall)
echo [1/4] Verificando permisos...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo     [OK] Permisos de Administrador detectados.
) else (
    echo     [!] Se requieren permisos de Administrador.
    echo     -> Reiniciando script como Admin...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:: 2. Configurar Red (Firewall + IP)
echo.
echo [2/4] Configurando Entorno de Red (Firewall + IP)...
powershell -ExecutionPolicy Bypass -File "..\..\setup_network.ps1"
if %errorLevel% neq 0 (
    echo [ERROR] Fallo al ejecutar el script de red.
    pause
    exit /b
)

:: 3. Verificar Backend (Dependencias)
echo.
echo [3/4] Verificando Backend...
cd ..\..\backend
if not exist "venv" (
    echo     [!] Creando entorno virtual Python...
    python -m venv venv
)
call venv\Scripts\activate.bat
echo     Instalando/Actualizando dependencias...
pip install -r requirements.txt >nul 2>&1
if %errorLevel% == 0 (
    echo     [OK] Dependencias instaladas.
) else (
    echo     [WARN] Podria haber faltado alguna libreria. Recomendado revisar.
)

:: 4. Opciones de Inicio
echo.
echo ===================================================
echo      TODO LISTO - SISTEMA REPARADO
echo ===================================================
echo.
echo Selecciona opcion:
echo 1. Iniciar Servidor (Backend)
echo 2. Solo salir (Ya esta todo configurado)
echo.
set /p choice="Opcion: "

if "%choice%"=="1" (
    call run_server.bat
)

endlocal
