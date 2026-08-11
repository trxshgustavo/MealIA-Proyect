import re

file_path = r"c:\Users\ggonz\MealIA\frontend\meal_ia\lib\ui\screens\main\recipe_calendar_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update _buildMealList for extra meals mapping
old_extra = """          if (menu['extra_meals'] != null && (menu['extra_meals'] as List).isNotEmpty)
            ...((menu['extra_meals'] as List).map((extra) => _buildMealCard(
              context,
              "Extra",
              "extra",
              Icons.fastfood_outlined,
              extra,
              Colors.green,
              true,
              appState,
            )).toList()),"""

new_extra = """          if (menu['extra_meals'] != null && (menu['extra_meals'] as List).isNotEmpty)
            ...((menu['extra_meals'] as List).asMap().entries.map((entry) => _buildMealCard(
              context,
              "Colación ${entry.key + 1}",
              "extra",
              Icons.fastfood_outlined,
              entry.value,
              Colors.green,
              true,
              appState,
            )).toList()),"""
content = content.replace(old_extra, new_extra)


# 2. Update _buildMealCard to show eating_time
old_time_label = """                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp, // Reducido
                      ),
                    ),"""

new_time_label = """                    Text(
                      (mealData is Map && mealData['eating_time'] != null) ? "$timeLabel • ${mealData['eating_time']}" : timeLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp, // Reducido
                      ),
                    ),"""
content = content.replace(old_time_label, new_time_label)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("recipe_calendar_screen.dart updated successfully.")
