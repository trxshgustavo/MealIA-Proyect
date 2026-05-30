import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'backend', 'mealia.db')

def migrate():
    print(f"Connecting to database at {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. Add is_premium to users
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN is_premium INTEGER DEFAULT 0")
        print("Added is_premium column to users table.")
    except sqlite3.OperationalError as e:
        if "duplicate column" in str(e):
             print("is_premium column already exists.")
        else:
            print(f"Error adding column: {e}")

    # 2. Create meal_plans table
    # We can rely on SQLAlchemy to create it if it doesn't exist, but we can also do it here manually to be sure.
    # Actually, SQLAlchemy create_all only creates check tables that don't exist.
    # So if we run this script BEFORE running the backend, we might as well just let SQLAlchemy handle the NEW table creation
    # if we just restart the backend?
    # But wait, create_all does NOT modify existing tables.
    # The new table 'meal_plans' will be created by create_all in main.py because it doesn't exist.
    # So we only strictly needed the ALTER TABLE for users.
    
    conn.commit()
    conn.close()
    print("Migration complete.")

if __name__ == "__main__":
    if os.path.exists(DB_PATH):
        migrate()
    else:
        print(f"Database not found at {DB_PATH}. It will be created by the backend.")
