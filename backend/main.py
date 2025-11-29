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
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles 
from sqlalchemy.orm import Session
from pydantic import BaseModel 
from openai import OpenAI 

import models, schemas, security, database
from database import engine, get_db

# Carga las claves secretas de .env
load_dotenv()

# Configuración de OpenAI (Cliente moderno)
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Crea las tablas en la base de datos
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Meal.IA Backend")

# Configuración de carpeta uploads
os.makedirs("uploads", exist_ok=True) 
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# --- ESQUEMAS EXTRA ---
class GoogleLoginResponse(schemas.Token):
    is_new_user: bool

class PhotoResponse(BaseModel):
    photo_url: str


# --- FUNCIÓN AUXILIAR: CÁLCULO CIENTÍFICO DE CALORÍAS ---
def calculate_target_calories(user: models.User) -> int:
    weight = user.weight or 70
    height_cm = (user.height * 100) if user.height else 170
    
    age = 25
    if user.birthdate:
        today = date.today()
        age = today.year - user.birthdate.year - ((today.month, today.day) < (user.birthdate.month, user.birthdate.day))

    # Fórmula Mifflin-St Jeor
    bmr = (10 * weight) + (6.25 * height_cm) - (5 * age) + 5 
    tdee = bmr * 1.3 

    target = int(tdee)
    if user.goal == "Déficit":
        target -= 400 
    elif user.goal == "Aumentar masa":
        target += 400 
    
    return max(1200, min(target, 4000))


# --- 1. Endpoints de Autenticación ---

