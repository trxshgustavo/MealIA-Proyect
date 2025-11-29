-- Script para inicializar la base de datos meal_ia_db

-- Tabla de Usuarios
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    birthdate DATE,
    height FLOAT,
    weight FLOAT,
    goal VARCHAR(50) DEFAULT 'Mantenimiento'
);

-- Tabla de Inventario
CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    user_id INTEGER REFERENCES users(id)
);

-- Tabla de Recetas (simplificada)
CREATE TABLE IF NOT EXISTS recipes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    ingredients TEXT,
    instructions TEXT,
    is_saved BOOLEAN DEFAULT false,
    user_id INTEGER REFERENCES users(id)
);

-- Puedes añadir inserts de ejemplo si quieres
-- INSERT INTO users (first_name) VALUES ('Usuario de Prueba');