import os
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles 
from fastapi.middleware.cors import CORSMiddleware

# Cargar variables de entorno
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

# IMPORTS FIX FOR RENDER/UVICORN
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Imports locales
import database
import payments
from routers import auth, users, inventory, menu
from database import engine

# Crear tablas (Si cambiaste modelos, recuerda borrar mealia.db para regenerar)
database.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Meal.IA Backend")
print("--------------------------------------------------")
print("MEAL.IA BACKEND STARTED - v3 (WITH ARGON2 & CORS)")
print("--------------------------------------------------")

# --- CORS CONFIGURATION (CRITICAL FOR MOBILE/FLUTTER) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allows all origins
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods
    allow_headers=["*"], # Allows all headers
)

# Include Routers
app.include_router(auth.router, tags=["Authentication"])
app.include_router(users.router, tags=["Users"])
app.include_router(inventory.router, tags=["Inventory"])
app.include_router(menu.router, tags=["Menu & Recipes"])
app.include_router(payments.router, tags=["Payments"])

# Configuración de carpetas
os.makedirs("uploads", exist_ok=True) 
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- ENDPOINT DE SALUD PARA DIAGNÓSTICO ---
@app.get("/health", tags=["Health"])
def health_check():
    """Endpoint simple para verificar que el servidor está corriendo"""
    return {
        "status": "ok",
        "message": "Backend is running",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)