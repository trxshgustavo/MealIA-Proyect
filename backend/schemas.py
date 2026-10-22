from pydantic import BaseModel, EmailStr, Field, field_validator, ConfigDict
from typing import List, Optional
from datetime import datetime
import re


def validate_password_strength(value: str) -> str:
    if len(value) < 8 or not re.search(r"[A-Z]", value) or not re.search(r"\d", value):
        raise ValueError("La contraseña debe tener 8 caracteres, una mayúscula y un número")
    return value


# --- Inventory ---
class InventoryItemBase(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: float = Field(default=1.0, gt=0, allow_inf_nan=False)
    unit: str = Field(default="Unidades", min_length=1, max_length=32)
    category: str = "Otros"
    calories: Optional[float] = None
    proteins: Optional[float] = None
    fats: Optional[float] = None
    carbs: Optional[float] = None


class InventoryItemCreate(InventoryItemBase):
    pass  # Solo necesitamos el nombre para crearlo/incrementarlo


class InventoryItemUpdate(BaseModel):  # <--- NUEVO ESQUEMA PARA EL PUT
    quantity: float = Field(ge=0, allow_inf_nan=False)
    unit: str = Field(min_length=1, max_length=32)
    category: str = "Otros"
    calories: Optional[float] = None
    proteins: Optional[float] = None
    fats: Optional[float] = None
    carbs: Optional[float] = None


class InventoryItem(InventoryItemBase):
    id: int
    owner_id: int
    quantity: float  # Debe coincidir con el modelo SQLAlchemy (Float)

    model_config = ConfigDict(from_attributes=True)


# --- User ---
class UserBase(BaseModel):
    email: EmailStr
    first_name: Optional[str] = None
    last_name: str | None = None
    gender: Optional[str] = None


class UserCreate(UserBase):
    password: str

    _validate_password = field_validator("password")(validate_password_strength)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value):
        return value.strip().lower() if isinstance(value, str) else value


class UserDataUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    birthdate: Optional[datetime] = None
    goal: Optional[str] = None
    gender: Optional[str] = None
    photo_url: Optional[str] = None
    meals_per_day: Optional[int] = Field(default=None, ge=3, le=5)
    meal_times: Optional[dict] = None


class UserPasswordUpdate(BaseModel):
    password: str

    _validate_password = field_validator("password")(validate_password_strength)


class User(UserBase):
    id: int
    height: Optional[float] = None
    weight: Optional[float] = None
    birthdate: Optional[datetime] = None
    goal: Optional[str] = None
    inventory_items: List[InventoryItem] = []
    photo_url: str | None = None
    is_premium: bool = False
    is_admin: bool = False
    meals_per_day: int = 3
    meal_times: Optional[dict] = None

    model_config = ConfigDict(from_attributes=True)


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
    ingredients: Optional[List[str]] = []
    steps: Optional[List[str]] = []
    calories: int = 0
    # Macros
    carbs: int = 0
    protein: int = 0
    fat: int = 0
    # Micros
    fiber: Optional[float] = 0.0
    sugar: Optional[float] = 0.0
    sodium: Optional[int] = 0
    vitamin_a: Optional[float] = 0.0  # mcg RAE
    vitamin_c: Optional[float] = 0.0  # mg
    calcium: Optional[float] = 0.0  # mg
    iron: Optional[float] = 0.0  # mg
    # Time
    time: Optional[str] = "5 min"
    eating_time: Optional[str] = None
    # Respaldo / Fuente real de la receta
    source_url: Optional[str] = None  # URL de la receta original
    source_name: Optional[str] = None  # Nombre de la fuente (TheMealDB, Edamam, USDA)
    eaten: Optional[bool] = True


class GenerateMenuRequest(BaseModel):
    rejected_recipes: List[str] = []

class MenuGenerationResponse(BaseModel):
    breakfast: MealDetail
    lunch: MealDetail
    dinner: MealDetail
    extra_meals: List[MealDetail] = []
    note: str
    total_calories: int


class WeeklyMenuResponse(BaseModel):
    days: List[MenuGenerationResponse]


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

    model_config = ConfigDict(from_attributes=True)


# --- Meal Plan ---
class MealPlanCreate(BaseModel):
    date: str  # YYYY-MM-DD
    breakfast: MealDetail
    lunch: MealDetail
    dinner: MealDetail
    extra_meals: Optional[List[MealDetail]] = []
    breakfast_eaten: Optional[bool] = False
    lunch_eaten: Optional[bool] = False
    dinner_eaten: Optional[bool] = False
    total_calories: int


class MealPlan(BaseModel):
    id: int
    date: datetime  # Override: DB stores as DateTime, not str
    breakfast: MealDetail
    lunch: MealDetail
    dinner: MealDetail
    total_calories: int

    # Nuevos campos de tracking
    breakfast_eaten: bool = False
    lunch_eaten: bool = False
    dinner_eaten: bool = False
    extra_meals: List[MealDetail] = []

    owner_id: int

    model_config = ConfigDict(from_attributes=True)


# --- Shopping Suggestion ---
class ShoppingSuggestionItem(BaseModel):
    name: str
    reason: str  # Por qué se sugiere (ej: "Para hacer Lasagna")


class ShoppingSuggestionResponse(BaseModel):
    suggestions: List[ShoppingSuggestionItem]


# --- Tracking ---
class MarkMealEatenRequest(BaseModel):
    meal_type: str  # "breakfast", "lunch", "dinner"
    eaten: bool


class MarkMealEatenResponse(BaseModel):
    plan: MealPlan
    depleted_items: List[str] = []


class AnalyzeFoodRequest(BaseModel):
    text_description: Optional[str] = None
    # If image, it will come as multipart form data


class ExtraMealCreate(MealDetail):
    pass
