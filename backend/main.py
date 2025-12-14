import os
import json 
import shutil 
import uuid 
import random 
from dotenv import load_dotenv
from datetime import date, timedelta 
from google.oauth2 import id_token
from google.auth.transport import requests
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles 
from sqlalchemy.orm import Session
from pydantic import BaseModel 
from openai import OpenAI 

# Cargar variables de entorno
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

# Imports locales (sin imports relativos para uvicorn directo)
import models
import schemas
import security
import database
from database import engine, get_db

# Configuración OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Crear tablas (Si cambiaste modelos, recuerda borrar mealia.db para regenerar)
database.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Meal.IA Backend")

# --- CONFIGURACIÓN CORS ---
# Función para validar orígenes dinámicos de localhost
def cors_origin_validator(origin: str) -> bool:
    """Permite localhost y 127.0.0.1 con cualquier puerto"""
    if not origin:
        return False
    # Permitir cualquier puerto de localhost o 127.0.0.1
    if origin.startswith("http://localhost") or origin.startswith("http://127.0.0.1"):
        return True
    # Permitir emulador Android
    if origin.startswith("http://10.0.2.2"):
        return True
    # Permitir producción
    if origin == "https://mealia-proyect-1.onrender.com":
        return True
    # Permitir origen adicional desde .env
    extra_origin = os.getenv("CORS_ORIGIN")
    if extra_origin and origin == extra_origin:
        return True
    return False

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",  # Permite localhost/127.0.0.1 con cualquier puerto
    allow_origins=[
        "http://10.0.2.2:8000",  # Emulador Android
        "https://mealia-proyect-1.onrender.com",  # Producción
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuración de carpetas
os.makedirs("uploads", exist_ok=True) 
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# --- CLASES AUXILIARES ---
class GoogleLoginResponse(schemas.Token):
    is_new_user: bool

class PhotoResponse(BaseModel):
    photo_url: str


# --- ENDPOINT DE SALUD PARA DIAGNÓSTICO ---
@app.get("/health")
def health_check():
    """Endpoint simple para verificar que el servidor está corriendo"""
    return {
        "status": "ok",
        "message": "Backend is running",
        "version": "1.0.0"
    }

# --- CÁLCULO DE CALORÍAS ---
def calculate_target_calories(user: models.User) -> int:
    weight = user.weight or 70
    height_cm = (user.height * 100) if user.height else 170
    age = 25
    if user.birthdate:
        today = date.today()
        age = today.year - user.birthdate.year - ((today.month, today.day) < (user.birthdate.month, user.birthdate.day))
    
    # Mifflin-St Jeor
    bmr = (10 * weight) + (6.25 * height_cm) - (5 * age) + 5 
    tdee = bmr * 1.3 
    target = int(tdee)
    
    if user.goal == "Déficit": target -= 400 
    elif user.goal == "Aumentar masa": target += 400 
    
    return max(1200, min(target, 4000))


# --- 1. ENDPOINTS DE AUTENTICACIÓN ---

@app.post("/register", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = security.get_user(db, email=user.email)
    if db_user: raise HTTPException(status_code=400, detail="Email ya registrado")
    hashed_password = security.get_password_hash(user.password)
    new_user = models.User(email=user.email, first_name=user.first_name, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/token", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = security.get_user(db, email=form_data.username)
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas", headers={"WWW-Authenticate": "Bearer"})
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=schemas.User)
def read_users_me(current_user: models.User = Depends(security.get_current_user)):
    return current_user

@app.put("/users/me/data", response_model=schemas.User)
def update_user_data(data: schemas.UserDataUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    if data.first_name: current_user.first_name = data.first_name
    if data.last_name: current_user.last_name = data.last_name
    if data.height: current_user.height = data.height
    if data.weight: current_user.weight = data.weight
    if data.birthdate: current_user.birthdate = data.birthdate
    if data.goal: current_user.goal = data.goal
    db.commit()
    db.refresh(current_user)
    return current_user


# --- 2. GESTIÓN DE FOTOS ---

@app.post("/users/me/upload-photo", response_model=PhotoResponse)
async def upload_profile_photo(request: Request, file: UploadFile = File(...), db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    allowed_types = ["image/jpeg", "image/png", "image/heic", "image/webp", "application/octet-stream"]
    if file.content_type not in allowed_types: raise HTTPException(status_code=400, detail="Archivo no válido")
    
    file_extension = file.filename.split(".")[-1]
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = f"uploads/{unique_filename}"
    
    try:
        with open(file_path, "wb") as buffer: shutil.copyfileobj(file.file, buffer)
    except: raise HTTPException(status_code=500, detail="Error al guardar")
    finally: file.file.close()
    
    full_photo_url = f"{str(request.base_url)}{file_path}"
    current_user.photo_url = full_photo_url
    db.commit()
    return {"photo_url": full_photo_url}

@app.delete("/users/me/delete-photo", response_model=schemas.User)
async def delete_profile_photo(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    if current_user.photo_url:
        try:
            filename = current_user.photo_url.split("/")[-1]
            path = f"uploads/{filename}"
            if os.path.exists(path): os.remove(path)
        except: pass
    current_user.photo_url = None
    db.commit()
    return current_user


# --- 3. ENDPOINTS DE INVENTARIO ---

@app.post("/inventory", response_model=schemas.InventoryItem)
def add_inventory_item(item: schemas.InventoryItemCreate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    normalized_name = item.name.strip().lower()
    if not normalized_name: raise HTTPException(status_code=400, detail="Nombre vacío")
    
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id, models.InventoryItem.name == normalized_name).first()
    
    if db_item:
        db_item.quantity += item.quantity # Suma si existe
    else:
        # Crea nuevo con unidad
        db_item = models.InventoryItem(name=normalized_name, owner_id=current_user.id, quantity=item.quantity, unit=item.unit)
        db.add(db_item)
    
    db.commit()
    db.refresh(db_item)
    return db_item

@app.put("/inventory/{item_name}", response_model=schemas.InventoryItem)
def update_inventory_item(item_name: str, item_update: schemas.InventoryItemUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    normalized_name = item_name.strip().lower()
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id, models.InventoryItem.name == normalized_name).first()
    
    if not db_item: raise HTTPException(status_code=404, detail="Ítem no encontrado")
    
    # Actualiza valores
    db_item.quantity = item_update.quantity
    db_item.unit = item_update.unit
    
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/inventory/decrement/{item_name}", response_model=schemas.InventoryItem)
def decrement_inventory_item(item_name: str, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id, models.InventoryItem.name == item_name).first()
    if not db_item: raise HTTPException(status_code=404, detail="No encontrado")
    
    if db_item.quantity > 1:
        db_item.quantity -= 1
        db.commit()
        db.refresh(db_item)
        return db_item
    else:
        db.delete(db_item)
        db.commit()
        raise HTTPException(status_code=200, detail="Eliminado")

@app.delete("/inventory/remove/{item_name}")
def remove_inventory_item(item_name: str, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    db_item = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id, models.InventoryItem.name == item_name).first()
    if not db_item: raise HTTPException(status_code=404, detail="No encontrado")
    
    db.delete(db_item)
    db.commit()
    return {"detail": "Eliminado"}

@app.get("/inventory", response_model=list[schemas.InventoryItem])
def get_inventory(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    return db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()


# --- 4. ENDPOINT RECETAS ---

@app.post("/save-recipe", response_model=schemas.SavedRecipe)
def save_recipe(recipe: schemas.SavedRecipeCreate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    existing = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id, models.SavedRecipe.name == recipe.name).first()
    if existing: raise HTTPException(status_code=400, detail="Ya existe")
    
    new_recipe = models.SavedRecipe(name=recipe.name, ingredients=recipe.ingredients, steps=recipe.steps, calories=recipe.calories, owner_id=current_user.id)
    db.add(new_recipe)
    db.commit()
    db.refresh(new_recipe)
    return new_recipe


# --- 5. GENERACIÓN DE MENÚ (IA SUPREMA: LOGICA DE PORCIONES + MARKETING) ---

@app.post("/generate-menu", response_model=schemas.MenuGenerationResponse)
def generate_menu_with_ia(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    # 1. Obtener inventario
    inventory_items = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()
    if not inventory_items: raise HTTPException(status_code=400, detail="Inventario vacío")
    
    # Formateamos lista legible: "2.5 Kg de Harina"
    inventory_list_str = ", ".join([f"{item.quantity} {item.unit} de {item.name}" for item in inventory_items])
    target_calories = calculate_target_calories(current_user)
    
    # 2. Gustos previos
    saved = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id).limit(10).all()
    fav_txt = ""
    if saved:
        names = [r.name for r in saved]
        fav_txt = f"GUSTOS PREVIOS: {', '.join(random.sample(names, min(len(names), 3)))}."

    vibes = ["fresco y ligero", "reconfortante", "sabores intensos", "estilo mediterráneo", "energético"]
    daily_vibe = random.choice(vibes)

    # --- PROMPT DEFINITIVO ---
    prompt_del_sistema = f"""
    Eres "Meal.IA", un Nutricionista experto y Chef Ejecutivo de alta cocina.
    
    === CONTEXTO DEL INVENTARIO (CRÍTICO) ===
    Estás viendo la DESPENSA COMPLETA de la casa (STOCK TOTAL).
    Lista: [{inventory_list_str}]
    
    REGLA DE LÓGICA DE PORCIONES (NO COMER 1 KG):
    1. Si la lista dice "1 Kg de Avena", significa que hay una BOLSA guardada. NO mandes al usuario a comer 1 Kg.
       -> Usa una porción lógica para 1 persona (Ej: 40g - 60g).
    2. Si dice "2 Kg de Arroz", usa solo 80g-100g.
    3. Si dice "5 Unidades de Tomate", usa 1 o 2.
    
    REGLAS DE ORDEN DE COMIDAS:
    1. EL ALMUERZO ES LA COMIDA PRINCIPAL (MÁS CALORIAS).
    
    REGLAS DE DISPONIBILIDAD:
    1. USA SOLO LO QUE HAY EN LA LISTA NO USES COSAS QUE NO ESTAN EN EL INVENTARIO. (Permitidos extras básicos: Sal, Pimienta, Aceite, Agua).
    2. Si falta algo esencial para un plato, NO lo inventes. Cambia de receta.

    REGLAS DE ESTILO (NO SEAS FLOJO):
    1. **TÍTULOS:** Crea nombres de restaurante (Marketing). Ej: "Risotto Cremoso de..." en lugar de "Arroz con...".
    2. **PASOS DETALLADOS:** - Prohibido decir "cocina hasta que esté listo". 
       - DI: "Cocina por 5 minutos hasta dorar".
       - DI: "Cuando huelas a nuez tostada, apaga el fuego".
    3. **EMPLATADO:** El último paso siempre es cómo servirlo para que se vea bello.

    OBJETIVO:
    - Calorías totales: {target_calories} kcal (+/- 50).
    - Idioma: Español.

    INSTRUCCIONES TÉCNICAS JSON:
    - Devuelve SOLO JSON válido.
    - NO uses comas al final de las listas (trailing commas).
    """
    
    prompt_del_usuario = f"""
    Crea el plan para {current_user.first_name}. Vibe de hoy: {daily_vibe}. {fav_txt}
    
    FORMATO JSON OBLIGATORIO:
    {{
      "breakfast": {{ "name": "TÍTULO MARKETING", "ingredients": ["cant+unidad ing", ...], "steps": ["Paso 1 (tiempo)...", "Paso 2...", "Emplatado..."], "calories": int }},
      "lunch": {{ "name": "TÍTULO MARKETING", "ingredients": ["cant+unidad ing", ...], "steps": ["...", "Emplatado..."], "calories": int }},
      "dinner": {{ "name": "TÍTULO MARKETING", "ingredients": ["cant+unidad ing", ...], "steps": ["...", "Emplatado..."], "calories": int }},
      "note": "Nota del Chef motivadora para tus objetivos.",
      "total_calories": int
    }}
    """

    try:
        completion = client.chat.completions.create(
            model="gpt-3.5-turbo", 
            messages=[{"role": "system", "content": prompt_del_sistema}, {"role": "user", "content": prompt_del_usuario}],
            temperature=0.7, 
        )
        
        # Limpieza y parseo
        content = completion.choices[0].message.content
        menu_data = json.loads(content)
        
        # Recalcular total por seguridad
        total = (menu_data.get("breakfast",{}).get("calories",0) + 
                 menu_data.get("lunch",{}).get("calories",0) + 
                 menu_data.get("dinner",{}).get("calories",0))
        menu_data["total_calories"] = total
        
        return menu_data

    except json.JSONDecodeError:
        print("Error: La IA generó un JSON inválido.")
        raise HTTPException(status_code=500, detail="Error de formato en respuesta IA. Intenta de nuevo.")
    except Exception as e:
        print(f"Error IA: {e}")
        raise HTTPException(status_code=500, detail=f"Error interno IA: {e}")


# --- 6. ENDPOINT GOOGLE ---

@app.post("/auth/google", response_model=GoogleLoginResponse) 
def auth_google(google_token: schemas.GoogleToken, db: Session = Depends(get_db)):
    WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")
    ANDROID_CLIENT_ID = os.getenv("GOOGLE_ANDROID_CLIENT_ID")
    if not WEB_CLIENT_ID or not ANDROID_CLIENT_ID: raise HTTPException(status_code=500, detail="IDs de Google no configurados")
    
    CLIENT_IDS = [WEB_CLIENT_ID, ANDROID_CLIENT_ID]
    
    try:
        id_info = id_token.verify_oauth2_token(google_token.token, requests.Request())
        if id_info['aud'] not in CLIENT_IDS: raise ValueError(f"Audiencia inválida: {id_info['aud']}")
        
        email = id_info['email']
        first_name = id_info.get('given_name', 'Usuario')
        last_name = id_info.get('family_name') 
        
        user = security.get_user(db, email=email)
        is_new_user = False 
        
        if not user:
            is_new_user = True 
            fake_password = security.get_password_hash(os.urandom(16).hex()) 
            user = models.User(email=email, first_name=first_name, last_name=last_name, hashed_password=fake_password)
            db.add(user)
            db.commit()
            db.refresh(user)
        
        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        app_token = security.create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
        
        return {"access_token": app_token, "token_type": "bearer", "is_new_user": is_new_user}
        
    except ValueError as e:
        print(f"Error token Google: {e}")
        raise HTTPException(status_code=401, detail=f"Token inválido: {e}")
    except Exception as e:
        print(f"Error auth/google: {e}")
        raise HTTPException(status_code=500, detail="Error interno servidor")