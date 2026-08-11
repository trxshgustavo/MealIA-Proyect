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
EDAMAM_APP_ID = os.getenv("EDAMAM_APP_ID", "")
EDAMAM_APP_KEY = os.getenv("EDAMAM_APP_KEY", "")

# ─── URLs de APIs externas ──────────────────────────────────────────────────────
THEMEALDB_FILTER_URL = "https://www.themealdb.com/api/json/v1/1/filter.php"
THEMEALDB_LOOKUP_URL = "https://www.themealdb.com/api/json/v1/1/lookup.php"
THEMEALDB_SEARCH_URL = "https://www.themealdb.com/api/json/v1/1/search.php"
EDAMAM_RECIPE_URL = "https://api.edamam.com/api/recipes/v2"
USDA_API_KEY = os.getenv("USDA_API_KEY", "DEMO_KEY")  # DEMO_KEY = 30 req/dia gratis

HTTP_TIMEOUT = 8  # segundos

# ─── Constantes ─────────────────────────────────────────────────────────────────
BASIC_PANTRY = {
    "sal",
    "pimienta",
    "aceite",
    "agua",
    "azucar",
    "vinagre",
    "aceite de oliva",
    "aceite vegetal",
    "ajo",
    "cebolla",
}


# ════════════════════════════════════════════════════════════════════════════════
# CALCULO DE CALORIAS OBJETIVO
# ════════════════════════════════════════════════════════════════════════════════
def calculate_target_calories(user: models.User) -> int:
    weight = user.weight or 70
    height_cm = (user.height * 100) if user.height else 170
    age = 25
    if user.birthdate:
        today = date.today()
        age = (
            today.year
            - user.birthdate.year
            - ((today.month, today.day) < (user.birthdate.month, user.birthdate.day))
        )

    # Mifflin-St Jeor
    bmr = (10 * weight) + (6.25 * height_cm) - (5 * age) + 5
    tdee = bmr * 1.3
    target = int(tdee)

    if user.goal == "Deficit":
        target -= 400
    elif user.goal == "Aumentar masa":
        target += 400

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


def search_recipes_for_meal(inventory_names: list, meal_type: str, limit: int = 5) -> list:
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
            "dinner": [
                "beef",
                "chicken",
                "salad",
                "soup",
                "fish",
                "vegetable",
                "tomato",
            ],
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
            1 for mi in meal_ings if any(inv in mi or mi in inv for inv in inv_set)
        )
        score = matches / max(len(meal_ings), 1)
        scored.append(
            {
                "id": meal_id,
                "name": meal.get("strMeal", ""),
                "category": meal.get("strCategory", ""),
                "area": meal.get("strArea", ""),
                "instructions": meal.get("strInstructions", ""),
                "ingredients": parse_themealdb_ingredients(meal),
                "thumb": meal.get("strMealThumb", ""),
                "source_url": meal.get("strSource")
                or f"https://www.themealdb.com/meal/{meal_id}",
                "source_name": "TheMealDB",
                "match_score": score,
            }
        )

    scored.sort(key=lambda x: x["match_score"], reverse=True)
    return scored[:limit]  # top N candidatos


