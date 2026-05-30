import os
import json
import random
import logging
from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from openai import OpenAI
import models
import schemas
import security
from database import get_db

router = APIRouter()

logger = logging.getLogger(__name__)

_openai_api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=_openai_api_key) if _openai_api_key else None

# --- CÁLCULO DE CALORÍAS ---
def calculate_target_calories(user: models.User) -> int:
    weight = user.weight or 70
    height_cm = (user.height * 100) if user.height else 170
    age = 25
    if user.birthdate:
        today = date.today()
        # Fix for calculating age correctly
        age = today.year - user.birthdate.year - ((today.month, today.day) < (user.birthdate.month, user.birthdate.day))
    
    # Mifflin-St Jeor
    bmr = (10 * weight) + (6.25 * height_cm) - (5 * age) + 5 
    tdee = bmr * 1.3 
    target = int(tdee)
    
    if user.goal == "Déficit": target -= 400 
    elif user.goal == "Aumentar masa": target += 400 
    
    return max(1200, min(target, 4000))

@router.post("/save-recipe", response_model=schemas.SavedRecipe)
def save_recipe(recipe: schemas.SavedRecipeCreate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    existing = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id, models.SavedRecipe.name == recipe.name).first()
    if existing: raise HTTPException(status_code=400, detail="Ya existe")
    
    new_recipe = models.SavedRecipe(name=recipe.name, ingredients=recipe.ingredients, steps=recipe.steps, calories=recipe.calories, owner_id=current_user.id)
    db.add(new_recipe)
    db.commit()
    db.refresh(new_recipe)
    return new_recipe

