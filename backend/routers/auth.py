import os
import logging

logger = logging.getLogger(__name__)
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import models
import schemas
import security
from database import get_db

router = APIRouter()

# --- CLASES AUXILIARES ---
class GoogleLoginResponse(schemas.Token):
    is_new_user: bool

@router.post("/register", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    try:
        db_user = security.get_user(db, email=user.email)
        if db_user:
            raise HTTPException(status_code=400, detail="Email ya registrado")
        
        # Validar que el email no esté vacío
        if not user.email or not user.email.strip():
            raise HTTPException(status_code=400, detail="El email es requerido")
        
        # Validar que la contraseña tenga al menos 6 caracteres
        if not user.password or len(user.password) < 6:
            raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 6 caracteres")
        
        hashed_password = security.get_password_hash(user.password)
        new_user = models.User(email=user.email, first_name=user.first_name, hashed_password=hashed_password)
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al registrar usuario: {str(e)}")

@router.post("/token", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    try:
        # Validar que se proporcionen credenciales
        if not form_data.username or not form_data.password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email y contraseña son requeridos",
                headers={"WWW-Authenticate": "Bearer"}
            )
        
        user = security.get_user(db, email=form_data.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"}
            )
        
        if not security.verify_password(form_data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"}
            )
        
        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = security.create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
        return {"access_token": access_token, "token_type": "bearer"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al iniciar sesión: {str(e)}"
        )

@router.post("/auth/google", response_model=GoogleLoginResponse) 
def auth_google(google_token: schemas.GoogleToken, db: Session = Depends(get_db)):
    WEB_CLIENT_ID = os.getenv("GOOGLE_WEB_CLIENT_ID")
    ANDROID_CLIENT_ID = os.getenv("GOOGLE_ANDROID_CLIENT_ID")
    
    # Debug logging to help diagnosis if it fails
    if not WEB_CLIENT_ID: logger.warning("GOOGLE_WEB_CLIENT_ID not set")
    if not ANDROID_CLIENT_ID: logger.warning("GOOGLE_ANDROID_CLIENT_ID not set")
    
    if not WEB_CLIENT_ID or not ANDROID_CLIENT_ID: 
        raise HTTPException(status_code=500, detail="IDs de Google no configurados en el servidor")
    
    CLIENT_IDS = [WEB_CLIENT_ID, ANDROID_CLIENT_ID]
    
    try:
        id_info = id_token.verify_oauth2_token(google_token.token, google_requests.Request())
        # Verificar que la audiencia coincida con alguno de nuestros client IDs
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
            user = models.User(email=email, first_name=first_name, last_name=last_name, hashed_password=fake_password)
            db.add(user)
            db.commit()
            db.refresh(user)
        
        access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
        app_token = security.create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
        
        return {"access_token": app_token, "token_type": "bearer", "is_new_user": is_new_user}
        
    except ValueError as e:
        logger.error(f"Error token Google: {e}")
        raise HTTPException(status_code=401, detail=f"Token inválido: {e}")
    except Exception as e:
        logger.error(f"Error auth/google: {e}")
        raise HTTPException(status_code=500, detail="Error interno servidor")
