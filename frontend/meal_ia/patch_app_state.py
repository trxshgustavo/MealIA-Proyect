import re

file_path = r"c:\Users\ggonz\MealIA\frontend\meal_ia\lib\core\providers\app_state.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add fields to AppState
old_fields = """  String? photoUrl;
  bool isPremium = false; // Premium Status
  bool isAdmin = false; // Admin Status

  // Inventario y Menú"""

new_fields = """  String? photoUrl;
  bool isPremium = false; // Premium Status
  bool isAdmin = false; // Admin Status
  int mealsPerDay = 3;
  Map<String, String> mealTimes = {
    "Desayuno": "08:00",
    "Almuerzo": "14:00",
    "Cena": "20:00"
  };

  // Inventario y Menú"""
content = content.replace(old_fields, new_fields)


# 2. Update memory clearing
old_clear = """    photoUrl = null;

    _inventory.clear();"""

new_clear = """    photoUrl = null;
    mealsPerDay = 3;
    mealTimes = {
      "Desayuno": "08:00",
      "Almuerzo": "14:00",
      "Cena": "20:00"
    };

    _inventory.clear();"""
content = content.replace(old_clear, new_clear)


# 3. Cache loading
old_cache_load = """            goal = data['goal'] ?? 'Mantenimiento';
            isPremium = data['is_premium'] ?? false;
            isAdmin = data['is_admin'] ?? false;
            debugPrint("Loaded Profile from Cache for ${user.uid}");"""

new_cache_load = """            goal = data['goal'] ?? 'Mantenimiento';
            isPremium = data['is_premium'] ?? false;
            isAdmin = data['is_admin'] ?? false;
            if (data['meals_per_day'] != null) mealsPerDay = data['meals_per_day'];
            if (data['meal_times'] != null) mealTimes = Map<String, String>.from(data['meal_times']);
            debugPrint("Loaded Profile from Cache for ${user.uid}");"""
content = content.replace(old_cache_load, new_cache_load)


# 4. Backend loading
old_backend_load = """            isPremium = userData['is_premium'] ?? false;
            isAdmin = userData['is_admin'] ?? false;

            if (user != null) {"""

new_backend_load = """            isPremium = userData['is_premium'] ?? false;
            isAdmin = userData['is_admin'] ?? false;
            if (userData['meals_per_day'] != null) mealsPerDay = userData['meals_per_day'];
            if (userData['meal_times'] != null) mealTimes = Map<String, String>.from(userData['meal_times']);

            if (user != null) {"""
content = content.replace(old_backend_load, new_backend_load)


# 5. Cache saving
old_cache_save = """                'gender': gender,
                'is_premium': isPremium,
                'is_admin': isAdmin,
              };
              await _storage.write("""

new_cache_save = """                'gender': gender,
                'is_premium': isPremium,
                'is_admin': isAdmin,
                'meals_per_day': mealsPerDay,
                'meal_times': mealTimes,
              };
              await _storage.write("""
content = content.replace(old_cache_save, new_cache_save)


# 6. Firestore backup loading
old_firestore_load = """              if (weight == null && data.containsKey('weight')) weight = (data['weight'] as num?)?.toDouble();
              if (birthdate == null && data.containsKey('birthdate')) birthdate = DateTime.tryParse(data['birthdate']);
            }
          } catch (e) {"""

new_firestore_load = """              if (weight == null && data.containsKey('weight')) weight = (data['weight'] as num?)?.toDouble();
              if (birthdate == null && data.containsKey('birthdate')) birthdate = DateTime.tryParse(data['birthdate']);
              if (data.containsKey('meals_per_day')) mealsPerDay = data['meals_per_day'];
              if (data.containsKey('meal_times')) mealTimes = Map<String, String>.from(data['meal_times']);
            }
          } catch (e) {"""
content = content.replace(old_firestore_load, new_firestore_load)


# 7. Update saveUserPhysicalData signature and implementation (Let's check if it exists, wait, we don't know the exact signature).
# Let's search for `saveUserPhysicalData` first or just replace it by regex.
# I'll use regex to inject the fields.
regex_save_sig = r"Future<bool> saveUserPhysicalData\(\s*\{([^}]*)\}\) async \{"
new_save_sig = r"Future<bool> saveUserPhysicalData({ \1, int? newMealsPerDay, Map<String, String>? newMealTimes }) async {"
content = re.sub(regex_save_sig, new_save_sig, content, count=1)

regex_save_body = r"final Map<String, dynamic> body = \{([^}]*)\};"
new_save_body = r"final Map<String, dynamic> body = {\1};\n      if (newMealsPerDay != null) {\n        body['meals_per_day'] = newMealsPerDay;\n        mealsPerDay = newMealsPerDay;\n      }\n      if (newMealTimes != null) {\n        body['meal_times'] = newMealTimes;\n        mealTimes = newMealTimes;\n      }"
content = re.sub(regex_save_body, new_save_body, content, count=1)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("app_state.dart updated successfully.")