@router.post("/generate-menu", response_model=schemas.MenuGenerationResponse)
def generate_menu_with_ia(db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    if client is None:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")
    # 1. Obtener inventario
    inventory_items = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()
    if not inventory_items: raise HTTPException(status_code=400, detail="Inventario vacío")
    
    # Formateamos lista legible: "2.5 Kg de Harina"
    inventory_list_str = ", ".join([f"{item.quantity} {item.unit} de {item.name}" for item in inventory_items])
    # Lista de nombres normalizados para validación
    inventory_names = [item.name.strip().lower() for item in inventory_items]
    # Lista enumerada para el prompt
    inventory_numbered = "\n".join([f"  {i+1}. {item.name} ({item.quantity} {item.unit})" for i, item in enumerate(inventory_items)])
    
    target_calories = calculate_target_calories(current_user)
    
    # Básicos permitidos siempre (no necesitan estar en inventario)
    BASIC_PANTRY = {"sal", "pimienta", "aceite", "agua", "azúcar", "vinagre", "aceite de oliva", "aceite vegetal"}
    
    # 2. Gustos previos
    saved = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id).limit(10).all()
    fav_txt = ""
    if saved:
        names = [r.name for r in saved]
        fav_txt = f"GUSTOS PREVIOS: {', '.join(random.sample(names, min(len(names), 3)))}."

    vibes = ["fresco y ligero", "reconfortante", "sabores intensos", "estilo mediterráneo", "energético"]
    daily_vibe = random.choice(vibes)

    # --- FUNCIÓN DE VALIDACIÓN DE INGREDIENTES ---
    def validate_ingredients_against_inventory(menu_data: dict) -> list:
        """Retorna lista de ingredientes que NO están en el inventario ni en básicos."""
        invalid = []
        for meal_name in ["breakfast", "lunch", "dinner"]:
            meal = menu_data.get(meal_name, {})
            if not isinstance(meal, dict):
                continue
            ingredients = meal.get("ingredients", [])
            if not isinstance(ingredients, list):
                continue
            for ing_str in ingredients:
                ing_lower = str(ing_str).lower().strip()
                # Extraer el nombre del ingrediente (remover cantidad y unidad)
                # Formato típico: "200g de arroz", "2 huevos", "1 tomate mediano"
                found_in_inventory = False
                found_in_basics = False
                
                # Verificar contra básicos
                for basic in BASIC_PANTRY:
                    if basic in ing_lower:
                        found_in_basics = True
                        break
                
                if found_in_basics:
                    continue
                
                # Verificar contra inventario (fuzzy match)
                for inv_name in inventory_names:
                    if inv_name in ing_lower or ing_lower in inv_name:
                        found_in_inventory = True
                        break
                    # Match parcial: "tomate" en "2 tomates cherry"
                    inv_words = inv_name.split()
                    for word in inv_words:
                        if len(word) >= 3 and word in ing_lower:
                            found_in_inventory = True
                            break
                    if found_in_inventory:
                        break
                
                if not found_in_inventory and not found_in_basics:
                    invalid.append(ing_str)
        return invalid

    def build_system_prompt(rejected_ingredients=None):
        """Construye el prompt del sistema, opcionalmente con ingredientes rechazados."""
        rejected_section = ""
        if rejected_ingredients:
            rejected_list = ", ".join(rejected_ingredients)
            rejected_section = f"""
    
    ⛔ INGREDIENTES RECHAZADOS (NO USAR BAJO NINGUNA CIRCUNSTANCIA):
    [{rejected_list}]
    Estos ingredientes fueron usados en un intento anterior y NO están disponibles.
    """

        return f"""
    Eres "Meal.IA", un Nutricionista experto y Chef Ejecutivo de alta cocina.
    
    ╔══════════════════════════════════════════════╗
    ║  REGLA #1 ABSOLUTA: SOLO INGREDIENTES       ║
    ║  DE LA LISTA DE ABAJO. NADA MÁS.            ║
    ╚══════════════════════════════════════════════╝
    
    === INGREDIENTES DISPONIBLES (SOLO ESTOS) ===
{inventory_numbered}
    
    === BÁSICOS SIEMPRE DISPONIBLES ===
    Sal, Pimienta, Aceite, Agua, Azúcar, Vinagre
    
    ⚠️ CUALQUIER ingrediente que NO esté en las listas de arriba está PROHIBIDO.
    NO inventes ingredientes. NO asumas que el usuario tiene algo que no está listado.
    Si no puedes hacer un plato porque falta un ingrediente, CAMBIA DE RECETA.
    {rejected_section}
    REGLA DE LÓGICA DE PORCIONES (NO COMER 1 KG):
    1. Si la lista dice "1 Kg de Avena", significa que hay una BOLSA guardada. NO mandes al usuario a comer 1 Kg.
       -> Usa una porción lógica para 1 persona (Ej: 40g - 60g).
    2. Si dice "2 Kg de Arroz", usa solo 80g-100g.
    3. Si dice "5 Unidades de Tomate", usa 1 o 2.
    
    REGLAS DE ORDEN DE COMIDAS:
    1. EL ALMUERZO ES LA COMIDA PRINCIPAL (MÁS CALORÍAS).
    
    REGLAS DE ESTILO (NO SEAS FLOJO):
    1. **TÍTULOS:** Crea nombres de restaurante (Marketing). Ej: "Risotto Cremoso de..." en lugar de "Arroz con...".
    2. **PASOS DETALLADOS:** - Prohibido decir "cocina hasta que esté listo". 
       - DI: "Cocina por 5 minutos hasta dorar".
       - DI: "Cuando huelas a nuez tostada, apaga el fuego".
    3. **EMPLATADO:** El último paso siempre es cómo servirlo para que se vea bello.

    OBJETIVO:
    - Calorías totales: {target_calories} kcal (+/- 50).
    - Idioma: Español.

    INSTRUCCIONES DE DATOS "REALES" (NO INVENTAR):
    - Calcula los MACROS (Carbohidratos, Proteína, Grasa) aproximados reales de los ingredientes.
    - Calcula los MICROS:
       - Fiber (g): Fibra dietética.
       - Sugar (g): Azúcares totales.
       - Sodium (mg): Sodio estimado.
    - Calcula el TIEMPO de preparación real total (prep + cocción). Ej: "25 min".
    - Si no estás seguro de un micro, haz una estimación educada basada en ingredientes, NO pongas 0.

    INSTRUCCIONES TÉCNICAS JSON:
    - Devuelve SOLO JSON válido.
    - NO uses comas al final de las listas (trailing commas).
    """
    
    prompt_del_usuario = f"""
    Crea el plan para {current_user.first_name}. Vibe de hoy: {daily_vibe}. {fav_txt}
    
    RECUERDA: SOLO puedes usar ingredientes de la lista proporcionada + básicos (sal, pimienta, aceite, agua, azúcar, vinagre).
    
    FORMATO JSON OBLIGATORIO:
    {{
      "breakfast": {{ 
        "name": "TÍTULO MARKETING", 
        "ingredients": ["cant+unidad ing", ...], 
        "steps": ["Paso 1 (tiempo)...", "Paso 2...", "Emplatado..."], 
        "calories": int,
        "carbs": int,
        "protein": int,
        "fat": int,
        "fiber": float,
        "sugar": float,
        "sodium": int,
        "time": "XX min"
      }},
      "lunch": {{ 
        "name": "TÍTULO MARKETING", 
        "ingredients": ["cant+unidad ing", ...], 
        "steps": ["...", "Emplatado..."], 
        "calories": int,
        "carbs": int,
        "protein": int,
        "fat": int,
        "fiber": float,
        "sugar": float,
        "sodium": int,
        "time": "XX min"
      }},
      "dinner": {{ 
        "name": "TÍTULO MARKETING", 
        "ingredients": ["cant+unidad ing", ...], 
        "steps": ["...", "Emplatado..."], 
        "calories": int,
        "carbs": int,
        "protein": int,
        "fat": int,
        "fiber": float,
        "sugar": float,
        "sodium": int,
        "time": "XX min"
      }},
      "note": "Nota del Chef motivadora para tus objetivos.",
      "total_calories": int
    }}
    """

    # --- GENERACIÓN CON REINTENTOS ---
    max_attempts = 3
    rejected_so_far = []
    
    for attempt in range(max_attempts):
        try:
            system_prompt = build_system_prompt(
                rejected_ingredients=rejected_so_far if rejected_so_far else None
            )
            
            completion = client.chat.completions.create(
                model="gpt-4o-mini", 
                messages=[
                    {"role": "system", "content": system_prompt}, 
                    {"role": "user", "content": prompt_del_usuario}
                ],
                response_format={ "type": "json_object" },
                temperature=0.7 if attempt == 0 else 0.3,  # Más determinístico en reintentos
            )
            
            # Limpieza y parseo
            content = completion.choices[0].message.content
            try:
                menu_data = json.loads(content)
                if not isinstance(menu_data, dict):
                    menu_data = {}
            except Exception:
                menu_data = {}
                
            def safe_get_int(data, key, default=0):
                val = data.get(key)
                if val is None: return default
                try: return int(str(val).replace("g", "").replace("mg", "").replace("kcal", "").strip())
                except (ValueError, TypeError): return default

            def safe_get_float(data, key, default=0.0):
                val = data.get(key)
                if val is None: return default
                try: return float(str(val).replace("g", "").strip())
                except (ValueError, TypeError): return default

            # --- SANITIZACIÓN DE DATOS (NO DEVOLVER 0) ---
            for meal_name in ["breakfast", "lunch", "dinner"]:
                meal = menu_data.get(meal_name)
                if not isinstance(meal, dict):
                    meal = {}
                    menu_data[meal_name] = meal
                
                if not isinstance(meal.get("name"), str) or not meal.get("name"): 
                    meal["name"] = f"Delicioso {meal_name.capitalize()}"
                if not isinstance(meal.get("ingredients"), list) or not meal.get("ingredients"): 
                    meal["ingredients"] = ["Ingredientes variados al gusto"]
                if not isinstance(meal.get("steps"), list) or not meal.get("steps"): 
                    meal["steps"] = ["Preparar y servir."]
                
                cal = safe_get_int(meal, "calories", 500)
                if cal <= 0: cal = 500
                meal["calories"] = cal
                
                meal["carbs"] = safe_get_int(meal, "carbs")
                if meal["carbs"] <= 0: meal["carbs"] = int((cal * 0.50) / 4)
                
                meal["protein"] = safe_get_int(meal, "protein")
                if meal["protein"] <= 0: meal["protein"] = int((cal * 0.20) / 4)
                
                meal["fat"] = safe_get_int(meal, "fat")
                if meal["fat"] <= 0: meal["fat"] = int((cal * 0.30) / 9)
                
                meal["sodium"] = safe_get_int(meal, "sodium")
                if meal["sodium"] <= 0: meal["sodium"] = int(cal * 0.5)

                meal["sugar"] = safe_get_float(meal, "sugar")
                if meal["sugar"] <= 0.0: meal["sugar"] = round(cal * 0.02, 1)
                
                meal["fiber"] = safe_get_float(meal, "fiber")
                if meal["fiber"] <= 0.0: meal["fiber"] = round(cal * 0.015, 1)

                if not isinstance(meal.get("time"), str) or meal.get("time") == "" or meal["time"].startswith("0"):
                    step_count = len(meal.get("steps", []))
                    meal["time"] = f"{15 + (step_count * 5)} min"
                    
            # Recalcular total por seguridad
            total = (menu_data["breakfast"]["calories"] + 
                     menu_data["lunch"]["calories"] + 
                     menu_data["dinner"]["calories"])
            menu_data["total_calories"] = total

            # Ensure note exists
            if not isinstance(menu_data.get("note"), str) or not menu_data.get("note"):
                menu_data["note"] = "¡Disfruta de este menú preparado especialmente para ti!"
            
            # --- VALIDACIÓN POST-GENERACIÓN ---
            invalid_ingredients = validate_ingredients_against_inventory(menu_data)
            
            if not invalid_ingredients:
                # ✅ Todo válido, retornar
                logger.info(f"Menu generated successfully on attempt {attempt + 1}")
                return menu_data
            else:
                # ❌ Hay ingredientes fuera del inventario
                logger.warning(f"Attempt {attempt + 1}: Invalid ingredients found: {invalid_ingredients}")
                rejected_so_far.extend(invalid_ingredients)
                
                if attempt == max_attempts - 1:
                    # Último intento: devolver de todos modos pero loggear
                    logger.warning(f"Max attempts reached. Returning menu with possible invalid ingredients: {invalid_ingredients}")
                    return menu_data
                # Si no es el último intento, continuar al siguiente ciclo
                continue

        except json.JSONDecodeError:
            logger.error("Error: La IA generó un JSON inválido.")
            if attempt == max_attempts - 1:
                raise HTTPException(status_code=500, detail="Error de formato en respuesta IA. Intenta de nuevo.")
        except Exception as e:
            logger.error(f"Error IA (attempt {attempt + 1}): {e}")
            if attempt == max_attempts - 1:
                raise HTTPException(status_code=500, detail=f"Error interno IA: {e}")
    
    # Fallback (no debería llegar aquí)
    raise HTTPException(status_code=500, detail="Error generando menú después de múltiples intentos")

