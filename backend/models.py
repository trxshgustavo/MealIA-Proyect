from sqlalchemy import Column, Integer, String, ForeignKey, Float, DateTime, JSON
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String)
    last_name = Column(String, nullable=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)

    height = Column(Float, nullable=True)  # metros
    weight = Column(Float, nullable=True)  # kg
    birthdate = Column(DateTime, nullable=True)
    goal = Column(String, default="Mantenimiento")
    photo_url = Column(String, nullable=True)
    is_premium = Column(Integer, default=0)  # 0: Free, 1: Premium
    is_admin = Column(Integer, default=0)  # 0: User, 1: Admin
    inventory_items = relationship("InventoryItem", back_populates="owner")
    saved_recipes = relationship("SavedRecipe", back_populates="owner")
    meal_plans = relationship("MealPlan", back_populates="owner")


class InventoryItem(Base):
    __tablename__ = "inventory_items"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    quantity = Column(Float, default=1.0)
    unit = Column(String, default="Unidades")
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="inventory_items")


class SavedRecipe(Base):
    __tablename__ = "saved_recipes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    # Usamos JSON para guardar listas de ingredientes y pasos
    ingredients = Column(JSON)
    steps = Column(JSON)
    calories = Column(Integer)
    owner_id = Column(Integer, ForeignKey("users.id"))

    owner = relationship("User", back_populates="saved_recipes")


class MealPlan(Base):
    __tablename__ = "meal_plans"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(DateTime, nullable=False)  # Fecha del plan
    breakfast = Column(JSON)
    lunch = Column(JSON)
    dinner = Column(JSON)
    total_calories = Column(Integer)

    # Nuevas columnas de tracking
    breakfast_eaten = Column(
        Integer, default=0
    )  # 0: False, 1: True (usamos Integer por compatibilidad con SQLite booleans si es necesario, pero SQLAlchemy soporta Boolean)
    lunch_eaten = Column(Integer, default=0)
    dinner_eaten = Column(Integer, default=0)
    extra_meals = Column(JSON, default=list)  # Lista de comidas extra

    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="meal_plans")
