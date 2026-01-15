@echo off
echo Iniciando MEAL.IA Backend en 0.0.0.0:8000...
echo Permite conexiones desde dispositivos en la misma red WiFi.
echo Preciona Ctrl+C para detener.
echo ---------------------------------------------------
uvicorn main:app --host 0.0.0.0 --port 8000 --reload