# --- GESTIÓN DE PLANES DE COMIDA (PREMIUM) ---

@router.get("/meal-plans", response_model=list[schemas.MealPlan])
def get_meal_plans(start_date: str, end_date: str, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    # Convert dates
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de fecha inválido. Use YYYY-MM-DD")
        
    plans = db.query(models.MealPlan).filter(
        models.MealPlan.owner_id == current_user.id,
        models.MealPlan.date >= start,
        models.MealPlan.date <= end
    ).all()
    return plans

@router.post("/meal-plans", response_model=schemas.MealPlan)
def save_meal_plan(plan: schemas.MealPlanCreate, db: Session = Depends(get_db), current_user: models.User = Depends(security.get_current_user)):
    try:
        plan_date = datetime.strptime(plan.date, "%Y-%m-%d")
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail="Fecha inválida")

    # Check existence
    existing = db.query(models.MealPlan).filter(models.MealPlan.owner_id == current_user.id, models.MealPlan.date == plan_date).first()
    
    if existing:
        existing.breakfast = plan.breakfast.model_dump()
        existing.lunch = plan.lunch.model_dump()
        existing.dinner = plan.dinner.model_dump()
        existing.total_calories = plan.total_calories
        db.commit()
        db.refresh(existing)
        return existing
    else:
        new_plan = models.MealPlan(
            date=plan_date,
            breakfast=plan.breakfast.model_dump(),
            lunch=plan.lunch.model_dump(),
            dinner=plan.dinner.model_dump(),
            total_calories=plan.total_calories,
            owner_id=current_user.id
        )
        db.add(new_plan)
        db.commit()
        db.refresh(new_plan)
        return new_plan
