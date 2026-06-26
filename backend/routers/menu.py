import os
import json
import random
import logging
import httpx
from datetime import date, datetime
from typing import Optional
import base64
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
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

# ─── Claves API opcionales (Edamam) ────────────────────────────────────────────
EDAMAM_APP_ID  = os.getenv("EDAMAM_APP_ID", "")
EDAMAM_APP_KEY = os.getenv("EDAMAM_APP_KEY", "")

# ─── URLs de APIs externas ──────────────────────────────────────────────────────
THEMEALDB_FILTER_URL  = "https://www.themealdb.com/api/json/v1/1/filter.php"
THEMEALDB_LOOKUP_URL  = "https://www.themealdb.com/api/json/v1/1/lookup.php"
THEMEALDB_SEARCH_URL  = "https://www.themealdb.com/api/json/v1/1/search.php"
EDAMAM_RECIPE_URL     = "https://api.edamam.com/api/recipes/v2"
USDA_API_KEY          = os.getenv("USDA_API_KEY", "DEMO_KEY")  # DEMO_KEY = 30 req/dia gratis

HTTP_TIMEOUT = 8  # segundos

# ─── Constantes ─────────────────────────────────────────────────────────────────
BASIC_PANTRY = {"sal", "pimienta", "aceite", "agua", "azucar", "vinagre",
                "aceite de oliva", "aceite vegetal", "ajo", "cebolla"}


# ════════════════════════════════════════════════════════════════════════════════
# CALCULO DE CALORIAS OBJETIVO
# ════════════════════════════════════════════════════════════════════════════════
def calculate_target_calories(user: models.User) -> int:
    weight    = user.weight or 70
    height_cm = (user.height * 100) if user.height else 170
    age       = 25
    if user.birthdate:
        today = date.today()
        age = today.year - user.birthdate.year - (
            (today.month, today.day) < (user.birthdate.month, user.birthdate.day)
        )

    # Mifflin-St Jeor
    bmr   = (10 * weight) + (6.25 * height_cm) - (5 * age) + 5
    tdee  = bmr * 1.3
    target = int(tdee)

    if user.goal == "Deficit":       target -= 400
    elif user.goal == "Aumentar masa": target += 400

    return max(1200, min(target, 4000))


# ════════════════════════════════════════════════════════════════════════════════
# BUSQUEDA EXTERNA DE RECETAS — TheMealDB (100% gratis, sin API key)
# ════════════════════════════════════════════════════════════════════════════════
def search_themealdb_by_ingredient(ingredient: str) -> list:
    """Busca recetas en TheMealDB por un ingrediente principal con aleatoriedad."""
    try:
        with httpx.Client(timeout=HTTP_TIMEOUT) as http:
            resp = http.get(THEMEALDB_FILTER_URL, params={"i": ingredient})
            if resp.status_code == 200:
                data = resp.json()
                meals = data.get("meals") or []
                if meals:
                    random.shuffle(meals)
                return meals[:10]  # maximo 10 candidatos aleatorios
    except Exception as e:
        logger.warning(f"TheMealDB filter error: {e}")
    return []


def get_themealdb_detail(meal_id: str) -> Optional[dict]:
    """Obtiene el detalle completo de una receta por su ID."""
    try:
        with httpx.Client(timeout=HTTP_TIMEOUT) as http:
            resp = http.get(THEMEALDB_LOOKUP_URL, params={"i": meal_id})
            if resp.status_code == 200:
                data = resp.json()
                meals = data.get("meals") or []
                return meals[0] if meals else None
    except Exception as e:
        logger.warning(f"TheMealDB lookup error: {e}")
    return None


def parse_themealdb_ingredients(meal: dict) -> list:
    """Extrae la lista de ingredientes de la respuesta de TheMealDB."""
    ingredients = []
    for i in range(1, 21):
        ing = meal.get(f"strIngredient{i}", "") or ""
        qty = meal.get(f"strMeasure{i}", "") or ""
        ing = ing.strip()
        qty = qty.strip()
        if ing:
            ingredients.append(f"{qty} {ing}".strip() if qty else ing)
    return ingredients


