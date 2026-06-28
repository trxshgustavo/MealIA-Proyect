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
    else:
        # Crea nuevo con unidad
        db_item = models.InventoryItem(
            name=normalized_name,
            owner_id=current_user.id,
            quantity=item.quantity,
            unit=item.unit,
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
    prompt_sys = """
    Eres un asistente de compras experto. Tu trabajo es sugerir 5 a 10 ingredientes CLAVE que le faltan al usuario para poder cocinar una mayor variedad de recetas saludables y deliciosas, basándote en lo que YA TIENE.
    NO surgieras cosas obvias si ya las tiene.
    
    Devuelve un JSON con el formato:
    {
      "suggestions": [
        {"name": "Ingrediente", "reason": "Razón corta"}
      ]
    }
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
