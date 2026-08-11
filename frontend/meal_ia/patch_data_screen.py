import re

file_path = r"c:\Users\ggonz\MealIA\frontend\meal_ia\lib\ui\screens\onboarding\data_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add state variables
state_vars_old = """  bool _isLoading = false;
  String? _selectedGender;

  @override"""

state_vars_new = """  bool _isLoading = false;
  String? _selectedGender;
  int _mealsPerDay = 3;
  Map<String, String> _mealTimes = {
    "Desayuno": "08:00",
    "Almuerzo": "14:00",
    "Cena": "20:00"
  };

  @override"""
content = content.replace(state_vars_old, state_vars_new)


# 2. Init state
init_state_old = """    if (appState.gender != null) {
      _selectedGender = appState.gender;
    }
  }"""

init_state_new = """    if (appState.gender != null) {
      _selectedGender = appState.gender;
    }
    _mealsPerDay = appState.mealsPerDay;
    if (appState.mealTimes.isNotEmpty) {
      _mealTimes = Map<String, String>.from(appState.mealTimes);
    }
    _updateMealTimesMap();
  }
  
  void _updateMealTimesMap() {
    // Ensure all required keys exist based on mealsPerDay
    if (!_mealTimes.containsKey("Desayuno")) _mealTimes["Desayuno"] = "08:00";
    if (!_mealTimes.containsKey("Almuerzo")) _mealTimes["Almuerzo"] = "14:00";
    if (!_mealTimes.containsKey("Cena")) _mealTimes["Cena"] = "20:00";
    
    if (_mealsPerDay >= 4) {
      if (!_mealTimes.containsKey("Colación 1")) _mealTimes["Colación 1"] = "11:00";
    } else {
      _mealTimes.remove("Colación 1");
    }
    
    if (_mealsPerDay == 5) {
      if (!_mealTimes.containsKey("Colación 2")) _mealTimes["Colación 2"] = "17:00";
    } else {
      _mealTimes.remove("Colación 2");
    }
  }
  
  Future<void> _pickTime(String mealKey) async {
    final current = _mealTimes[mealKey]!.split(":");
    final initialTime = TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1]));
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null) {
      setState(() {
        final hour = picked.hour.toString().padLeft(2, '0');
        final min = picked.minute.toString().padLeft(2, '0');
        _mealTimes[mealKey] = "$hour:$min";
      });
    }
  }"""
content = content.replace(init_state_old, init_state_new)


# 3. Save data
save_data_old = """      final success = await appState.saveUserPhysicalData(
        firstName: appState.firstName,
        lastName: lastName,
        birthdate: _birthdate,
        height: _currentHeight / 100.0,
        weight: _currentWeight,
        gender: _selectedGender,
      );"""

save_data_new = """      final success = await appState.saveUserPhysicalData(
        firstName: appState.firstName,
        lastName: lastName,
        birthdate: _birthdate,
        height: _currentHeight / 100.0,
        weight: _currentWeight,
        gender: _selectedGender,
        newMealsPerDay: _mealsPerDay,
        newMealTimes: _mealTimes,
      );"""
content = content.replace(save_data_old, save_data_new)


# 4. Build UI
ui_old = """                        const SizedBox(height: 24),

                        _isLoading"""

ui_new = """                        const SizedBox(height: 20),
                        
                        // --- Meal Configuration ---
                        const Divider(),
                        const SizedBox(height: 10),
                        Text(
                          'Configuración de Comidas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _mealsPerDay,
                          decoration: _inputDecoration('Cantidad de comidas al día', Icons.restaurant_menu),
                          items: const [
                            DropdownMenuItem(value: 3, child: Text('3 comidas (Principal)')),
                            DropdownMenuItem(value: 4, child: Text('4 comidas (1 colación)')),
                            DropdownMenuItem(value: 5, child: Text('5 comidas (2 colaciones)')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _mealsPerDay = value;
                                _updateMealTimesMap();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        ...['Desayuno', if (_mealsPerDay >= 4) 'Colación 1', 'Almuerzo', if (_mealsPerDay == 5) 'Colación 2', 'Cena'].map((meal) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () => _pickTime(meal),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      meal,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _mealTimes[meal] ?? "00:00",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.access_time, size: 20, color: AppColors.secondaryText),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 14),

                        _isLoading"""
content = content.replace(ui_old, ui_new)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("data_screen.dart updated successfully.")