@app.post("/register", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = security.get_user(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email ya registrado")
    
    hashed_password = security.get_password_hash(user.password)
    new_user = models.User(
        email=user.email, 
        first_name=user.first_name, 
        hashed_password=hashed_password
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/token", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = security.get_user(db, email=form_data.username)
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=schemas.User)
def read_users_me(current_user: models.User = Depends(security.get_current_user)):
    return current_user

@app.put("/users/me/data", response_model=schemas.User)
def update_user_data(
    data: schemas.UserDataUpdate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    if data.first_name is not None:
        current_user.first_name = data.first_name
    if data.last_name is not None:
        current_user.last_name = data.last_name
    if data.height is not None:
        current_user.height = data.height
    if data.weight is not None:
        current_user.weight = data.weight
    if data.birthdate is not None:
        current_user.birthdate = data.birthdate
    if data.goal is not None:
        current_user.goal = data.goal
        
    db.commit()
    db.refresh(current_user)
    return current_user


# --- GESTIÓN DE FOTOS ---

@app.post("/users/me/upload-photo", response_model=PhotoResponse)
async def upload_profile_photo(
    request: Request, 
    file: UploadFile = File(...), 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    allowed_types = [
        "image/jpeg", "image/png", "image/heic", "image/webp", "application/octet-stream" 
    ]
    
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail=f"Tipo de archivo no válido ({file.content_type}).")

    file_extension = file.filename.split(".")[-1]
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = f"uploads/{unique_filename}"

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        print(f"Error al guardar archivo: {e}")
        raise HTTPException(status_code=500, detail="Error al guardar el archivo en el servidor.")
    finally:
        file.file.close()

    full_photo_url = f"{str(request.base_url)}{file_path}"
    current_user.photo_url = full_photo_url
    db.commit()
    db.refresh(current_user)

    return {"photo_url": full_photo_url}

@app.delete("/users/me/delete-photo", response_model=schemas.User)
async def delete_profile_photo(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    if current_user.photo_url:
        try:
            filename = current_user.photo_url.split("/")[-1]
            file_path = f"uploads/{filename}"
            if os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"Advertencia: No se pudo borrar el archivo físico: {e}")

    current_user.photo_url = None
    db.commit()
    db.refresh(current_user)

    return current_user


# --- 2. Endpoints de Inventario ---

@app.post("/inventory", response_model=schemas.InventoryItem)
def add_inventory_item(
    item: schemas.InventoryItemCreate, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    normalized_name = item.name.strip().lower()
    if not normalized_name:
        raise HTTPException(status_code=400, detail="El nombre no puede estar vacío")

    db_item = db.query(models.InventoryItem).filter(
        models.InventoryItem.owner_id == current_user.id,
        models.InventoryItem.name == normalized_name
    ).first()

    if db_item:
        db_item.quantity += 1
    else:
        db_item = models.InventoryItem(
            name=normalized_name, 
            owner_id=current_user.id,
            quantity=1
        )
        db.add(db_item)
    
    db.commit()
    db.refresh(db_item)
    return db_item

@app.post("/inventory/decrement/{item_name}", response_model=schemas.InventoryItem)
def decrement_inventory_item(
    item_name: str, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    db_item = db.query(models.InventoryItem).filter(
        models.InventoryItem.owner_id == current_user.id,
        models.InventoryItem.name == item_name
    ).first()

    if not db_item:
        raise HTTPException(status_code=404, detail="Ítem no encontrado")
    
    if db_item.quantity > 1:
        db_item.quantity -= 1
        db.commit()
        db.refresh(db_item)
        return db_item
    else:
        db.delete(db_item)
        db.commit()
        raise HTTPException(status_code=200, detail="Ítem eliminado")


@app.delete("/inventory/remove/{item_name}")
def remove_inventory_item(
    item_name: str, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    db_item = db.query(models.InventoryItem).filter(
        models.InventoryItem.owner_id == current_user.id,
        models.InventoryItem.name == item_name
    ).first()

    if not db_item:
        raise HTTPException(status_code=404, detail="Ítem no encontrado")

    db.delete(db_item)
    db.commit()
    return {"detail": "Ítem eliminado permanentemente"}


@app.get("/inventory", response_model=list[schemas.InventoryItem])
def get_inventory(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    return db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()


# --- 3. Endpoint: Guardar Receta ---

@app.post("/save-recipe", response_model=schemas.SavedRecipe)
def save_recipe(
    recipe: schemas.SavedRecipeCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    existing = db.query(models.SavedRecipe).filter(
        models.SavedRecipe.owner_id == current_user.id,
        models.SavedRecipe.name == recipe.name
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Esta receta ya está guardada.")

    new_recipe = models.SavedRecipe(
        name=recipe.name,
        ingredients=recipe.ingredients, 
        steps=recipe.steps,
        calories=recipe.calories,
        owner_id=current_user.id
    )
    db.add(new_recipe)
    db.commit()
    db.refresh(new_recipe)
    return new_recipe


# --- 4. GENERACIÓN DE MENÚ (IA DEFINITIVA: CHEF + CIENTÍFICO + PROFESOR) ---

@app.post("/generate-menu", response_model=schemas.MenuGenerationResponse)
def generate_menu_with_ia(
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(security.get_current_user)
):
    # 1. Obtener datos
    inventory_items = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()
    if not inventory_items:
        raise HTTPException(status_code=400, detail="Tu inventario está vacío. Añade alimentos primero.")
    inventory_dict = {item.name: item.quantity for item in inventory_items}
    
    # 2. Calcular calorías
    target_calories = calculate_target_calories(current_user)

    # 3. Leer gustos
    saved_recipes = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id).limit(10).all()
    favorites_text = ""
    if saved_recipes:
        fav_names = [r.name for r in saved_recipes]
        sample_favs = random.sample(fav_names, min(len(fav_names), 3))
        favorites_text = f"GUSTOS PREVIOS (Para inspiración, NO REPETIR): {', '.join(sample_favs)}."

    # 4. Variedad
    vibes = ["fresco y ligero", "reconfortante", "sabores intensos", "estilo mediterráneo", "energético"]
    daily_vibe = random.choice(vibes)

    # --- EL PROMPT SUPREMO ---
    prompt_del_sistema = f"""
    Eres "Meal.IA", un Chef Ejecutivo que enseña a cocinar a PRINCIPIANTES ABSOLUTOS.
    
    OBJETIVO MATEMÁTICO:
    - El usuario DEBE consumir {target_calories} kcal (+/- 50) hoy.
    - Ajusta las cantidades (auméntalas si es necesario) para llegar a esa meta.

    REGLAS DE ORO PARA EL CONTENIDO:
    1.  **IDIOMA:** TODO EN ESPAÑOL.
    2.  **INVENTARIO:** Usa EXCLUSIVAMENTE: {json.dumps(inventory_dict)}. (Básicos permitidos: Sal, Pimienta, Aceite, Agua). ¡PROHIBIDO INVENTAR INGREDIENTES!
    3.  **TÍTULOS:** Marketing Gastronómico. Nombres deliciosos y elegantes (ej: "Festín de Pollo Dorado").
    
    REGLAS DE ORO PARA LOS PASOS (ANTI-FLOJERA):
    1.  **LISTA NEGRA:** NUNCA digas "Sazona al gusto", "Cocina hasta que esté listo" o "Sigue las instrucciones del paquete".
    2.  **MICRO-PASOS:** Desglosa cada acción física.
    3.  **TIEMPO OBLIGATORIO:** CADA paso de cocción/preparación debe decir CUÁNTO TIEMPO toma (ej: "espera 5 minutos exactos").
    4.  **SEÑALES:** Dile qué buscar (olor, color, textura).
    5.  **EMPLATADO:** El ÚLTIMO paso de cada receta debe ser cómo servirlo en el plato para que se vea bonito y a qué temperatura comerlo.

    Salida: SOLO JSON válido.
    """
    
    prompt_del_usuario = f"""
    Genera el plan para {current_user.first_name}.
    Estilo de hoy: {daily_vibe}.
    
    FORMATO JSON REQUERIDO (Valores en Español):
    {{
      "breakfast": {{ "name": "TÍTULO", "ingredients": ["cant + ing", ...], "steps": ["Paso 1...", "Paso 2...", "Emplatado..."], "calories": int }},
      "lunch": {{ "name": "TÍTULO", "ingredients": ["cant + ing", ...], "steps": ["Paso 1...", "Paso 2...", "Emplatado..."], "calories": int }},
      "dinner": {{ "name": "TÍTULO", "ingredients": ["cant + ing", ...], "steps": ["Paso 1...", "Paso 2...", "Emplatado..."], "calories": int }},
      "note": "Mensaje del Chef.",
      "total_calories": int
    }}
    """

    try:
        completion = client.chat.completions.create(
            model="gpt-3.5-turbo", 
            messages=[
                {"role": "system", "content": prompt_del_sistema},
                {"role": "user", "content": prompt_del_usuario}
            ],
            temperature=0.8, # Equilibrio entre creatividad y obediencia
        )
        
        response_content = completion.choices[0].message.content
        print(f"DEBUG IA CHEF: {response_content}")
        
        menu_data = json.loads(response_content)

        # Corrección manual de suma de calorías
        cal_b = menu_data.get("breakfast", {}).get("calories", 0)
        cal_l = menu_data.get("lunch", {}).get("calories", 0)
        cal_d = menu_data.get("dinner", {}).get("calories", 0)
        menu_data["total_calories"] = cal_b + cal_l + cal_d

        return menu_data

    except Exception as e:
        print(f"Error IA: {e}")
        raise HTTPException(status_code=500, detail=f"Error interno IA: {str(e)}")


# --- 5. Endpoint de Google (Sin Cambios) ---

@app.post("/auth/google", response_model=GoogleLoginResponse) 
def auth_google(
    google_token: schemas.GoogleToken, 
    db: Session = Depends(get_db)
):
    WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")
    ANDROID_CLIENT_ID = os.getenv("GOOGLE_ANDROID_CLIENT_ID")
    
    if not WEB_CLIENT_ID or not ANDROID_CLIENT_ID:
        raise HTTPException(status_code=500, detail="Google Client IDs no configurados")

    CLIENT_IDS = [WEB_CLIENT_ID, ANDROID_CLIENT_ID]

    try:
        id_info = id_token.verify_oauth2_token(google_token.token, requests.Request())

        if id_info['aud'] not in CLIENT_IDS:
            raise ValueError(f"Audiencia inválida: {id_info['aud']}")

        email = id_info['email']
        first_name = id_info.get('given_name', 'Usuario')
        last_name = id_info.get('family_name') 

        user = security.get_user(db, email=email)
        is_new_user = False 

        if not user:
            is_new_user = True 
            fake_password = security.get_password_hash(os.urandom(16).hex()) 
            user = models.User(
                email=email,
                first_name=first_name,
                last_name=last_name, 
                hashed_password=fake_password
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        app_token = security.create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )
        
        return {
            "access_token": app_token, 
            "token_type": "bearer",
            "is_new_user": is_new_user
        }

    except ValueError as e:
        print(f"Error token Google: {e}")
        raise HTTPException(status_code=401, detail=f"Token inválido: {e}")
    except Exception as e:
        print(f"Error auth/google: {e}")
        raise HTTPException(status_code=500, detail="Error interno servidor")