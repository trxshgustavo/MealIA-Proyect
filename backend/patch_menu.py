import re

file_path = r"c:\Users\ggonz\MealIA\backend\routers\menu.py"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update Calorie Distribution
old_cal_dist = """    # Distribucion calorica por comida
    breakfast_cal_target = int(target_calories * 0.25)
    lunch_cal_target = int(target_calories * 0.40)
    dinner_cal_target = int(target_calories * 0.35)
    cal_margin = 150  # +/- kcal aceptable"""

new_cal_dist = """    # Distribucion calorica por comida
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
    cal_margin = 150  # +/- kcal aceptable"""

content = content.replace(old_cal_dist, new_cal_dist)

# 2. Update System Prompt (eating times)
old_system_prompt_intro = """=== PERFIL DEL USUARIO ===
Nombre: {current_user.first_name}
Objetivo de calorias: {target_calories} kcal totales al dia
  - Desayuno: ~{breakfast_cal_target} kcal
  - Almuerzo: ~{lunch_cal_target} kcal (comida principal)
  - Cena: ~{dinner_cal_target} kcal"""

new_system_prompt_intro = """=== PERFIL DEL USUARIO ===
Nombre: {current_user.first_name}
Objetivo de calorias: {target_calories} kcal totales al dia (Distribuido en {meals_per_day} comidas)
Horarios configurados por el usuario: {current_user.meal_times or 'Predeterminados'}
**INSTRUCCION CRITICA**: Debes asegurar de poner la hora correspondiente en el campo "eating_time" de cada comida generada, usando el horario configurado por el usuario para esa comida."""

content = content.replace(old_system_prompt_intro, new_system_prompt_intro)

# 3. Update Prompt Del Usuario (Adding extra meals to JSON schema and eating_time)
old_json_format = """FORMATO JSON OBLIGATORIO:
{
  "breakfast": {
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
  },
  "lunch": {
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
  },
  "dinner": {
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
  },
  "note": "Nota motivadora del Chef para el objetivo de salud de {current_user.first_name}.",
  "total_calories": 0
}"""

new_json_format = """FORMATO JSON OBLIGATORIO:
{
  "breakfast": {
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
    "eating_time": "HH:MM",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  },
  "lunch": {
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
    "eating_time": "HH:MM",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  },
  "dinner": {
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
    "eating_time": "HH:MM",
    "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
    "source_name": "TheMealDB"
  },
  "extra_meals": [
    {
      "name": "Colacion 1 (Solo si el usuario come 4 o 5 comidas)",
      "ingredients": ["..."],
      "steps": ["..."],
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
      "eating_time": "HH:MM",
      "source_url": "URL_EXACTA_DE_LA_OPCION_ELEGIDA",
      "source_name": "TheMealDB"
    }
  ],
  "note": "Nota motivadora del Chef para el objetivo de salud de {current_user.first_name}.",
  "total_calories": 0
}
- NOTA: Si meals_per_day es 4, debes agregar 1 comida en extra_meals. Si es 5, debes agregar 2 comidas en extra_meals. Si es 3, extra_meals debe estar vacio []."""

content = content.replace(old_json_format, new_json_format)

# 4. Instruction modification
old_instruction = """2. Objetivo calorico: desayuno ~{breakfast_cal_target} kcal, almuerzo ~{lunch_cal_target} kcal, cena ~{dinner_cal_target} kcal."""
new_instruction = """2. Objetivo calorico: Debes distribuir las calorias considerando la configuracion de {meals_per_day} comidas del usuario. (ej. Desayuno ~{breakfast_cal_target} kcal, Almuerzo ~{lunch_cal_target} kcal, Cena ~{dinner_cal_target} kcal, y el resto en extra_meals)."""
content = content.replace(old_instruction, new_instruction)

# 5. Adding extra_meals validation in the validation step
old_validation_start = """            # ── 8. SANITIZACION Y VALIDACION ─────────────────────────────────────
            for meal_name, meal_cal_target, meal_candidates in [
                ("breakfast", breakfast_cal_target, breakfast_candidates),
                ("lunch", lunch_cal_target, lunch_candidates),
                ("dinner", dinner_cal_target, dinner_candidates),
            ]:"""

new_validation_start = """            # ── 8. SANITIZACION Y VALIDACION ─────────────────────────────────────
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
                        menu_data[meal_name] = meal"""

content = content.replace(old_validation_start, new_validation_start)


# 6. Total calories addition needs to include extra meals
old_total_cals = """            # Total de calorias
            total = (
                menu_data["breakfast"]["calories"]
                + menu_data["lunch"]["calories"]
                + menu_data["dinner"]["calories"]
            )"""

new_total_cals = """            # Total de calorias
            total = (
                menu_data["breakfast"]["calories"]
                + menu_data["lunch"]["calories"]
                + menu_data["dinner"]["calories"]
                + sum(m.get("calories", 0) for m in menu_data["extra_meals"])
            )"""

content = content.replace(old_total_cals, new_total_cals)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("menu.py updated successfully.")