def search_recipes_for_meal(inventory_names: list, meal_type: str) -> list:
    """
    Busca recetas reales en TheMealDB usando los ingredientes disponibles.
    Retorna una lista de recetas con su URL de fuente.
    """
    candidates = {}  # id -> meal_detail
    
    # Randomizar los items prioritarios para variedad
    priority_items = inventory_names[:]
    random.shuffle(priority_items)
    priority_items = priority_items[:6]

    for ing_name in priority_items:
        meals = search_themealdb_by_ingredient(ing_name)
        for meal in meals:
            meal_id = meal.get("idMeal", "")
            if meal_id and meal_id not in candidates:
                detail = get_themealdb_detail(meal_id)
                if detail:
                    candidates[meal_id] = detail
                if len(candidates) >= 10:
                    break
        if len(candidates) >= 10:
            break

    if not candidates:
        # Fallback: buscar por nombre generico del tipo de comida con aleatoriedad
        search_terms = {
            "breakfast": ["egg", "bacon", "pancake", "bread", "milk", "oat"],
            "lunch": ["chicken", "beef", "pasta", "rice", "pork", "fish", "lamb"],
            "dinner": ["beef", "chicken", "salad", "soup", "fish", "vegetable", "tomato"]
        }
        fallback_term = random.choice(search_terms.get(meal_type, ["chicken"]))
        for meal in search_themealdb_by_ingredient(fallback_term):
            meal_id = meal.get("idMeal", "")
            if meal_id and meal_id not in candidates:
                detail = get_themealdb_detail(meal_id)
                if detail:
                    candidates[meal_id] = detail
            if len(candidates) >= 10:
                break

    # Calcular score de coincidencia con el inventario
    scored = []
    inv_set = set(inventory_names)
    for meal_id, meal in candidates.items():
        meal_ings = [
            (meal.get(f"strIngredient{i}") or "").strip().lower()
            for i in range(1, 21)
            if (meal.get(f"strIngredient{i}") or "").strip()
        ]
        matches = sum(
            1 for mi in meal_ings
            if any(inv in mi or mi in inv for inv in inv_set)
        )
        score = matches / max(len(meal_ings), 1)
        scored.append({
            "id":           meal_id,
            "name":         meal.get("strMeal", ""),
            "category":     meal.get("strCategory", ""),
            "area":         meal.get("strArea", ""),
            "instructions": meal.get("strInstructions", ""),
            "ingredients":  parse_themealdb_ingredients(meal),
            "thumb":        meal.get("strMealThumb", ""),
            "source_url":   meal.get("strSource") or f"https://www.themealdb.com/meal/{meal_id}",
            "source_name":  "TheMealDB",
            "match_score":  score,
        })

    scored.sort(key=lambda x: x["match_score"], reverse=True)
    return scored[:5]  # top 5 candidatos


