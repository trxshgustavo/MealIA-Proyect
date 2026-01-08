from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict
from datetime import datetime

# --- Inventory ---
class InventoryItemBase(BaseModel):
    name: str
    quantity: float = 1.0
    unit: str = "Unidades"

class InventoryItemCreate(InventoryItemBase):
    pass # Solo necesitamos el nombre para crearlo/incrementarlo

class InventoryItemUpdate(BaseModel): # <--- NUEVO ESQUEMA PARA EL PUT
    quantity: float
    unit: str

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
    photo_url: Optional[str] = None

class UserPasswordUpdate(BaseModel):
    password: str

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
    # Macros
    carbs: int
    protein: int
    fat: int
    # Micros
    fiber: float
    sugar: float
    sodium: int
    # Time
    time: str

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