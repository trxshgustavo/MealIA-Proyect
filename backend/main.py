from fastapi import FastAPI

# Crea la instancia de la aplicación
app = FastAPI()

# Define una ruta (endpoint)
@app.get("/")
def read_root():
    return {"Hello": "Meal.IA Backend"}