# ════════════════════════════════════════════════════════════════════════════════
# BUSQUEDA EN EDAMAM (si hay API keys configuradas)
# ════════════════════════════════════════════════════════════════════════════════
def search_recipes_edamam(ingredients: list, calories_min: int, calories_max: int, meal_type: str) -> list:
    """Busca recetas en Edamam filtrando por calorias. Solo si hay API key."""
    if not EDAMAM_APP_ID or not EDAMAM_APP_KEY:
        return []
    try:
        # Usar ingredientes aleatorios para evitar los mismos resultados siempre
        sample_ings = ingredients[:]
        random.shuffle(sample_ings)
        q = ", ".join(sample_ings[:4]) if sample_ings else random.choice(["chicken", "beef", "egg", "salad"])
        
        params = {
            "type":      "public",
            "q":         q,
            "app_id":    EDAMAM_APP_ID,
            "app_key":   EDAMAM_APP_KEY,
            "calories":  f"{calories_min}-{calories_max}",
            "mealType":  meal_type.capitalize(),
            "field":     ["label", "url", "ingredientLines", "calories",
                          "totalNutrients", "totalTime", "source"],
        }
        with httpx.Client(timeout=HTTP_TIMEOUT) as http:
            resp = http.get(EDAMAM_RECIPE_URL, params=params)
            if resp.status_code == 200:
                hits = resp.json().get("hits", [])
                if hits:
                    random.shuffle(hits)
                results = []
                for hit in hits[:5]:
                    r        = hit.get("recipe", {})
                    nutrients = r.get("totalNutrients", {})
                    results.append({
                        "name":         r.get("label", ""),
                        "ingredients":  r.get("ingredientLines", []),
                        "instructions": "",
                        "calories":     int(r.get("calories", 0)),
                        "carbs":        int(nutrients.get("CHOCDF", {}).get("quantity", 0)),
                        "protein":      int(nutrients.get("PROCNT", {}).get("quantity", 0)),
                        "fat":          int(nutrients.get("FAT",    {}).get("quantity", 0)),
                        "fiber":        round(nutrients.get("FIBTG", {}).get("quantity", 0.0), 1),
                        "sugar":        round(nutrients.get("SUGAR", {}).get("quantity", 0.0), 1),
                        "sodium":       int(nutrients.get("NA",     {}).get("quantity", 0)),
                        "time":         f"{int(r.get('totalTime', 30))} min",
                        "source_url":   r.get("url", ""),
                        "source_name":  r.get("source", "Edamam"),
                        "match_score":  1.0,
                    })
                return results
    except Exception as e:
        logger.warning(f"Edamam search error: {e}")
    return []


# ════════════════════════════════════════════════════════════════════════════════
# FORMATEO DE CANDIDATOS PARA EL PROMPT DE GPT
# ════════════════════════════════════════════════════════════════════════════════
def format_recipe_candidates(recipes: list, meal_type: str, max_n: int = 3) -> str:
    """Serializa los candidatos de recetas reales para enviarselas a GPT."""
    if not recipes:
        return f"[Sin candidatos para {meal_type} — la IA debe elegir una receta similar conocida y citar la fuente de TheMealDB]"

    # Randomizar el orden de presentacion a GPT
    random_recipes = recipes[:]
    random.shuffle(random_recipes)

    lines = []
    for i, r in enumerate(random_recipes[:max_n], 1):
        ing_preview = "; ".join(r["ingredients"][:8])
        instructions_preview = (r.get("instructions") or "")[:300]
        lines.append(
            f"OPCION {i}: \"{r['name']}\"\n"
            f"  Fuente: {r.get('source_name','?')} | URL: {r.get('source_url','')}\n"
            f"  Ingredientes reales: {ing_preview}\n"
            f"  Instrucciones base: {instructions_preview}..."
        )
    return "\n\n".join(lines)


# ════════════════════════════════════════════════════════════════════════════════
# ENDPOINT: GUARDAR RECETA
# ════════════════════════════════════════════════════════════════════════════════
@router.post("/save-recipe", response_model=schemas.SavedRecipe)
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
        raise HTTPException(status_code=400, detail="Ya existe")

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


