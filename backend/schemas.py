from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict
from datetime import datetime

# --- Inventory ---
class InventoryItemBase(BaseModel):
    name: str

class InventoryItemCreate(InventoryItemBase):
    pass # Solo necesitamos el nombre para crearlo/incrementarlo

class InventoryItem(InventoryItemBase):
    id: int
    owner_id: int
    quantity: int # ¡Debe devolver la cantidad!

    class Config:
        from_attributes = True # Permite a Pydantic leer modelos de SQLAlchemy

# --- User ---
class UserBase(BaseModel):
    email: EmailStr
    first_name: Optional[str] = None
    last_name: str | None = None

class UserCreate(UserBase):
    password: str

class UserDataUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    birthdate: Optional[datetime] = None
    goal: Optional[str] = None

class User(UserBase):
    id: int
    height: Optional[float] = None
    weight: Optional[float] = None
    birthdate: Optional[datetime] = None
    goal: Optional[str] = None
    inventory_items: List[InventoryItem] = []
    photo_url: str | None = None

    class Config:
        from_attributes = True

# --- Auth ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- IA Menu Generation ---
# Define la estructura JSON que esperamos de OpenAI
class MealDetail(BaseModel):
    name: str
    ingredients: List[str]
    steps: List[str]
    calories: int

class MenuGenerationResponse(BaseModel):
    breakfast: MealDetail
    lunch: MealDetail
    dinner: MealDetail
    note: str
    total_calories: int
    
class GoogleToken(BaseModel):
    token: str
    
class SavedRecipeCreate(BaseModel):
    name: str
    ingredients: List[str]
    steps: List[str]
    calories: int

class SavedRecipe(SavedRecipeCreate):
    id: int
    owner_id: int

    class Config:
        from_attributes = True