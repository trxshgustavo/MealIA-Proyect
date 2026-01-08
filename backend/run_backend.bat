@echo off
cd %~dp0
echo Activating virtual environment (.venv)...
if exist ".venv\Scripts\activate.bat" (
    call .venv\Scripts\activate.bat
) else (
    echo .venv not found, trying venv...
    if exist "venv\Scripts\activate.bat" (
        call venv\Scripts\activate.bat
    ) else (
        echo No virtual environment found!
        pause
        exit /b
    )
)

echo Starting Mealia Backend on 0.0.0.0:8000...
echo Ensure this window stays open!
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
pause