# ════════════════════════════════════════════════════════════════════════════════
# ENDPOINT PRINCIPAL: GENERAR MENU CON IA + RESPALDO CIENTIFICO
# ════════════════════════════════════════════════════════════════════════════════
@router.post("/generate-menu", response_model=schemas.MenuGenerationResponse)
def generate_menu_with_ia(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    if client is None:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    # ── 1. Inventario ────────────────────────────────────────────────────────────
    inventory_items = db.query(models.InventoryItem).filter(
        models.InventoryItem.owner_id == current_user.id
    ).all()
    if not inventory_items:
        raise HTTPException(status_code=400, detail="Inventario vacio")

    inventory_names    = [item.name.strip().lower() for item in inventory_items]
    inventory_numbered = "\n".join(
        [f"  {i+1}. {item.name} ({item.quantity} {item.unit})" for i, item in enumerate(inventory_items)]
    )

    target_calories = calculate_target_calories(current_user)

    # Distribucion calorica por comida
    breakfast_cal_target = int(target_calories * 0.25)
    lunch_cal_target     = int(target_calories * 0.40)
    dinner_cal_target    = int(target_calories * 0.35)
    cal_margin           = 150  # +/- kcal aceptable

    # ── 2. Gustos previos ────────────────────────────────────────────────────────
    saved   = db.query(models.SavedRecipe).filter(models.SavedRecipe.owner_id == current_user.id).limit(10).all()
    fav_txt = ""
    if saved:
        names   = [r.name for r in saved]
        fav_txt = f"GUSTOS PREVIOS: {', '.join(random.sample(names, min(len(names), 3)))}."

    vibes      = ["fresco y ligero", "reconfortante", "sabores intensos", "estilo mediterraneo", "energetico"]
    daily_vibe = random.choice(vibes)

    # ── 3. BUSQUEDA EXTERNA DE RECETAS REALES ───────────────────────────────────
    logger.info(f"Buscando recetas externas para {current_user.first_name} (objetivo: {target_calories} kcal)")

    # Intentar Edamam primero (tiene datos nutricionales integrados)
    breakfast_candidates = search_recipes_edamam(
        inventory_names, breakfast_cal_target - cal_margin, breakfast_cal_target + cal_margin, "breakfast"
    )
    lunch_candidates = search_recipes_edamam(
        inventory_names, lunch_cal_target - cal_margin, lunch_cal_target + cal_margin, "lunch"
    )
    dinner_candidates = search_recipes_edamam(
        inventory_names, dinner_cal_target - cal_margin, dinner_cal_target + cal_margin, "dinner"
    )

    # Si Edamam no retorno resultados, usar TheMealDB (siempre disponible, sin API key)
    if not breakfast_candidates:
        breakfast_candidates = search_recipes_for_meal(inventory_names, "breakfast")
    if not lunch_candidates:
        lunch_candidates     = search_recipes_for_meal(inventory_names, "lunch")
    if not dinner_candidates:
        dinner_candidates    = search_recipes_for_meal(inventory_names, "dinner")

    logger.info(
        f"Candidatos encontrados -> Desayuno: {len(breakfast_candidates)}, "
        f"Almuerzo: {len(lunch_candidates)}, Cena: {len(dinner_candidates)}"
    )

    breakfast_text = format_recipe_candidates(breakfast_candidates, "desayuno")
    lunch_text     = format_recipe_candidates(lunch_candidates,     "almuerzo")
    dinner_text    = format_recipe_candidates(dinner_candidates,    "cena")

    # ── 4. PROMPT DEL SISTEMA ────────────────────────────────────────────────────
    system_prompt = f"""
Eres "Meal.IA", un Nutricionista experto y Chef Ejecutivo de alta cocina.
Tu trabajo HOY es ADAPTAR recetas REALES que ya te fueron buscadas en bases de datos nutricionales confiables.

REGLA #1 ABSOLUTA: NUNCA INVENTES RECETAS DESDE CERO.
SIEMPRE debes SELECCIONAR una de las opciones reales proporcionadas abajo y adaptarla al inventario del usuario.

REGLA #2: SIEMPRE incluye el campo "source_url" con la URL real de la receta seleccionada.
NUNCA dejes source_url vacio o inventado. Usa exactamente la URL de la OPCION elegida.

REGLA #3: NUNCA uses ingredientes que no esten en el inventario del usuario (salvo los basicos).

=== PERFIL DEL USUARIO ===
Nombre: {current_user.first_name}
Objetivo de calorias: {target_calories} kcal totales al dia
  - Desayuno: ~{breakfast_cal_target} kcal
  - Almuerzo: ~{lunch_cal_target} kcal (comida principal)
  - Cena: ~{dinner_cal_target} kcal
Objetivo de salud: {current_user.goal or "Mantenimiento"}
{fav_txt}
Vibe del dia: {daily_vibe}

=== INGREDIENTES DISPONIBLES EN EL INVENTARIO ===
{inventory_numbered}

=== BASICOS SIEMPRE DISPONIBLES (sin necesidad de estar en inventario) ===
Sal, Pimienta, Aceite, Agua, Azucar, Vinagre, Ajo, Cebolla

=== REGLAS DE ADAPTACION ===
1. SELECCIONA la OPCION que mejor coincida con los ingredientes disponibles.
2. ADAPTA las cantidades a porciones individuales razonables (no usar 1 Kg de golpe).
3. TRADUCE el nombre y los pasos al espanol si estan en ingles.
4. CREA un nombre creativo de restaurante basado en el nombre original de la receta.
5. DETALLA los pasos con tiempos exactos. PROHIBIDO decir "cocina hasta que este listo".
6. El ultimo paso siempre debe ser el emplatado.
7. CALCULA de forma MATEMÁTICAMENTE EXACTA Y REAL los macros (carbs, protein, fat), micros (fiber, sugar, sodium) y calorías.
   - Las calorías DEBEN CUMPLIR EXACTAMENTE con la ecuación: (1g proteína = 4 kcal, 1g carbs = 4 kcal, 1g grasa = 9 kcal).
   - Ajusta meticulosamente las cantidades de los ingredientes para cumplir LO MÁS EXACTO POSIBLE con los objetivos calóricos del usuario, sin romper la receta.
   - Usa datos nutricionales reales (USDA, INCAP). NO inventes valores ni hagas aproximaciones burdas.

=== INSTRUCCIONES TECNICAS JSON ===
- Devuelve SOLO JSON valido, sin comentarios ni trailing commas.
- El campo "source_url" debe ser la URL exacta de la OPCION elegida.
- El campo "source_name" debe ser el nombre de la base de datos (TheMealDB, Edamam, etc.).
"""

    # ── 5. PROMPT DEL USUARIO ────────────────────────────────────────────────────
    prompt_del_usuario = f"""
Aqui estan las recetas REALES encontradas en bases de datos nutricionales confiables.
DEBES elegir una de ellas para cada tiempo de comida (no inventar nuevas):

DESAYUNO (opciones reales de TheMealDB/Edamam):
{breakfast_text}

ALMUERZO (opciones reales de TheMealDB/Edamam):
{lunch_text}

CENA (opciones reales de TheMealDB/Edamam):
{dinner_text}

INSTRUCCION: Para cada comida, selecciona la OPCION mas adecuada segun:
1. Ingredientes disponibles en el inventario de {current_user.first_name}
2. Objetivo calorico: desayuno ~{breakfast_cal_target} kcal, almuerzo ~{lunch_cal_target} kcal, cena ~{dinner_cal_target} kcal
3. Objetivo de salud: {current_user.goal or "Mantenimiento"}

FORMATO JSON OBLIGATORIO:
{{
  "breakfast": {{
    "name": "NOMBRE CREATIVO EN ESPANOL",
    "ingredients": ["cant+unidad ingrediente", "..."],
    "steps": ["Paso 1 con tiempo exacto...", "Paso 2...", "Emplatado final..."],
    "calories": 0,
    "carbs": 0,
    "protein": 0,
    "fat": 0,
    "fiber": 0.0,
    "sugar": 0.0,
    "sodium": 0,
    "time": "XX min",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  }},
  "lunch": {{
    "name": "NOMBRE CREATIVO EN ESPANOL",
    "ingredients": ["cant+unidad ingrediente", "..."],
    "steps": ["...", "Emplatado..."],
    "calories": 0,
    "carbs": 0,
    "protein": 0,
    "fat": 0,
    "fiber": 0.0,
    "sugar": 0.0,
    "sodium": 0,
    "time": "XX min",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  }},
  "dinner": {{
    "name": "NOMBRE CREATIVO EN ESPANOL",
    "ingredients": ["cant+unidad ingrediente", "..."],
    "steps": ["...", "Emplatado..."],
    "calories": 0,
    "carbs": 0,
    "protein": 0,
    "fat": 0,
    "fiber": 0.0,
    "sugar": 0.0,
    "sodium": 0,
    "time": "XX min",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  }},
  "note": "Nota motivadora del Chef para el objetivo de salud de {current_user.first_name}.",
  "total_calories": 0
}}
"""

    # ── 6. HELPERS DE PARSEO ─────────────────────────────────────────────────────
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

    # ── 7. GENERACION CON REINTENTOS ─────────────────────────────────────────────
    max_attempts = 3

    for attempt in range(max_attempts):
        try:
            completion = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user",   "content": prompt_del_usuario}
                ],
                response_format={"type": "json_object"},
                temperature=0.4 if attempt == 0 else 0.2,
            )

            content = completion.choices[0].message.content
            try:
                menu_data = json.loads(content)
                if not isinstance(menu_data, dict):
                    menu_data = {}
            except Exception:
                menu_data = {}

            # ── 8. SANITIZACION Y VALIDACION ─────────────────────────────────────
            for meal_name, meal_cal_target, meal_candidates in [
                ("breakfast", breakfast_cal_target, breakfast_candidates),
                ("lunch",     lunch_cal_target,     lunch_candidates),
                ("dinner",    dinner_cal_target,     dinner_candidates),
            ]:
                meal = menu_data.get(meal_name)
                if not isinstance(meal, dict):
                    meal = {}
                    menu_data[meal_name] = meal

                # Nombre
                if not isinstance(meal.get("name"), str) or not meal.get("name"):
                    meal["name"] = "Plato Especial del Chef"

                # Ingredientes y pasos
                if not isinstance(meal.get("ingredients"), list) or not meal.get("ingredients"):
                    meal["ingredients"] = ["Ingredientes variados al gusto"]
                if not isinstance(meal.get("steps"), list) or not meal.get("steps"):
                    meal["steps"] = ["Preparar segun receta original.", "Emplatar y servir."]

                # Calorias
                cal = safe_get_int(meal, "calories", meal_cal_target)
                if cal <= 0: cal = meal_cal_target
                meal["calories"] = cal

                # Macros
                meal["carbs"]   = safe_get_int(meal, "carbs")
                if meal["carbs"]   <= 0: meal["carbs"]   = int((cal * 0.50) / 4)
                meal["protein"] = safe_get_int(meal, "protein")
                if meal["protein"] <= 0: meal["protein"] = int((cal * 0.25) / 4)
                meal["fat"]     = safe_get_int(meal, "fat")
                if meal["fat"]     <= 0: meal["fat"]     = int((cal * 0.25) / 9)
                
                # ENFORCE EXACT MATH FOR CALORIES
                cal = (meal["carbs"] * 4) + (meal["protein"] * 4) + (meal["fat"] * 9)
                meal["calories"] = cal
                
                meal["sodium"]  = safe_get_int(meal, "sodium")
                if meal["sodium"]  <= 0: meal["sodium"]  = int(cal * 0.4)
                meal["sugar"]   = safe_get_float(meal, "sugar")
                if meal["sugar"]   <= 0.0: meal["sugar"]   = round(cal * 0.02, 1)
                meal["fiber"]   = safe_get_float(meal, "fiber")
                if meal["fiber"]   <= 0.0: meal["fiber"]   = round(cal * 0.012, 1)

                # Tiempo
                if not isinstance(meal.get("time"), str) or not meal.get("time") or meal["time"].startswith("0"):
                    step_count   = len(meal.get("steps", []))
                    meal["time"] = f"{15 + (step_count * 5)} min"

                # ── GARANTIZAR source_url REAL ────────────────────────────────────
                current_source_url  = meal.get("source_url") or ""
                current_source_name = meal.get("source_name") or ""

                is_url_invalid = (
                    not current_source_url
                    or "example" in current_source_url.lower()
                    or current_source_url.startswith("URL_")
                    or len(current_source_url) < 10
                )

                if is_url_invalid:
                    if meal_candidates:
                        best = meal_candidates[0]
                        meal["source_url"]  = best.get("source_url", "https://www.themealdb.com")
                        meal["source_name"] = best.get("source_name", "TheMealDB")
                    else:
                        meal["source_url"]  = "https://www.themealdb.com"
                        meal["source_name"] = "TheMealDB"
                else:
                    meal["source_url"]  = current_source_url
                    meal["source_name"] = current_source_name or "TheMealDB"

            # Total de calorias
            total = (
                menu_data["breakfast"]["calories"] +
                menu_data["lunch"]["calories"] +
                menu_data["dinner"]["calories"]
            )
            menu_data["total_calories"] = total

            # Nota del chef
            if not isinstance(menu_data.get("note"), str) or not menu_data.get("note"):
                menu_data["note"] = "Este menu fue elaborado con recetas reales verificadas, pensado especialmente para tus objetivos!"

            logger.info(
                f"Menu generado con respaldo (intento {attempt + 1}). "
                f"Fuentes: "
                f"{menu_data['breakfast'].get('source_name','?')} | "
                f"{menu_data['lunch'].get('source_name','?')} | "
                f"{menu_data['dinner'].get('source_name','?')}"
            )
            return menu_data

        except json.JSONDecodeError:
            logger.error("Error: La IA genero un JSON invalido.")
            if attempt == max_attempts - 1:
                raise HTTPException(status_code=500, detail="Error de formato en respuesta IA. Intenta de nuevo.")
        except Exception as e:
            logger.error(f"Error IA (intento {attempt + 1}): {e}")
            if attempt == max_attempts - 1:
                raise HTTPException(status_code=500, detail=f"Error interno IA: {e}")

    raise HTTPException(status_code=500, detail="Error generando menu despues de multiples intentos")


