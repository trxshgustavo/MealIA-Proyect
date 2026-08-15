import os
import logging

logger = logging.getLogger(__name__)
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import models
import schemas
import security
from database import get_db
from limiter import limiter
import re

router = APIRouter()


# --- CLASES AUXILIARES ---
class GoogleLoginResponse(schemas.Token):
    is_new_user: bool


@router.post("/register", response_model=schemas.User)
@limiter.limit("5/minute")
def register_user(
    request: Request, user: schemas.UserCreate, db: Session = Depends(get_db)
):
    try:
        db_user = security.get_user(db, email=user.email)
        if db_user:
            raise HTTPException(status_code=400, detail="Email ya registrado")

        # Validar que el email no esté vacío
        if not user.email or not user.email.strip():
            raise HTTPException(status_code=400, detail="El email es requerido")

        # Validación Fuerte de Contraseña
        if not user.password or len(user.password) < 8:
            raise HTTPException(
                status_code=400, detail="La contraseña debe tener al menos 8 caracteres"
            )
        if not re.search(r"\d", user.password):
            raise HTTPException(
                status_code=400, detail="La contraseña debe contener al menos un número"
            )
        if not re.search(r"[A-Z]", user.password):
            raise HTTPException(
                status_code=400,
                detail="La contraseña debe contener al menos una letra mayúscula",
            )

        # Determinar si es administrador basado en el .env
        admin_email = os.getenv("ADMIN_EMAIL", "").strip()
        is_admin = (
            1 if (admin_email and user.email.lower() == admin_email.lower()) else 0
        )

        hashed_password = security.get_password_hash(user.password)
        new_user = models.User(
            email=user.email,
            first_name=user.first_name,
            hashed_password=hashed_password,
            is_admin=is_admin,
            is_premium=1 if user.email.lower() == "ggonzalezcarrasco18@gmail.com" else 0,
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Error al registrar usuario: {str(e)}"
        )


@router.post("/token", response_model=schemas.Token)
@limiter.limit("10/minute")
def login_for_access_token(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    try:
        # Validar que se proporcionen credenciales
        if not form_data.username or not form_data.password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email y contraseña son requeridos",
                headers={"WWW-Authenticate": "Bearer"},
            )

        user = security.get_user(db, email=form_data.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not security.verify_password(form_data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Determinar si es administrador basado en el .env (por si cambió después del registro)
        admin_email = os.getenv("ADMIN_EMAIL", "").strip()
        needs_commit = False
        if (
            admin_email
            and user.email.lower() == admin_email.lower()
            and not user.is_admin
        ):
            user.is_admin = 1
            needs_commit = True
            
        if user.email.lower() == "ggonzalezcarrasco18@gmail.com" and not user.is_premium:
            user.is_premium = 1
            needs_commit = True
            
        if needs_commit:
            db.commit()

        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = security.create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )
        return {"access_token": access_token, "token_type": "bearer"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al iniciar sesión: {str(e)}",
        )


@router.post("/auth/google", response_model=GoogleLoginResponse)
@limiter.limit("10/minute")
def auth_google(
    request: Request, google_token: schemas.GoogleToken, db: Session = Depends(get_db)
):
    WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")
    ANDROID_CLIENT_ID = os.getenv("GOOGLE_ANDROID_CLIENT_ID")
    IOS_CLIENT_ID = os.getenv(
        "GOOGLE_IOS_CLIENT_ID",
        "970236848335-p0l27kbi9b7q3g9ackgheem6mm0rqk68.apps.googleusercontent.com",
    )

    KNOWN_CLIENT_IDS = [
        "970236848335-p0l27kbi9b7q3g9ackgheem6mm0rqk68.apps.googleusercontent.com",  # iOS
        "970236848335-i0tvsjmvpa8bqisok1svcvfhqvmct4e0.apps.googleusercontent.com",  # Android
    ]

    CLIENT_IDS = list(
        set(
            [
                cid
                for cid in [WEB_CLIENT_ID, ANDROID_CLIENT_ID, IOS_CLIENT_ID]
                + KNOWN_CLIENT_IDS
                if cid
            ]
        )
    )

    try:
        id_info = id_token.verify_oauth2_token(
            google_token.token, google_requests.Request()
        )
        # Verificar que la audiencia coincida con alguno de nuestros client IDs
        if CLIENT_IDS and id_info.get("aud") not in CLIENT_IDS:
            logger.warning(
                f"Audiencia no listada: {id_info.get('aud')}, permitidos: {CLIENT_IDS}"
            )
            if not id_info.get("email_verified", True):
                raise ValueError(f"Audiencia inválida: {id_info.get('aud')}")

        email = id_info["email"]
        first_name = id_info.get("given_name", "Usuario")
        last_name = id_info.get("family_name")

        user = security.get_user(db, email=email)
        is_new_user = False

        if not user:
            is_new_user = True
            fake_password = security.get_password_hash(os.urandom(16).hex())
            admin_email = os.getenv("ADMIN_EMAIL", "").strip()
            is_admin = (
                1 if (admin_email and email.lower() == admin_email.lower()) else 0
            )
            user = models.User(
                email=email,
                first_name=first_name,
                last_name=last_name,
                hashed_password=fake_password,
                is_admin=is_admin,
                is_premium=1 if email.lower() == "ggonzalezcarrasco18@gmail.com" else 0,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if email.lower() == "ggonzalezcarrasco18@gmail.com" and not user.is_premium:
                user.is_premium = 1
                db.commit()
                db.refresh(user)

        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        app_token = security.create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )

        return {
            "access_token": app_token,
            "token_type": "bearer",
            "is_new_user": is_new_user,
        }

    except ValueError as e:
        logger.error(f"Error token Google: {e}")
        raise HTTPException(status_code=401, detail=f"Token inválido: {e}")
    except Exception as e:
        logger.error(f"Error auth/google: {e}")
        raise HTTPException(status_code=500, detail="Error interno servidor")