# ════════════════════════════════════════════════════════════════════════════════
# BUSQUEDA EN EDAMAM (si hay API keys configuradas)
# ════════════════════════════════════════════════════════════════════════════════
def search_recipes_edamam(
    ingredients: list, calories_min: int, calories_max: int, meal_type: str, limit: int = 5
) -> list:
    """Busca recetas en Edamam filtrando por calorias. Solo si hay API key."""
    if not EDAMAM_APP_ID or not EDAMAM_APP_KEY:
        return []
    try:
        # Usar ingredientes aleatorios para evitar los mismos resultados siempre
        sample_ings = ingredients[:]
        random.shuffle(sample_ings)
        q = (
            ", ".join(sample_ings[:4])
            if sample_ings
            else random.choice(["chicken", "beef", "egg", "salad"])
        )

        params = {
            "type": "public",
            "q": q,
            "app_id": EDAMAM_APP_ID,
            "app_key": EDAMAM_APP_KEY,
            "calories": f"{calories_min}-{calories_max}",
            "mealType": meal_type.capitalize(),
            "field": [
                "label",
                "url",
                "ingredientLines",
                "calories",
                "totalNutrients",
                "totalTime",
                "source",
            ],
        }
        with httpx.Client(timeout=HTTP_TIMEOUT) as http:
            resp = http.get(EDAMAM_RECIPE_URL, params=params)
            if resp.status_code == 200:
                hits = resp.json().get("hits", [])
                if hits:
                    random.shuffle(hits)
                results = []
                for hit in hits[:limit]:
                    r = hit.get("recipe", {})
                    nutrients = r.get("totalNutrients", {})
                    results.append(
                        {
                            "name": r.get("label", ""),
                            "ingredients": r.get("ingredientLines", []),
                            "instructions": "",
                            "calories": int(r.get("calories", 0)),
                            "carbs": int(
                                nutrients.get("CHOCDF", {}).get("quantity", 0)
                            ),
                            "protein": int(
                                nutrients.get("PROCNT", {}).get("quantity", 0)
                            ),
                            "fat": int(nutrients.get("FAT", {}).get("quantity", 0)),
                            "fiber": round(
                                nutrients.get("FIBTG", {}).get("quantity", 0.0), 1
                            ),
                            "sugar": round(
                                nutrients.get("SUGAR", {}).get("quantity", 0.0), 1
                            ),
                            "sodium": int(nutrients.get("NA", {}).get("quantity", 0)),
                            "time": f"{int(r.get('totalTime', 30))} min",
                            "source_url": r.get("url", ""),
                            "source_name": r.get("source", "Edamam"),
                            "match_score": 1.0,
                        }
                    )
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
        
        macros_info = ""
        if r.get("calories"):
            macros_info = f"  Macros Reales: {r.get('calories')} kcal (Carbs: {r.get('carbs')}g, Proteína: {r.get('protein')}g, Grasa: {r.get('fat')}g)\n"
            
        lines.append(
            f"OPCIÓN {i}: \"{r['name']}\"\n"
            f"  Fuente: {r.get('source_name','?')} | URL: {r.get('source_url','')}\n"
            f"{macros_info}"
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
    current_user: models.User = Depends(security.get_current_user),
):
    existing = (
        db.query(models.SavedRecipe)
        .filter(
            models.SavedRecipe.owner_id == current_user.id,
            models.SavedRecipe.name == recipe.name,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Ya existe")

    new_recipe = models.SavedRecipe(
        name=recipe.name,
        ingredients=recipe.ingredients,
        steps=recipe.steps,
        calories=recipe.calories,
        owner_id=current_user.id,
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
    request: schemas.GenerateMenuRequest = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    if client is None:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    # ── 1. Inventario ────────────────────────────────────────────────────────────
    inventory_items = (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.owner_id == current_user.id)
        .all()
    )
    if not inventory_items:
        raise HTTPException(status_code=400, detail="Inventario vacio")

    inventory_names = [item.name.strip().lower() for item in inventory_items]
    inventory_numbered = "\n".join(
        [
            f"  {i+1}. {item.name} ({item.quantity} {item.unit})"
            for i, item in enumerate(inventory_items)
        ]
    )

    # ── 1.5 Memoria de recetas recientes y rechazadas ─────────────────────────
    recent_plans = (
        db.query(models.MealPlan)
        .filter(models.MealPlan.owner_id == current_user.id)
        .order_by(models.MealPlan.date.desc())
        .limit(5)
        .all()
    )
    recent_names = []
    for plan in recent_plans:
        if plan.breakfast and isinstance(plan.breakfast, dict):
            recent_names.append(plan.breakfast.get("name", ""))
        if plan.lunch and isinstance(plan.lunch, dict):
            recent_names.append(plan.lunch.get("name", ""))
        if plan.dinner and isinstance(plan.dinner, dict):
            recent_names.append(plan.dinner.get("name", ""))
            
    recent_names = [n for n in recent_names if n]
    
    memory_constraint = ""
    if recent_names:
        memory_constraint += f"\n- RECIENTEMENTE CONSUMIDAS (NO REPETIR, debe haber 5 dias de diferencia): {', '.join(set(recent_names))}"
        
    if request and request.rejected_recipes:
        memory_constraint += f"\n- RECETAS RECHAZADAS AHORA MISMO (ESTRICTAMENTE PROHIBIDO REPETIR ESTAS): {', '.join(request.rejected_recipes)}"
        
    if memory_constraint:
        memory_constraint = f"""
=== RESTRICCIONES DE MEMORIA ==={memory_constraint}
- REGLA ANTI-TRAMPA (CRITICA): No basta con cambiarle el nombre a la receta para evadir esta lista. DEBES generar una receta sustancialmente distinta en concepto, técnica principal o perfil de sabor. Si la receta rechazada o consumida era un pollo a la plancha, NO ofrezcas otro pollo a la plancha con un nombre distinto. Cambia radicalmente la propuesta (ej. haz un guiso, un horneado o usa otra proteína/carbohidrato principal) respetando el inventario.
"""

    target_calories = calculate_target_calories(current_user)

    # Distribucion calorica por comida
    meals_per_day = getattr(current_user, 'meals_per_day', 3) or 3
    if meals_per_day == 4:
        breakfast_cal_target = int(target_calories * 0.25)
        snack1_cal_target = int(target_calories * 0.10)
        lunch_cal_target = int(target_calories * 0.35)
        dinner_cal_target = int(target_calories * 0.30)
    elif meals_per_day >= 5:
        breakfast_cal_target = int(target_calories * 0.20)
        snack1_cal_target = int(target_calories * 0.10)
        lunch_cal_target = int(target_calories * 0.35)
        snack2_cal_target = int(target_calories * 0.10)
        dinner_cal_target = int(target_calories * 0.25)
    else:
        breakfast_cal_target = int(target_calories * 0.25)
        lunch_cal_target = int(target_calories * 0.40)
        dinner_cal_target = int(target_calories * 0.35)
    cal_margin = 150  # +/- kcal aceptable

    # ── 2. Gustos previos ────────────────────────────────────────────────────────
    saved = (
        db.query(models.SavedRecipe)
        .filter(models.SavedRecipe.owner_id == current_user.id)
        .limit(10)
        .all()
    )
    fav_txt = ""
    if saved:
        names = [r.name for r in saved]
        fav_txt = (
            f"GUSTOS PREVIOS: {', '.join(random.sample(names, min(len(names), 3)))}."
        )

    vibes = [
        "fresco y ligero",
        "reconfortante",
        "sabores intensos",
        "estilo mediterraneo",
        "energetico",
    ]
    daily_vibe = random.choice(vibes)

    # ── 3. BUSQUEDA EXTERNA DE RECETAS REALES ───────────────────────────────────
    logger.info(
        f"Buscando recetas externas para {current_user.first_name} (objetivo: {target_calories} kcal)"
    )

    inventory_usda_context = get_inventory_usda_macros(inventory_items)

    # Intentar Edamam primero (tiene datos nutricionales integrados)
    breakfast_candidates = search_recipes_edamam(
        inventory_names,
        breakfast_cal_target - cal_margin,
        breakfast_cal_target + cal_margin,
        "breakfast",
    )
    lunch_candidates = search_recipes_edamam(
        inventory_names,
        lunch_cal_target - cal_margin,
        lunch_cal_target + cal_margin,
        "lunch",
    )
    dinner_candidates = search_recipes_edamam(
        inventory_names,
        dinner_cal_target - cal_margin,
        dinner_cal_target + cal_margin,
        "dinner",
    )

    # Si Edamam no retorno resultados, usar TheMealDB (siempre disponible, sin API key)
    if not breakfast_candidates:
        breakfast_candidates = search_recipes_for_meal(inventory_names, "breakfast")
    if not lunch_candidates:
        lunch_candidates = search_recipes_for_meal(inventory_names, "lunch")
    if not dinner_candidates:
        dinner_candidates = search_recipes_for_meal(inventory_names, "dinner")

    logger.info(
        f"Candidatos encontrados -> Desayuno: {len(breakfast_candidates)}, "
        f"Almuerzo: {len(lunch_candidates)}, Cena: {len(dinner_candidates)}"
    )

    breakfast_text = format_recipe_candidates(breakfast_candidates, "desayuno")
    lunch_text = format_recipe_candidates(lunch_candidates, "almuerzo")
    dinner_text = format_recipe_candidates(dinner_candidates, "cena")

    # ── 4. PROMPT DEL SISTEMA ────────────────────────────────────────────────────
    system_prompt = f"""
Eres "Meal.IA", un Nutricionista experto y Chef Ejecutivo de alta cocina.
Tu trabajo HOY es diseñar un menú diario utilizando ESTRICTAMENTE ÚNICAMENTE los ingredientes que el usuario tiene en su inventario. Te daremos algunas recetas reales como inspiración, pero el inventario manda.

REGLA #1 ABSOLUTA: INVENTARIO ESTRICTO.
NUNCA, BAJO NINGUNA CIRCUNSTANCIA, uses un ingrediente que no esté en la lista de INGREDIENTES DISPONIBLES EN EL INVENTARIO (salvo los básicos). Si una receta de inspiración requiere un ingrediente que el usuario no tiene, OMÍTELO o INVENTA una receta nueva usando SOLO lo que hay.

REGLA #2: INSPIRACIÓN Y SUSTENTO CIENTIFICO.
Utiliza las opciones proporcionadas abajo como INSPIRACIÓN comprobada. Si logras adaptar una de ellas al inventario, incluye su "source_url". Si te ves obligado a crear una adaptación drástica, la receta final DEBE tener un sustento científico nutricional claro que apoye el objetivo del usuario. No inventes mezclas arbitrarias; las recetas deben ser fisiológicamente beneficiosas y culinariamente coherentes. Pon "source_url": "Meal.IA", "source_name": "Nutrición Clínica AI".

REGLA #3: CERO ALUCINACIONES DE INGREDIENTES. ESTRICTO.
Si el usuario solo tiene pollo y arroz, tu receta solo puede llevar pollo, arroz y los básicos. No agregues "un toque de perejil", "vino", "salsa de soja" o "limón" si no están en la lista explícitamente. DEBES ser creativo SOLO con lo que hay. Si asumes un ingrediente que no está, el sistema fallará.

=== PERFIL DEL USUARIO ===
Nombre: {current_user.first_name}
Objetivo de calorias: {target_calories} kcal totales al dia (Distribuido en {meals_per_day} comidas)
Horarios configurados por el usuario: {current_user.meal_times or 'Predeterminados'}
**INSTRUCCION CRITICA**: Debes asegurar de poner la hora correspondiente en el campo "eating_time" de cada comida generada, usando el horario configurado por el usuario para esa comida.
Objetivo de salud: {current_user.goal or "Mantenimiento"}
Sexo biológico: {current_user.gender or "No especificado"}
**IMPORTANTE**: Ajusta las porciones, distribución de macronutrientes y metabolismo basal considerando el sexo biológico proporcionado.
{fav_txt}
Vibe del dia: {daily_vibe}

=== INGREDIENTES DISPONIBLES EN EL INVENTARIO ===
{inventory_numbered}

=== BASICOS SIEMPRE DISPONIBLES (sin necesidad de estar en inventario) ===
Sal, Pimienta, Aceite, Agua, Azucar, Vinagre, Ajo, Cebolla

=== BASE DE DATOS USDA EN VIVO PARA TUS CÁLCULOS ===
Utiliza OBLIGATORIAMENTE la siguiente información nutricional (obtenida de la base de datos oficial del USDA) para calcular los macros de los platillos que generes. Multiplica/ajusta estos valores a las cantidades exactas que asignes en tu receta para obtener los macros finales.
{inventory_usda_context}

=== REGLAS DE ADAPTACION Y BASE CIENTIFICA ===
1. Las recetas generadas DEBEN estar respaldadas por principios científicos de nutrición para ayudar al usuario con su objetivo de "{current_user.goal or "Mantenimiento"}". No crees platos "inventados" sin sentido nutricional. Prioriza combinaciones de ingredientes comprobadas que ofrezcan un perfil de macronutrientes y micronutrientes adecuado. Usa las opciones externas provistas abajo como guía principal de coherencia. Si debes adaptar una receta al inventario, hazlo respetando la sinergia nutricional.
2. ADAPTA y ESPECIFICA las cantidades exactas de cada ingrediente (ej. "150g de pollo", "2 tazas de arroz") a porciones individuales para llegar al objetivo calórico.
3. TRADUCE el nombre y los pasos al español.
4. CREA un nombre atractivo basado en la receta.
5. DETALLA los pasos paso a paso con tiempos exactos de preparación y cocción. PROHIBIDO dar instrucciones vagas como "cocina hasta que este listo".
6. El ultimo paso siempre debe ser el emplatado.
7. CALCULA de forma MATEMÁTICAMENTE EXACTA Y REAL los macros (carbs, protein, fat), micros (fiber, sugar, sodium) y calorías.
   - Las calorías DEBEN CUMPLIR EXACTAMENTE con la ecuación: (1g proteína = 4 kcal, 1g carbs = 4 kcal, 1g grasa = 9 kcal).
   - Ajusta meticulosamente las cantidades de los ingredientes para cumplir LO MÁS EXACTO POSIBLE con los objetivos calóricos del usuario, sin romper la receta.
   - Usa exclusivamente los datos nutricionales reales provistos arriba en la sección USDA. NO inventes valores. DEBES incluir Vitamina A (mcg), Vitamina C (mg), Calcio (mg) y Hierro (mg).
{memory_constraint}
=== INSTRUCCIONES TECNICAS JSON ===
- Devuelve SOLO JSON valido, sin comentarios ni trailing commas.
- El campo "source_url" debe ser la URL exacta de la OPCION elegida.
- El campo "source_name" debe ser el nombre de la base de datos (TheMealDB, Edamam, etc.).
"""

    # ── 5. PROMPT DEL USUARIO ────────────────────────────────────────────────────
    prompt_del_usuario = f"""
Aqui tienes recetas REALES como INSPIRACIÓN. 
Recuerda: ESTÁ ESTRICTAMENTE PROHIBIDO usar ingredientes de estas recetas que NO estén en el inventario. Si no puedes adaptarlas, crea tus propias recetas usando SOLO lo disponible.

DESAYUNO (opciones reales de TheMealDB/Edamam):
{breakfast_text}

ALMUERZO (opciones reales de TheMealDB/Edamam):
{lunch_text}

CENA (opciones reales de TheMealDB/Edamam):
{dinner_text}

INSTRUCCION: Para cada comida:
1. Revisa el inventario de {current_user.first_name} y NUNCA te salgas de él.
2. Objetivo calorico: Debes distribuir las calorias considerando la configuracion de {meals_per_day} comidas del usuario. (ej. Desayuno ~{breakfast_cal_target} kcal, Almuerzo ~{lunch_cal_target} kcal, Cena ~{dinner_cal_target} kcal, y el resto en extra_meals).
3. Objetivo de salud: {current_user.goal or "Mantenimiento"}.
4. Considera el sexo biológico ({current_user.gender or "No especificado"}) para calcular las necesidades reales de macronutrientes y calorías basales de manera más precisa.

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
    "vitamin_a": 0.0,
    "vitamin_c": 0.0,
    "calcium": 0.0,
    "iron": 0.0,
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
    "vitamin_a": 0.0,
    "vitamin_c": 0.0,
    "calcium": 0.0,
    "iron": 0.0,
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
    "vitamin_a": 0.0,
    "vitamin_c": 0.0,
    "calcium": 0.0,
    "iron": 0.0,
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
        if val is None:
            return default
        try:
            return int(
                str(val).replace("g", "").replace("mg", "").replace("kcal", "").strip()
            )
        except (ValueError, TypeError):
            return default

    def safe_get_float(data, key, default=0.0):
        val = data.get(key)
        if val is None:
            return default
        try:
            return float(str(val).replace("g", "").strip())
        except (ValueError, TypeError):
            return default

    # ── 7. GENERACION CON REINTENTOS ─────────────────────────────────────────────
    max_attempts = 3

    for attempt in range(max_attempts):
        try:
            completion = client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt_del_usuario},
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
            if not isinstance(menu_data.get("extra_meals"), list):
                menu_data["extra_meals"] = []
            
            # Prepare validation array
            validation_list = [
                ("breakfast", breakfast_cal_target, breakfast_candidates),
                ("lunch", lunch_cal_target, lunch_candidates),
                ("dinner", dinner_cal_target, dinner_candidates),
            ]
            
            # Add extra meals to validation dynamically (so they get default values, macros calculated, etc)
            for idx, extra_meal in enumerate(menu_data["extra_meals"]):
                cal_target = snack1_cal_target if idx == 0 and meals_per_day >= 4 else (snack2_cal_target if idx == 1 and meals_per_day >= 5 else 200)
                validation_list.append((f"extra_meal_{idx}", cal_target, []))

            for meal_name, meal_cal_target, meal_candidates in validation_list:
                if meal_name.startswith("extra_meal_"):
                    idx = int(meal_name.split("_")[-1])
                    meal = menu_data["extra_meals"][idx]
                else:
                    meal = menu_data.get(meal_name)
                    if not isinstance(meal, dict):
                        meal = {}
                        menu_data[meal_name] = meal
                meal = menu_data.get(meal_name)
                if not isinstance(meal, dict):
                    meal = {}
                    menu_data[meal_name] = meal

                # Nombre
                if not isinstance(meal.get("name"), str) or not meal.get("name"):
                    meal["name"] = "Plato Especial del Chef"

                # Ingredientes y pasos
                if not isinstance(meal.get("ingredients"), list) or not meal.get(
                    "ingredients"
                ):
                    meal["ingredients"] = ["Ingredientes variados al gusto"]
                if not isinstance(meal.get("steps"), list) or not meal.get("steps"):
                    meal["steps"] = [
                        "Preparar segun receta original.",
                        "Emplatar y servir.",
                    ]

                # Calorias
                cal = safe_get_int(meal, "calories", meal_cal_target)
                if cal <= 0:
                    cal = meal_cal_target
                meal["calories"] = cal

                # Macros
                meal["carbs"] = safe_get_int(meal, "carbs")
                if meal["carbs"] <= 0:
                    meal["carbs"] = int((cal * 0.50) / 4)
                meal["protein"] = safe_get_int(meal, "protein")
                if meal["protein"] <= 0:
                    meal["protein"] = int((cal * 0.25) / 4)
                meal["fat"] = safe_get_int(meal, "fat")
                if meal["fat"] <= 0:
                    meal["fat"] = int((cal * 0.25) / 9)

                # ENFORCE EXACT MATH FOR CALORIES
                cal = (meal["carbs"] * 4) + (meal["protein"] * 4) + (meal["fat"] * 9)
                meal["calories"] = cal

                meal["sodium"] = safe_get_int(meal, "sodium")
                if meal["sodium"] <= 0:
                    meal["sodium"] = int(cal * 0.4)
                meal["sugar"] = safe_get_float(meal, "sugar")
                if meal["sugar"] <= 0.0:
                    meal["sugar"] = round(cal * 0.02, 1)
                meal["fiber"] = safe_get_float(meal, "fiber")
                if meal["fiber"] <= 0.0:
                    meal["fiber"] = round(cal * 0.012, 1)

                # Vitaminas y minerales
                meal["vitamin_a"] = safe_get_float(meal, "vitamin_a")
                meal["vitamin_c"] = safe_get_float(meal, "vitamin_c")
                meal["calcium"] = safe_get_float(meal, "calcium")
                meal["iron"] = safe_get_float(meal, "iron")

                # Tiempo
                if (
                    not isinstance(meal.get("time"), str)
                    or not meal.get("time")
                    or meal["time"].startswith("0")
                ):
                    step_count = len(meal.get("steps", []))
                    meal["time"] = f"{15 + (step_count * 5)} min"

                # ── GARANTIZAR source_url REAL ────────────────────────────────────
                current_source_url = meal.get("source_url") or ""
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
                        meal["source_url"] = best.get(
                            "source_url", "https://www.themealdb.com"
                        )
                        meal["source_name"] = best.get("source_name", "TheMealDB")
                    else:
                        meal["source_url"] = "https://www.themealdb.com"
                        meal["source_name"] = "TheMealDB"
                else:
                    meal["source_url"] = current_source_url
                    meal["source_name"] = current_source_name or "TheMealDB"

            # Total de calorias
            total = (
                menu_data["breakfast"]["calories"]
                + menu_data["lunch"]["calories"]
                + menu_data["dinner"]["calories"]
                + sum(m.get("calories", 0) for m in menu_data["extra_meals"])
            )
            menu_data["total_calories"] = total

            # Nota del chef
            if not isinstance(menu_data.get("note"), str) or not menu_data.get("note"):
                menu_data["note"] = (
                    "Este menu fue elaborado con recetas reales verificadas, pensado especialmente para tus objetivos!"
                )

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
                raise HTTPException(
                    status_code=500,
                    detail="Error de formato en respuesta IA. Intenta de nuevo.",
                )
        except Exception as e:
            logger.error(f"Error IA (intento {attempt + 1}): {e}")
            if attempt == max_attempts - 1:
                raise HTTPException(status_code=500, detail=f"Error interno IA: {e}")

    raise HTTPException(
        status_code=500, detail="Error generando menu despues de multiples intentos"
    )


# ════════════════════════════════════════════════════════════════════════════════
# GESTION DE PLANES DE COMIDA (PREMIUM)
# ════════════════════════════════════════════════════════════════════════════════
# ════════════════════════════════════════════════════════════════════════════════
# ENDPOINT: GENERAR MENU SEMANAL CON IA (SOLO PREMIUM)
# ════════════════════════════════════════════════════════════════════════════════
@router.post("/generate-weekly-menu", response_model=list[schemas.MealPlan])
def generate_weekly_menu_with_ia(
    client_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    if client is None:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    if not current_user.is_premium:
        raise HTTPException(status_code=403, detail="Requiere suscripción Premium")

    # 1. Inventario
    inventory_items = (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.owner_id == current_user.id)
        .all()
    )
    if not inventory_items:
        raise HTTPException(status_code=400, detail="Inventario vacio")

    inventory_names = [item.name.strip().lower() for item in inventory_items]
    inventory_numbered = "\n".join(
        [
            f"  {i+1}. {item.name} ({item.quantity} {item.unit})"
            for i, item in enumerate(inventory_items)
        ]
    )

    target_calories = calculate_target_calories(current_user)
    breakfast_cal_target = int(target_calories * 0.25)
    lunch_cal_target = int(target_calories * 0.40)
    dinner_cal_target = int(target_calories * 0.35)

    # ── BÚSQUEDA DE RECETAS REALES ──
    logger.info(f"Buscando recetas externas (semanal) para {current_user.first_name}")

    inventory_usda_context = get_inventory_usda_macros(inventory_items)

    breakfast_candidates = search_recipes_edamam(inventory_names, breakfast_cal_target - 150, breakfast_cal_target + 150, "breakfast", limit=14)
    lunch_candidates = search_recipes_edamam(inventory_names, lunch_cal_target - 150, lunch_cal_target + 150, "lunch", limit=14)
    dinner_candidates = search_recipes_edamam(inventory_names, dinner_cal_target - 150, dinner_cal_target + 150, "dinner", limit=14)

    if not breakfast_candidates:
        breakfast_candidates = search_recipes_for_meal(inventory_names, "breakfast", limit=14)
    if not lunch_candidates:
        lunch_candidates = search_recipes_for_meal(inventory_names, "lunch", limit=14)
    if not dinner_candidates:
        dinner_candidates = search_recipes_for_meal(inventory_names, "dinner", limit=14)

    breakfast_text = format_recipe_candidates(breakfast_candidates, "desayuno", max_n=10)
    lunch_text = format_recipe_candidates(lunch_candidates, "almuerzo", max_n=10)
    dinner_text = format_recipe_candidates(dinner_candidates, "cena", max_n=10)

    system_prompt = f"""
Eres "Meal.IA", un Nutricionista experto y Chef Ejecutivo de alta cocina.
Tu trabajo HOY es diseñar un menú SEMANAL (7 días) utilizando ESTRICTAMENTE ÚNICAMENTE los ingredientes que el usuario tiene en su inventario. 
REGLA #1 ABSOLUTA: INVENTARIO ESTRICTO. NUNCA, BAJO NINGUNA CIRCUNSTANCIA, uses un ingrediente que no esté en la lista de INGREDIENTES DISPONIBLES EN EL INVENTARIO (salvo los básicos).

=== PERFIL DEL USUARIO ===
Nombre: {current_user.first_name}
Objetivo de calorias: {target_calories} kcal totales al dia
  - Desayuno: ~{breakfast_cal_target} kcal
  - Almuerzo: ~{lunch_cal_target} kcal
  - Cena: ~{dinner_cal_target} kcal
Objetivo de salud: {current_user.goal or "Mantenimiento"}
Sexo biológico: {current_user.gender or "No especificado"}
**IMPORTANTE**: Ajusta las porciones, distribución de macronutrientes y metabolismo basal considerando el sexo biológico proporcionado.

=== INGREDIENTES DISPONIBLES EN EL INVENTARIO ===
{inventory_numbered}

=== BASICOS SIEMPRE DISPONIBLES ===
Sal, Pimienta, Aceite, Agua, Azucar, Vinagre, Ajo, Cebolla

=== BASE DE DATOS USDA EN VIVO PARA TUS CÁLCULOS ===
Utiliza OBLIGATORIAMENTE la siguiente información nutricional (obtenida de la base de datos oficial del USDA) para calcular los macros de los platillos que generes. Multiplica/ajusta estos valores a las cantidades exactas que asignes en tu receta para obtener los macros finales.
{inventory_usda_context}

=== INSTRUCCIONES ===
1. Genera un JSON con un array "days" de 7 días exactos.
2. Cada día debe tener "breakfast", "lunch", "dinner", "note", y "total_calories".
3. REGLA DE ORO MACROS: Selecciona de las recetas de INSPIRACIÓN entregadas por el usuario. Calcula los macros EXACTOS basándote EXCLUSIVAMENTE en los valores USDA proporcionados arriba para los ingredientes que uses. Usa los macros de inspiración solo como referencia general, los tuyos deben ser matemáticamente correctos basados en USDA.
4. Calcula de forma MATEMÁTICAMENTE EXACTA las calorías usando esta ecuación: (1g proteína = 4 kcal, 1g carbs = 4 kcal, 1g grasa = 9 kcal).
5. El "source_url" y "source_name" debe ser de la receta original si la usaste, o "USDA FoodData Central" si la creaste 100% de ingredientes base.
6. NO asumas ingredientes externos.
7. Para cada receta:
   - ADAPTA y ESPECIFICA las cantidades exactas de cada ingrediente (ej. "150g de pollo", "2 tazas de arroz") a porciones individuales para llegar al objetivo calórico.
   - TRADUCE el nombre y los pasos al español.
   - DETALLA los pasos paso a paso con tiempos exactos de preparación y cocción. PROHIBIDO dar instrucciones vagas como "cocina hasta que esté listo".
   - El último paso siempre debe ser el emplatado.
8. La estructura debe ser estrictamente válida JSON.
"""
    prompt_user = f"""Genera mi menú semanal de 7 días exactos.
Aquí tienes un catálogo de recetas 100% REALES con sus macros verdaderos para usar de INSPIRACIÓN y que distribuyas en la semana:

DESAYUNOS REALES DISPONIBLES:
{breakfast_text}

ALMUERZOS REALES DISPONIBLES:
{lunch_text}

CENAS REALES DISPONIBLES:
{dinner_text}

INSTRUCCIÓN: Para cada uno de los 7 días, elige una receta de este catálogo (¡no las inventes!), adáptala si falta algún ingrediente basándote en mi inventario, y copia sus macros exactos al JSON. 
FORMATO JSON OBLIGATORIO:
{{
  "days": [
    {{
      "breakfast": {{
        "name": "...", "ingredients": ["..."], "steps": ["..."], "calories": 0, "carbs": 0, "protein": 0, "fat": 0, "fiber": 0, "sugar": 0, "sodium": 0, "vitamin_a": 0, "vitamin_c": 0, "calcium": 0, "iron": 0, "time": "15 min", "source_url": "URL", "source_name": "Edamam"
      }},
      "lunch": {{ ... }},
      "dinner": {{ ... }},
      "note": "Breve nota del dia",
      "total_calories": 0
    }}
  ]
}}
Asegúrate de que haya exactamente 7 elementos en el array "days".
"""
    try:
        completion = client.chat.completions.create(
            model="gpt-4o-mini", # Usar gpt-4o-mini para mayor límite de tokens de salida
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt_user},
            ],
            response_format={"type": "json_object"},
            temperature=0.7,
            max_tokens=10000
        )
        content = completion.choices[0].message.content
        data = json.loads(content)
        
        days_generated = data.get("days", [])
        
        saved_plans = []
        from datetime import timedelta, datetime
        
        # Eliminar planes futuros (de hoy en adelante) para reemplazarlos con el nuevo plan
        today = date.today()
        if client_date:
            try:
                dt = datetime.strptime(client_date, "%Y-%m-%d")
                today = dt.date()
            except ValueError:
                pass
        today_datetime = datetime(today.year, today.month, today.day)
        
        # Opcional: borrar planes futuros para que no se superpongan (solo los generados automáticamente)
        db.query(models.MealPlan).filter(
            models.MealPlan.owner_id == current_user.id,
            models.MealPlan.date >= today_datetime
        ).delete()
        db.commit()
        
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
            
        for idx, day_data in enumerate(days_generated[:7]):
            plan_date = today_datetime + timedelta(days=idx)
            
            # Asegurar calculos exactos y sanitizacion
            for meal_key, meal_cal_target in [("breakfast", breakfast_cal_target), ("lunch", lunch_cal_target), ("dinner", dinner_cal_target)]:
                meal = day_data.get(meal_key)
                if not isinstance(meal, dict):
                    meal = {}
                    
                meal["name"] = meal.get("name") or "Plato Especial del Chef"
                if not isinstance(meal.get("ingredients"), list) or not meal.get("ingredients"):
                    meal["ingredients"] = ["Ingredientes variados al gusto"]
                if not isinstance(meal.get("steps"), list) or not meal.get("steps"):
                    meal["steps"] = ["Preparar según receta original.", "Emplatar y servir."]
                    
                cal = safe_get_int(meal, "calories", meal_cal_target)
                if cal <= 0: cal = meal_cal_target
                
                meal["carbs"] = safe_get_int(meal, "carbs", int((cal * 0.50) / 4))
                meal["protein"] = safe_get_int(meal, "protein", int((cal * 0.25) / 4))
                meal["fat"] = safe_get_int(meal, "fat", int((cal * 0.25) / 9))
                
                # ENFORCE EXACT MATH FOR CALORIES
                cal = (meal["carbs"] * 4) + (meal["protein"] * 4) + (meal["fat"] * 9)
                meal["calories"] = cal
                
                meal["sodium"] = safe_get_int(meal, "sodium", int(cal * 0.4))
                meal["sugar"] = safe_get_float(meal, "sugar", round(cal * 0.02, 1))
                meal["fiber"] = safe_get_float(meal, "fiber", round(cal * 0.012, 1))
                
                meal["vitamin_a"] = safe_get_float(meal, "vitamin_a", 0.0)
                meal["vitamin_c"] = safe_get_float(meal, "vitamin_c", 0.0)
                meal["calcium"] = safe_get_float(meal, "calcium", 0.0)
                meal["iron"] = safe_get_float(meal, "iron", 0.0)
                
                if not isinstance(meal.get("time"), str) or not meal.get("time") or meal["time"].startswith("0"):
                    meal["time"] = "15 min"
                    
                meal["source_url"] = meal.get("source_url") or "Meal.IA"
                meal["source_name"] = meal.get("source_name") or "Nutrición IA"
                
                day_data[meal_key] = meal
                
            total_cal = day_data.get("breakfast", {}).get("calories", 0) + \
                        day_data.get("lunch", {}).get("calories", 0) + \
                        day_data.get("dinner", {}).get("calories", 0)
                        
            new_plan = models.MealPlan(
                date=plan_date,
                breakfast=day_data.get("breakfast", {}),
                lunch=day_data.get("lunch", {}),
                dinner=day_data.get("dinner", {}),
                total_calories=total_cal,
                owner_id=current_user.id,
            )
            db.add(new_plan)
            saved_plans.append(new_plan)
            
        db.commit()
        for plan in saved_plans:
            db.refresh(plan)
            
        return saved_plans

    except Exception as e:
        logger.error(f"Error AI Weekly Menu: {e}")
        raise HTTPException(status_code=500, detail=f"Error generando menú semanal: {str(e)}")


@router.get("/meal-plans", response_model=list[schemas.MealPlan])
def get_meal_plans(
    start_date: str,
    end_date: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status_code=400, detail="Formato de fecha invalido. Use YYYY-MM-DD"
        )

    plans = (
        db.query(models.MealPlan)
        .filter(
            models.MealPlan.owner_id == current_user.id,
            models.MealPlan.date >= start,
            models.MealPlan.date <= end,
        )
        .all()
    )
    return plans


@router.post("/meal-plans", response_model=schemas.MealPlan)
def save_meal_plan(
    plan: schemas.MealPlanCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    try:
        plan_date = datetime.strptime(plan.date, "%Y-%m-%d")
    except (ValueError, Exception):
        raise HTTPException(status_code=400, detail="Fecha invalida")

    existing = (
        db.query(models.MealPlan)
        .filter(
            models.MealPlan.owner_id == current_user.id,
            models.MealPlan.date == plan_date,
        )
        .first()
    )

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
            owner_id=current_user.id,
        )
        db.add(new_plan)
        db.commit()
        db.refresh(new_plan)
        return new_plan


# ════════════════════════════════════════════════════════════════════════════════
# TRACKING Y COMIDAS EXTRA
# ════════════════════════════════════════════════════════════════════════════════


@router.patch("/meal-plans/{date}/mark-eaten", response_model=schemas.MarkMealEatenResponse)
def mark_meal_eaten(
    date: str,
    request: schemas.MarkMealEatenRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    try:
        plan_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Fecha invalida")

    plan = (
        db.query(models.MealPlan)
        .filter(
            models.MealPlan.owner_id == current_user.id,
            models.MealPlan.date == plan_date,
        )
        .first()
    )

    if not plan:
        raise HTTPException(
            status_code=404, detail="Plan de comida no encontrado para esta fecha"
        )

    val = 1 if request.eaten else 0
    if request.meal_type == "breakfast":
        plan.breakfast_eaten = val
    elif request.meal_type == "lunch":
        plan.lunch_eaten = val
    elif request.meal_type == "dinner":
        plan.dinner_eaten = val
    else:
        raise HTTPException(status_code=400, detail="Tipo de comida invalido")

    depleted_items = []
    
    if request.eaten:
        # Deduct inventory using AI for parsing
        meal_data = {}
        if request.meal_type == "breakfast":
            meal_data = plan.breakfast
        elif request.meal_type == "lunch":
            meal_data = plan.lunch
        elif request.meal_type == "dinner":
            meal_data = plan.dinner
            
        if isinstance(meal_data, dict) and "ingredients" in meal_data:
            ingredients_list = meal_data["ingredients"]
            inventory = db.query(models.InventoryItem).filter(models.InventoryItem.owner_id == current_user.id).all()
            
            if inventory and ingredients_list and client:
                inv_dict = {i.name: {"id": i.id, "qty": i.quantity, "unit": i.unit} for i in inventory}
                inv_str = ", ".join([f"{k} (ID: {v['id']}): {v['qty']} {v['unit']}" for k, v in inv_dict.items()])
                ing_str = "\n".join(ingredients_list)
                
                prompt = f"""
                El usuario ha cocinado una receta con los siguientes ingredientes (texto libre):
                {ing_str}
                
                Su inventario actual estructurado en la base de datos es:
                {inv_str}
                
                Tu trabajo es extraer la cantidad usada de cada ingrediente en la receta para saber cuánto descontar del inventario.
                Debes emparejar el ingrediente de la receta con el ID numérico correcto del inventario.
                CRÍTICO: NO restes todo el inventario. SOLO deduce la porción usada en la receta.
                Ejemplo: Si la receta pide '2 huevos' y el inventario tiene '12', amount_to_subtract debe ser 2.
                Convierte las unidades matemáticamente si es necesario (ej: si la receta usa 500g y el inventario está en kg, amount_to_subtract es 0.5).
                Si la receta no especifica cantidad o usa términos abstractos ("una pizca"), asume un valor numérico pequeño o asume 0 para no restar.
                NUNCA devuelvas un amount_to_subtract igual a la cantidad total del inventario a menos que la receta demande usar esa cantidad exacta.
                Devuelve SOLO un JSON valido con este formato estricto:
                {{
                  "deductions": [
                    {{"id": 1, "amount_to_subtract": 2}}
                  ]
                }}
                """
                try:
                    completion = client.chat.completions.create(
                        model="gpt-3.5-turbo",
                        messages=[{"role": "user", "content": prompt}],
                        temperature=0,
                        response_format={ "type": "json_object" }
                    )
                    import json
                    result = json.loads(completion.choices[0].message.content)
                    deductions = result.get("deductions", [])
                    
                    for ded in deductions:
                        item_id = ded.get("id")
                        sub = ded.get("amount_to_subtract")
                        if item_id and sub:
                            item = db.query(models.InventoryItem).filter(models.InventoryItem.id == item_id).first()
                            if item:
                                item.quantity -= sub
                                if item.quantity <= 0:
                                    depleted_items.append(item.name)
                                    db.delete(item)
                                else:
                                    db.add(item)
                except Exception as e:
                    logger.warning(f"Error parseando deduccion de inventario con IA: {e}")

    db.commit()
    db.refresh(plan)
    return schemas.MarkMealEatenResponse(plan=plan, depleted_items=depleted_items)


@router.post("/meal-plans/{date}/extra-meal", response_model=schemas.MealPlan)
def add_extra_meal(
    date: str,
    extra_meal: schemas.ExtraMealCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    try:
        plan_date = datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Fecha invalida")

    plan = (
        db.query(models.MealPlan)
        .filter(
            models.MealPlan.owner_id == current_user.id,
            models.MealPlan.date == plan_date,
        )
        .first()
    )

    if not plan:
        # Si no hay plan, creamos uno vacio solo para guardar la comida extra
        plan = models.MealPlan(
            date=plan_date,
            breakfast={},
            lunch={},
            dinner={},
            total_calories=0,
            owner_id=current_user.id,
            extra_meals=[],
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


async def search_usda_database(query: str) -> Optional[dict]:
    url = "https://api.nal.usda.gov/fdc/v1/foods/search"
    params = {
        "api_key": USDA_API_KEY,
        "query": query,
        "pageSize": 2
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client_http:
            resp = await client_http.get(url, params=params)
            if resp.status_code == 200:
                return resp.json()
    except Exception as e:
        logger.warning(f"USDA search error: {e}")
    return None

def get_inventory_usda_macros(inventory_items: list) -> str:
    """Obtiene los macros exactos de la BD, o del USDA si no existen."""
    usda_data = {}
    url = "https://api.nal.usda.gov/fdc/v1/foods/search"
    try:
        with httpx.Client(timeout=10) as client_http:
            for item in inventory_items:
                # Si el item tiene macros exactos guardados (por escáner de boletas, etc)
                if getattr(item, "calories", None) is not None:
                    usda_data[item.name] = {
                        "description": f"{item.name} (MACROS EXACTOS DE BOLETA)",
                        "servingSize": 100,
                        "servingSizeUnit": "g",
                        "nutrients": {
                            "Energy": item.calories,
                            "Protein": getattr(item, "proteins", 0.0),
                            "Total lipid (fat)": getattr(item, "fats", 0.0),
                            "Carbohydrate, by difference": getattr(item, "carbs", 0.0)
                        }
                    }
                    continue

                # Si no tiene macros exactos, buscamos en USDA
                params = {"api_key": USDA_API_KEY, "query": item.name, "pageSize": 1}
                resp = client_http.get(url, params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("foods"):
                        food = data["foods"][0]
                        nutrients = {n.get("nutrientName"): n.get("value") for n in food.get("foodNutrients", []) if n.get("value")}
                        usda_data[item.name] = {
                            "description": food.get("description"),
                            "servingSize": food.get("servingSize", 100),
                            "servingSizeUnit": food.get("servingSizeUnit", "g"),
                            "nutrients": nutrients
                        }
    except Exception as e:
        logger.warning(f"Error fetching USDA for inventory: {e}")
    if not usda_data:
        return "Sin datos nutricionales disponibles."
    return json.dumps(usda_data, ensure_ascii=False)

@router.post("/analyze-food", response_model=schemas.MealDetail)
async def analyze_food(
    text_description: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    current_user: models.User = Depends(security.get_current_user),
):
    if not client:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    if not text_description and not image:
        raise HTTPException(status_code=400, detail="Debe proporcionar texto o imagen")

    content = []
    if text_description:
        content.append(
            {
                "type": "text",
                "text": f"Analiza esta comida: {text_description}",
            }
        )
    else:
        content.append(
            {
                "type": "text",
                "text": "Analiza esta imagen de comida e identifica qué es.",
            }
        )

    if image:
        contents = await image.read()
        base64_image = base64.b64encode(contents).decode("utf-8")
        mime_type = image.content_type or "image/jpeg"
        content.append(
            {
                "type": "image_url",
                "image_url": {"url": f"data:{mime_type};base64,{base64_image}"},
            }
        )

    # 1. Extraer término de búsqueda para USDA
    query_messages = [
        {
            "role": "system",
            "content": "Devuelve ÚNICAMENTE un término de búsqueda corto y preciso (en inglés) para esta comida, ideal para buscar en la base de datos USDA (ej: 'Cooked white rice', 'Grilled chicken breast'). No agregues explicaciones."
        },
        {"role": "user", "content": content}
    ]
    try:
        query_response = client.chat.completions.create(
            model="gpt-4o",
            messages=query_messages,
            max_tokens=30,
        )
        search_query = query_response.choices[0].message.content.strip()
    except Exception as e:
        logger.warning(f"Error en extracción de query: {e}")
        search_query = text_description or "food"

    # 2. Consultar USDA API
    usda_data = await search_usda_database(search_query)
    usda_context = "No se encontraron datos en USDA."
    if usda_data and "foods" in usda_data and len(usda_data["foods"]) > 0:
        # Extraer info relevante para no saturar tokens
        simplified_foods = []
        for food in usda_data["foods"]:
            nutrients = {n.get("nutrientName"): n.get("value") for n in food.get("foodNutrients", []) if n.get("value")}
            simplified_foods.append({
                "description": food.get("description"),
                "servingSize": food.get("servingSize", 100),
                "servingSizeUnit": food.get("servingSizeUnit", "g"),
                "nutrients": nutrients
            })
        usda_context = f"Datos obtenidos de USDA para '{search_query}': {json.dumps(simplified_foods)}"

    # 3. Generar respuesta final con macros exactos basados en USDA
    final_messages = [
        {
            "role": "system",
            "content": f"Eres un nutricionista de élite experto en composición de alimentos. Tu objetivo es devolver los MACROS REALES de la comida que el usuario solicita. Usa OBLIGATORIAMENTE la siguiente información obtenida de la base de datos de la USDA como referencia (ajusta las matemáticas a la porción estimada si es diferente a 100g):\n\n{usda_context}\n\nNO INVENTES DATOS. DEBES devolver macros y calorías EXACTOS y MATEMÁTICAMENTE CORRECTOS. Las calorías totales DEBEN coincidir a la perfección con la ecuación: (1g proteína = 4 kcal, 1g carbs = 4 kcal, 1g grasa = 9 kcal). Responde en formato JSON estricto."
        },
        {"role": "user", "content": content}
    ]

    system_prompt_format = """
FORMATO JSON OBLIGATORIO:
{
  "name": "Nombre de la comida identificada (en español)",
  "ingredients": ["ingrediente 1", "ingrediente 2"],
  "steps": ["Analizado desde foto/texto usando datos reales de USDA."],
  "calories": int,
  "carbs": int,
  "protein": int,
  "fat": int,
  "fiber": float,
  "sugar": float,
  "sodium": int,
  "vitamin_a": float,
  "vitamin_c": float,
  "calcium": float,
  "iron": float,
  "time": "0 min",
  "source_url": "USDA FoodData Central",
  "source_name": "USDA API"
}
"""
    final_messages[0]["content"] += system_prompt_format

    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=final_messages,
            response_format={"type": "json_object"},
            max_tokens=500,
        )

        result_str = response.choices[0].message.content
        result = json.loads(result_str)

        # Enforce exact mathematical calories
        carbs = int(result.get("carbs", 0))
        protein = int(result.get("protein", 0))
        fat = int(result.get("fat", 0))
        result["calories"] = (carbs * 4) + (protein * 4) + (fat * 9)

        # Fallbacks for new fields
        result["vitamin_a"] = float(result.get("vitamin_a", 0.0))
        result["vitamin_c"] = float(result.get("vitamin_c", 0.0))
        result["calcium"] = float(result.get("calcium", 0.0))
        result["iron"] = float(result.get("iron", 0.0))

        return result
    except Exception as e:
        logger.error(f"Error analizando comida: {e}")
        raise HTTPException(status_code=500, detail="Error al analizar la comida")
