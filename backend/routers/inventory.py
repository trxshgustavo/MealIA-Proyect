import os
import json
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
from openai import OpenAI
import models
import schemas
import security
from database import get_db

router = APIRouter()

# Configuración OpenAI
_openai_api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=_openai_api_key) if _openai_api_key else None


@router.post("/inventory", response_model=schemas.InventoryItem)
def add_inventory_item(
    item: schemas.InventoryItemCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    normalized_name = item.name.strip().lower()
    if not normalized_name:
        raise HTTPException(status_code=400, detail="Nombre vacío")

    db_item = (
        db.query(models.InventoryItem)
        .filter(
            models.InventoryItem.owner_id == current_user.id,
            models.InventoryItem.name == normalized_name,
        )
        .first()
    )

    if db_item:
        db_item.quantity += item.quantity  # Suma si existe
        # Actualiza macros si el cliente los envía (útil si escaneó con recibo)
        if item.calories is not None:
            db_item.calories = item.calories
            db_item.proteins = item.proteins
            db_item.fats = item.fats
            db_item.carbs = item.carbs
        # Update category if provided
        if hasattr(item, 'category') and item.category:
            db_item.category = item.category
    else:
        # Crea nuevo con unidad
        db_item = models.InventoryItem(
            name=normalized_name,
            owner_id=current_user.id,
            quantity=item.quantity,
            unit=item.unit,
            category=item.category if hasattr(item, 'category') else "Otros",
            calories=item.calories,
            proteins=item.proteins,
            fats=item.fats,
            carbs=item.carbs,
        )
        db.add(db_item)

    db.commit()
    db.refresh(db_item)
    return db_item


@router.put("/inventory/{item_name}", response_model=schemas.InventoryItem)
def update_inventory_item(
    item_name: str,
    item_update: schemas.InventoryItemUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    normalized_name = item_name.strip().lower()
    db_item = (
        db.query(models.InventoryItem)
        .filter(
            models.InventoryItem.owner_id == current_user.id,
            models.InventoryItem.name == normalized_name,
        )
        .first()
    )

    if not db_item:
        raise HTTPException(status_code=404, detail="Ítem no encontrado")

    # Actualiza valores
    db_item.quantity = item_update.quantity
    db_item.unit = item_update.unit
    if hasattr(item_update, 'category') and item_update.category:
        db_item.category = item_update.category
    if item_update.calories is not None:
        db_item.calories = item_update.calories
    if item_update.proteins is not None:
        db_item.proteins = item_update.proteins
    if item_update.fats is not None:
        db_item.fats = item_update.fats
    if item_update.carbs is not None:
        db_item.carbs = item_update.carbs

    db.commit()
    db.refresh(db_item)
    return db_item


@router.post("/inventory/decrement/{item_name}")
def decrement_inventory_item(
    item_name: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    db_item = (
        db.query(models.InventoryItem)
        .filter(
            models.InventoryItem.owner_id == current_user.id,
            models.InventoryItem.name == item_name,
        )
        .first()
    )
    if not db_item:
        raise HTTPException(status_code=404, detail="No encontrado")

    if db_item.quantity > 1:
        db_item.quantity -= 1
        db.commit()
        db.refresh(db_item)
        return {
            "name": db_item.name,
            "quantity": db_item.quantity,
            "unit": db_item.unit,
            "id": db_item.id,
            "owner_id": db_item.owner_id,
        }
    else:
        db.delete(db_item)
        db.commit()
        return {"detail": "Eliminado", "deleted": True}


@router.delete("/inventory/remove/{item_name}")
def remove_inventory_item(
    item_name: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    db_item = (
        db.query(models.InventoryItem)
        .filter(
            models.InventoryItem.owner_id == current_user.id,
            models.InventoryItem.name == item_name,
        )
        .first()
    )
    if not db_item:
        raise HTTPException(status_code=404, detail="No encontrado")

    db.delete(db_item)
    db.commit()
    return {"detail": "Eliminado"}


@router.get("/inventory", response_model=list[schemas.InventoryItem])
def get_inventory(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    return (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.owner_id == current_user.id)
        .all()
    )


@router.post("/inventory/suggest", response_model=schemas.ShoppingSuggestionResponse)
def suggest_shopping_list(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    import logging
    logger = logging.getLogger(__name__)

    # 1. Obtener inventario actual
    inventory = (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.owner_id == current_user.id)
        .all()
    )
    inv_names = [i.name.strip() for i in inventory if i.name and i.name.strip()]
    inventory_str = ", ".join(inv_names) if inv_names else "Inventario vacío"
    user_goal = current_user.goal or "Mantenimiento y Salud"

    def get_fallback_suggestions():
        goal_lower = user_goal.lower()
        existing = {n.lower() for n in inv_names}
        
        candidates = []
        if "déficit" in goal_lower or "deficit" in goal_lower or "bajar" in goal_lower:
            candidates = [
                {"name": "Espinacas frescas", "reason": "Bajas en calorías y altas en volumen y fibra para máxima saciedad."},
                {"name": "Pechuga de pollo o pavo", "reason": "Proteína magra para preservar masa muscular durante el déficit calórico."},
                {"name": "Huevos", "reason": "Fuente completa de proteína y grasas saludables que controlan el apetito."},
                {"name": "Frutos rojos (frutillas/arándanos)", "reason": "Frutas bajas en azúcar y ricas en antioxidantes."},
                {"name": "Yogurt griego descremado", "reason": "Excelente colación saciante alta en proteína."},
                {"name": "Avena integral", "reason": "Carbohidratos complejos de absorción lenta que dan energía sostenida."},
                {"name": "Zapallo italiano o calabacín", "reason": "Muy versátil y de bajísima densidad calórica para tus comidas."}
            ]
        elif "músculo" in goal_lower or "muscular" in goal_lower or "ganar" in goal_lower or "masa" in goal_lower:
            candidates = [
                {"name": "Huevos", "reason": "Proteína de alto valor biológico indispensable para la síntesis muscular."},
                {"name": "Avena integral", "reason": "Energía limpia y carbohidratos densos para entrenamientos intensos."},
                {"name": "Pechuga de pollo", "reason": "Proteína magra de rápida asimilación para el desarrollo muscular."},
                {"name": "Plátanos / Bananas", "reason": "Excelente recarga de glucógeno y potasio post-entrenamiento."},
                {"name": "Mantequilla de maní o frutos secos", "reason": "Calorías y grasas monoinsaturadas densas para apoyar el superávit."},
                {"name": "Atún al agua o salmón", "reason": "Rico en ácidos grasos Omega-3 y proteína de calidad."},
                {"name": "Arroz blanco o integral", "reason": "Base de carbohidratos de fácil digestión para ganar masa."}
            ]
        else:
            candidates = [
                {"name": "Aceite de oliva virgen extra", "reason": "Grasas cardiosaludables esenciales para la absorción de vitaminas."},
                {"name": "Huevos", "reason": "Alimento completo y versátil para cualquier momento del día."},
                {"name": "Lentejas o garbanzos", "reason": "Legumbres ricas en fibra vegetal, hierro y proteína."},
                {"name": "Manzanas o frutas de estación", "reason": "Aporte diario de micronutrientes, fibra y frescura."},
                {"name": "Pechuga de pollo", "reason": "Proteína limpia para mantener tus requerimientos diarios."},
                {"name": "Verduras mixtas (brócoli/zanahoria)", "reason": "Vitaminas y minerales clave para tu sistema inmunológico."},
                {"name": "Frutos secos variados", "reason": "Snack saludable y fuente de energía natural."}
            ]

        filtered = [c for c in candidates if not any(c["name"].lower() in e or e in c["name"].lower() for e in existing)]
        return {"suggestions": filtered[:6] if filtered else candidates[:5]}

    if client is None:
        return get_fallback_suggestions()

    # 2. Prompt para OpenAI
    prompt_sys = f"""
Eres un Nutricionista y Chef experto. Tu trabajo es sugerir 5 a 7 ingredientes CLAVE que le faltan al usuario en su despensa para complementar lo que YA TIENE y potenciar su objetivo de salud.
NO sugieras ingredientes que el usuario ya tenga en su inventario.

Objetivo de salud del usuario: "{user_goal}".
Inventario actual: [{inventory_str}].

Devuelve ÚNICAMENTE un JSON estrictamente válido en este formato:
{{
  "suggestions": [
    {{"name": "Nombre del alimento", "reason": "Razón corta y motivadora alineada a su objetivo"}}
  ]
}}
"""

    prompt_user = f"Mi objetivo es '{user_goal}'. Revisa lo que tengo [{inventory_str}] y dime qué 5 a 7 alimentos específicos debería comprar en el supermercado para mis recetas y salud."

    try:
        completion = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": prompt_sys},
                {"role": "user", "content": prompt_user},
            ],
            response_format={"type": "json_object"},
            temperature=0.6,
            max_tokens=600,
        )
        content = completion.choices[0].message.content.strip()
        cleaned = content.replace("```json", "").replace("```", "").strip()
        data = json.loads(cleaned)

        suggestions = []
        if isinstance(data, dict):
            raw_sugg = data.get("suggestions") or data.get("sugerencias") or data.get("items") or []
            if isinstance(raw_sugg, list):
                for s in raw_sugg:
                    if isinstance(s, dict) and "name" in s and "reason" in s:
                        suggestions.append({"name": str(s["name"]), "reason": str(s["reason"])})
                    elif isinstance(s, dict) and "nombre" in s and "razon" in s:
                        suggestions.append({"name": str(s["nombre"]), "reason": str(s["razon"])})

        if suggestions:
            return {"suggestions": suggestions}
        return get_fallback_suggestions()
    except Exception as e:
        logger.error(f"Error IA Shopping: {e}")
        return get_fallback_suggestions()


@router.post("/inventory/scan-fridge")
async def scan_fridge(
    image: UploadFile = File(...),
    current_user: models.User = Depends(security.get_current_user),
):
    import logging
    import base64
    logger = logging.getLogger(__name__)

    if not client:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    try:
        contents = await image.read()
        base64_image = base64.b64encode(contents).decode("utf-8")
        mime_type = image.content_type or "image/jpeg"

        prompt = (
            "Analiza la imagen minuciosamente y detecta el alimento o producto principal que se está escaneando.\n"
            "Si es una etiqueta nutricional, extrae los valores exactos por porción.\n"
            "Devuelve ÚNICAMENTE un JSON ARRAY estrictamente válido en este formato exacto:\n"
            "[\n"
            "  {\n"
            '    "alimento": "Nombre descriptivo del producto en español",\n'
            '    "cantidad_estimada": 1.0,\n'
            '    "unidad_estimada": "Unidades/Kg/g/L/ml/paquete",\n'
            '    "calorias": 100,\n'
            '    "calorias_exactas": 100.0,\n'
            '    "proteinas": 5.0,\n'
            '    "grasas": 2.0,\n'
            '    "carbohidratos": 15.0,\n'
            '    "info": "Breve descripción"\n'
            "  }\n"
            "]\n"
            "REGLAS:\n"
            "1. Enfócate en el alimento principal o empaque. Si hay varios claros, lístalos por separado.\n"
            "2. Estima la cantidad real. Extrae u estima macros (calorias_exactas, proteinas, grasas, carbohidratos) en base a la porción estimada.\n"
            "3. Usa 'Unidades' si es contable. Usa 'g' o 'Kg' si es peso. Usa 'L' o 'ml' para líquidos.\n"
            "4. Si es imposible calcular macros, usa null.\n"
            "5. Si no ves alimentos, devuelve []."
        )

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:{mime_type};base64,{base64_image}"},
                        },
                    ],
                }
            ],
            response_format={"type": "json_object"} if False else None,
            max_tokens=1000,
        )

        raw_text = response.choices[0].message.content.strip()
        cleaned = raw_text.replace("```json", "").replace("```", "").strip()
        
        try:
            items = json.loads(cleaned)
            if isinstance(items, dict) and "items" in items:
                items = items["items"]
            elif isinstance(items, dict) and "alimentos" in items:
                items = items["alimentos"]
            if not isinstance(items, list):
                items = []
        except Exception:
            items = []

        return {"items": items}
    except Exception as e:
        logger.error(f"Error escaneando refrigerador con IA: {e}")
        raise HTTPException(status_code=500, detail="Error al escanear la imagen")


