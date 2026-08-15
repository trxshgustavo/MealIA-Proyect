import os
import json
from fastapi import APIRouter, Depends, HTTPException
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
    else:
        # Crea nuevo con unidad
        db_item = models.InventoryItem(
            name=normalized_name,
            owner_id=current_user.id,
            quantity=item.quantity,
            unit=item.unit,
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
    if client is None:
        raise HTTPException(status_code=503, detail="Servicio de IA no configurado")
    if not current_user.is_premium:
        raise HTTPException(status_code=403, detail="Requiere suscripción Premium")

    # 1. Obtener inventario actual
    inventory = (
        db.query(models.InventoryItem)
        .filter(models.InventoryItem.owner_id == current_user.id)
        .all()
    )
    inv_names = [i.name for i in inventory]
    inventory_str = ", ".join(inv_names) if inv_names else "Nada"

    # 2. Prompt para OpenAI
    prompt_sys = f"""
    Eres un asistente de compras experto. Tu trabajo es sugerir 5 a 10 ingredientes CLAVE que le faltan al usuario para poder cocinar una mayor variedad de recetas saludables y deliciosas, basándote en lo que YA TIENE.
    NO sugieras cosas obvias si ya las tiene.
    
    El objetivo de salud/nutricional del usuario es: "{current_user.goal}".
    Tus sugerencias DEBEN estar directamente alineadas con este objetivo. Por ejemplo, si busca ganar masa muscular, sugiere alimentos altos en proteína. Si busca déficit, sugiere vegetales de baja densidad calórica, etc.
    
    Devuelve un JSON con el formato:
    {{
      "suggestions": [
        {{"name": "Ingrediente", "reason": "Razón corta relacionada al objetivo"}}
      ]
    }}
    """

    prompt_user = f"Mi inventario actual es: [{inventory_str}]. ¿Qué debería comprar para complementar esto y cocinar mejor?"

    try:
        completion = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": prompt_sys},
                {"role": "user", "content": prompt_user},
            ],
            temperature=0.7,
        )
        content = completion.choices[0].message.content
        data = json.loads(content)
        return data
    except Exception as e:
        import logging

        logging.getLogger(__name__).error(f"Error IA Shopping: {e}")
        raise HTTPException(status_code=500, detail="Error generando sugerencias")


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
            "Analiza la imagen minuciosamente y detecta todos los alimentos o productos presentes.\n"
            "Devuelve ÚNICAMENTE un JSON ARRAY estrictamente válido en este formato exacto:\n"
            "[\n"
            "  {\n"
            '    "alimento": "Nombre del producto en español",\n'
            '    "cantidad_estimada": 1.0,\n'
            '    "unidad_estimada": "Unidades/Kg/g/L/ml/paquete",\n'
            '    "calorias": 100,\n'
            '    "info": "Breve descripción"\n'
            "  }\n"
            "]\n"
            "REGLAS:\n"
            "1. Diferencia claramente entre productos (ej: no agrupes 'frutas', lista 'manzana', 'plátano' por separado).\n"
            "2. Estima la cantidad con la mayor exactitud posible basándote en el tamaño relativo.\n"
            "3. Usa 'Unidades' si es contable. Usa 'g' o 'Kg' si es peso. Usa 'L' o 'ml' para líquidos.\n"
            "4. Si no ves alimentos, devuelve []."
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