# ════════════════════════════════════════════════════════════════════════════════
# GESTION DE PLANES DE COMIDA (PREMIUM)
# ════════════════════════════════════════════════════════════════════════════════
@router.get("/meal-plans", response_model=list[schemas.MealPlan])
def get_meal_plans(
    start_date: str,
    end_date: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end   = datetime.strptime(end_date,   "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de fecha invalido. Use YYYY-MM-DD")

    plans = db.query(models.MealPlan).filter(
        models.MealPlan.owner_id == current_user.id,
        models.MealPlan.date >= start,
        models.MealPlan.date <= end
    ).all()
    return plans


@router.post("/meal-plans", response_model=schemas.MealPlan)
def save_meal_plan(
    plan: schemas.MealPlanCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    try:
        plan_date = datetime.strptime(plan.date, "%Y-%m-%d")
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail="Fecha invalida")

    existing = db.query(models.MealPlan).filter(
        models.MealPlan.owner_id == current_user.id,
        models.MealPlan.date == plan_date
    ).first()

    if existing:
        existing.breakfast      = plan.breakfast.model_dump()
        existing.lunch          = plan.lunch.model_dump()
        existing.dinner         = plan.dinner.model_dump()
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

# ════════════════════════════════════════════════════════════════════════════════
# TRACKING Y COMIDAS EXTRA
# ════════════════════════════════════════════════════════════════════════════════

@router.patch("/meal-plans/{date}/mark-eaten", response_model=schemas.MealPlan)
def mark_meal_eaten(
    date: str,
    request: schemas.MarkMealEatenRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    try:
        plan_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Fecha invalida")

    plan = db.query(models.MealPlan).filter(
        models.MealPlan.owner_id == current_user.id,
        models.MealPlan.date == plan_date
    ).first()

    if not plan:
        raise HTTPException(status_code=404, detail="Plan de comida no encontrado para esta fecha")

    val = 1 if request.eaten else 0
    if request.meal_type == "breakfast":
        plan.breakfast_eaten = val
    elif request.meal_type == "lunch":
        plan.lunch_eaten = val
    elif request.meal_type == "dinner":
        plan.dinner_eaten = val
    else:
        raise HTTPException(status_code=400, detail="Tipo de comida invalido")

    db.commit()
    db.refresh(plan)
    return plan

@router.post("/meal-plans/{date}/extra-meal", response_model=schemas.MealPlan)
def add_extra_meal(
    date: str,
    extra_meal: schemas.ExtraMealCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user)
):
    try:
        plan_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Fecha invalida")

    plan = db.query(models.MealPlan).filter(
        models.MealPlan.owner_id == current_user.id,
        models.MealPlan.date == plan_date
    ).first()

    if not plan:
        # Si no hay plan, creamos uno vacio solo para guardar la comida extra
        plan = models.MealPlan(
            date=plan_date,
            breakfast={}, lunch={}, dinner={}, total_calories=0,
            owner_id=current_user.id,
            extra_meals=[]
        )
        db.add(plan)
        db.commit()
        db.refresh(plan)

    current_extras = list(plan.extra_meals) if plan.extra_meals else []
    current_extras.append(extra_meal.model_dump())
    
    plan.extra_meals = current_extras
    db.commit()
    db.refresh(plan)
    return plan

@router.post("/analyze-food", response_model=schemas.MealDetail)
async def analyze_food(
    text_description: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    current_user: models.User = Depends(security.get_current_user)
):
    if not client:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")
        
    if not text_description and not image:
        raise HTTPException(status_code=400, detail="Debe proporcionar texto o imagen")

    messages = [
        {
            "role": "system",
            "content": "Eres un nutricionista experto. Tu objetivo es analizar la comida (ya sea por descripción o imagen) y devolver una estimación de sus ingredientes reales. DEBES devolver macros y calorías EXACTOS y MATEMÁTICAMENTE CORRECTOS. Las calorías totales DEBEN coincidir a la perfección con la ecuación: (1g proteína = 4 kcal, 1g carbs = 4 kcal, 1g grasa = 9 kcal). Utiliza estimaciones rigurosas basadas en bases de datos reales y responde en formato JSON estricto."
        }
    ]

    content = []
    if text_description:
        content.append({"type": "text", "text": f"Analiza esta comida y estima sus macros: {text_description}"})
    else:
        content.append({"type": "text", "text": "Analiza esta imagen de comida, identifica qué es, sus ingredientes probables y estima sus macros para una porción normal."})

    if image:
        contents = await image.read()
        base64_image = base64.b64encode(contents).decode('utf-8')
        mime_type = image.content_type or "image/jpeg"
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:{mime_type};base64,{base64_image}"
            }
        })
        
    messages.append({
        "role": "user",
        "content": content
    })

    system_prompt_format = """
FORMATO JSON OBLIGATORIO:
{
  "name": "Nombre de la comida identificada",
  "ingredients": ["ingrediente 1", "ingrediente 2"],
  "steps": ["Analizado desde foto/texto."],
  "calories": int,
  "carbs": int,
  "protein": int,
  "fat": int,
  "fiber": float,
  "sugar": float,
  "sodium": int,
  "time": "0 min",
  "source_url": "Extra Meal",
  "source_name": "Usuario"
}
"""
    messages[0]["content"] += system_prompt_format

    try:
        response = client.chat.completions.create(
            model="gpt-4o", # Model with vision
            messages=messages,
            response_format={"type": "json_object"},
            max_tokens=500
        )
        
        result_str = response.choices[0].message.content
        result = json.loads(result_str)
        
        # Enforce exact mathematical calories
        carbs = int(result.get("carbs", 0))
        protein = int(result.get("protein", 0))
        fat = int(result.get("fat", 0))
        result["calories"] = (carbs * 4) + (protein * 4) + (fat * 9)
        
        return result
    except Exception as e:
        logger.error(f"Error analizando comida: {e}")
        raise HTTPException(status_code=500, detail="Error al analizar la comida")