@router.post("/inventory/scan-receipt")
async def scan_receipt(
    image: UploadFile = File(...),
    current_user: models.User = Depends(security.get_current_user),
):
    import logging
    import base64
    import httpx
    logger = logging.getLogger(__name__)

    if not client:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")

    try:
        contents = await image.read()
        base64_image = base64.b64encode(contents).decode("utf-8")
        mime_type = image.content_type or "image/jpeg"

        prompt = (
            "Analiza esta imagen de una boleta de supermercado.\n"
            "Tu objetivo es extraer los nombres de los productos alimenticios y cualquier código numérico o de barras impreso.\n"
            "Devuelve ÚNICAMENTE un JSON ARRAY estrictamente válido en este formato exacto:\n"
            "[\n"
            "  {\n"
            '    "codigo_barras": "1234567890123 o vacío si no hay",\n'
            '    "alimento": "Nombre del producto en español",\n'
            '    "cantidad_estimada": 1.0,\n'
            '    "unidad_estimada": "Unidades"\n'
            "  }\n"
            "]\n"
            "Si no encuentras productos, devuelve []."
        )

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:{mime_type};base64,{base64_image}"},
                        },
                    ],
                }
            ],
            max_tokens=1000,
        )

        raw_text = response.choices[0].message.content.strip()
        cleaned = raw_text.replace("```json", "").replace("```", "").strip()
        
        try:
            detected = json.loads(cleaned)
            if isinstance(detected, dict) and "items" in detected:
                detected = detected["items"]
            if not isinstance(detected, list):
                detected = []
        except Exception:
            detected = []

        # Enriquecer con OpenFoodFacts si hay códigos de barra
        final_items = []
        async with httpx.AsyncClient(timeout=8) as http_c:
            for it in detected:
                barcode = str(it.get("codigo_barras", "")).strip()
                name = it.get("alimento", "")
                qty = float(it.get("cantidad_estimada", 1.0))
                unit = it.get("unidad_estimada", "Unidades")
                cals = 100
                carbs = 10
                prot = 5
                fat = 2

                if barcode and barcode.isdigit() and len(barcode) >= 6:
                    try:
                        off_url = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
                        off_resp = await http_c.get(off_url)
                        if off_resp.status_code == 200:
                            off_data = off_resp.json()
                            if off_data.get("status") == 1 and "product" in off_data:
                                p = off_data["product"]
                                p_name = p.get("product_name_es") or p.get("product_name") or name
                                brand = p.get("brands", "")
                                name = f"{brand} - {p_name}".strip(" -")
                                nut = p.get("nutriments", {})
                                cals = int(float(nut.get("energy-kcal_100g") or nut.get("energy-kcal") or 100))
                                carbs = int(float(nut.get("carbohydrates_100g") or 10))
                                prot = int(float(nut.get("proteins_100g") or 5))
                                fat = int(float(nut.get("fat_100g") or 2))
                    except Exception:
                        pass

                final_items.append({
                    "alimento": name,
                    "codigo_barras": barcode,
                    "cantidad_estimada": qty,
                    "unidad_estimada": unit,
                    "calorias": cals,
                    "carbs": carbs,
                    "proteinas": prot,
                    "grasas": fat,
                })

        return {"items": final_items}
    except Exception as e:
        logger.error(f"Error escaneando boleta con IA: {e}")
        raise HTTPException(status_code=500, detail="Error al escanear la boleta")
