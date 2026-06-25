import sqlite3
import shutil

shutil.copy('mealia.db.bak', 'mealia.db')
conn = sqlite3.connect('mealia.db')
c = conn.cursor()
try:
    c.execute('ALTER TABLE users ADD COLUMN is_admin INTEGER DEFAULT 0;')
    c.execute("UPDATE users SET is_admin=1 WHERE email='ggonzalezcarrasco18@gmail.com'")
    conn.commit()
    print("DB Restored and Migrated")
except Exception as e:
    print(e)
finally:
    conn.close()
