import os
import logging
import shutil
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
import models
import schemas
import security
from database import get_db

logger = logging.getLogger(__name__)

router = APIRouter()


class PhotoResponse(BaseModel):
    photo_url: str


@router.get("/users/me", response_model=schemas.User)
def read_users_me(current_user: models.User = Depends(security.get_current_user)):
    return current_user


@router.put("/users/me/data", response_model=schemas.User)
def update_user_data(
    data: schemas.UserDataUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
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
    if data.photo_url is not None:
        current_user.photo_url = data.photo_url
    if data.meals_per_day is not None:
        current_user.meals_per_day = data.meals_per_day
    if data.meal_times is not None:
        current_user.meal_times = data.meal_times
    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/users/me/password")
def update_password(
    data: schemas.UserPasswordUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    hashed_password = security.get_password_hash(data.password)
    current_user.hashed_password = hashed_password
    db.commit()
    return {"detail": "Contraseña actualizada correctamente"}


@router.post("/subscription/upgrade", response_model=schemas.User)
def upgrade_subscription(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    current_user.is_premium = 1  # True
    db.commit()
    db.refresh(current_user)
    return current_user


# --- GESTIÓN DE FOTOS ---


@router.post("/users/me/upload-photo", response_model=PhotoResponse)
async def upload_profile_photo(
    request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    allowed_types = [
        "image/jpeg",
        "image/png",
        "image/heic",
        "image/webp",
        "application/octet-stream",
    ]
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Archivo no válido")

    file_extension = file.filename.split(".")[-1]
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = f"uploads/{unique_filename}"

    # Ensure uploads directory exists (should be created in main, but good to ensure)
    os.makedirs("uploads", exist_ok=True)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception:
        raise HTTPException(status_code=500, detail="Error al guardar")
    finally:
        file.file.close()

    full_photo_url = f"{str(request.base_url)}{file_path}"
    # Fix for double slash if any
    # full_photo_url = full_photo_url.replace("//uploads", "/uploads") # Not needed if standard base_url has trailing slash?

    current_user.photo_url = full_photo_url
    db.commit()
    return {"photo_url": full_photo_url}


@router.delete("/users/me/delete-photo", response_model=schemas.User)
async def delete_profile_photo(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    if current_user.photo_url:
        try:
            filename = current_user.photo_url.split("/")[-1]
            path = f"uploads/{filename}"
            if os.path.exists(path):
                os.remove(path)
        except Exception as e:
            logger.warning(f"Error deleting photo: {e}")
    current_user.photo_url = None
    db.commit()
    return current_user


@router.delete("/users/me")
def delete_user_account(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    """Delete the current user's account and all associated data."""
    try:
        # 1. Delete inventory items
        db.query(models.InventoryItem).filter(
            models.InventoryItem.owner_id == current_user.id
        ).delete()

        # 2. Delete saved recipes
        db.query(models.SavedRecipe).filter(
            models.SavedRecipe.owner_id == current_user.id
        ).delete()

        # 3. Delete meal plans
        db.query(models.MealPlan).filter(
            models.MealPlan.owner_id == current_user.id
        ).delete()

        # 4. Delete profile photo file
        if current_user.photo_url:
            try:
                filename = current_user.photo_url.split("/")[-1]
                path = f"uploads/{filename}"
                if os.path.exists(path):
                    os.remove(path)
            except Exception:
                pass

        # 5. Delete user
        db.delete(current_user)
        db.commit()

        return {"detail": "Cuenta eliminada exitosamente"}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Error eliminando cuenta: {str(e)}"
        )
