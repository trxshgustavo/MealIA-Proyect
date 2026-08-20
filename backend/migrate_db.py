import sqlite3
import json

db_path = "c:\\Users\\ggonz\\MealIA\\backend\\mealia.db"

def migrate():
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if column exists
    cursor.execute("PRAGMA table_info(users);")
    columns = [info[1] for info in cursor.fetchall()]
    
    if "meals_per_day" not in columns:
        print("Adding meals_per_day...")
        cursor.execute("ALTER TABLE users ADD COLUMN meals_per_day INTEGER DEFAULT 3;")
    
    if "meal_times" not in columns:
        print("Adding meal_times...")
        # Since SQLite ALTER TABLE ADD COLUMN doesn't easily support JSON default in older versions without constraints, 
        # we will set default to a string '{}' or insert it for existing users.
        cursor.execute("ALTER TABLE users ADD COLUMN meal_times JSON;")
        
        # Give existing users a default time
        default_times = json.dumps({"Desayuno": "08:00", "Almuerzo": "14:00", "Cena": "20:00"})
        cursor.execute("UPDATE users SET meal_times = ?", (default_times,))

    # Add category to inventory_items
    cursor.execute("PRAGMA table_info(inventory_items);")
    inv_columns = [info[1] for info in cursor.fetchall()]
    if "category" not in inv_columns:
        print("Adding category to inventory_items...")
        cursor.execute("ALTER TABLE inventory_items ADD COLUMN category VARCHAR DEFAULT 'Otros';")
        cursor.execute("UPDATE inventory_items SET category = 'Otros' WHERE category IS NULL;")

    conn.commit()
    conn.close()
    print("Migration complete.")

if __name__ == "__main__":
    migrate()
