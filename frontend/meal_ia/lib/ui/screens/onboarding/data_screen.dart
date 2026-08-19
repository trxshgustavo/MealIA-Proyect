import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});
  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
  DateTime? _birthdate;
  int _currentHeight = 170;
  double _currentWeight = 70.5;
  final _dateCtl = TextEditingController();
  bool _isLoading = false;
  String? _selectedGender;
  int _mealsPerDay = 3;
  Map<String, String> _mealTimes = {
    "Desayuno": "08:00",
    "Almuerzo": "14:00",
    "Cena": "20:00"
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      setState(() {
        _firstNameCtl.text = appState.firstName ?? '';
        _lastNameCtl.text = appState.lastName ?? '';
        if (appState.height != null) {
          _currentHeight = (appState.height! * 100).round();
        }
        if (appState.weight != null) {
          _currentWeight = appState.weight!;
        }
        if (appState.birthdate != null) {
          _birthdate = appState.birthdate;
          _dateCtl.text = DateFormat('dd/MM/yyyy').format(_birthdate!);
        }
        if (appState.gender != null) {
          _selectedGender = appState.gender;
        }
        _mealsPerDay = appState.mealsPerDay;
        if (appState.mealTimes.isNotEmpty) {
          _mealTimes = Map<String, String>.from(appState.mealTimes);
        }
        _updateMealTimesMap();
      });
    });
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
  }

  @override
  void dispose() {
    _dateCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) {
      setState(() {
        _birthdate = d;
        _dateCtl.text = DateFormat('dd/MM/yyyy').format(d);
      });
    }
  }

  Future<void> _pickHeight() async {
    await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona tu altura (cm)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return NumberPicker(
                value: _currentHeight,
                minValue: 100,
                maxValue: 230,
                step: 1,
                onChanged: (value) {
                  setState(() => _currentHeight = value);
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickWeight() async {
    await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona tu peso (kg)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DecimalNumberPicker(
                value: _currentWeight,
                minValue: 30,
                maxValue: 180,
                decimalPlaces: 1,
                onChanged: (value) {
                  setState(() => _currentWeight = value);
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      final success = await appState.saveUserPhysicalData(
        firstName: _firstNameCtl.text.trim().isEmpty ? null : _firstNameCtl.text.trim(),
        lastName: _lastNameCtl.text.trim().isEmpty ? null : _lastNameCtl.text.trim(),
        birthdate: _birthdate,
        height: _currentHeight / 100.0,
        weight: _currentWeight,
        gender: _selectedGender,
        newMealsPerDay: _mealsPerDay,
        newMealTimes: _mealTimes,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushNamed(context, '/goals');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar tus datos. Intenta de nuevo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label, [IconData? icon]) {
    return InputDecoration(
      hintText: label,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.secondaryText) : null,
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      filled: true,
      fillColor: AppColors.inputFill, // Fondo gris claro
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none, // Sin borde
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(
          color: AppColors.primaryColor,
        ), // Borde en foco
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primaryText,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ScreenUtils.getMaxContainerWidth(context),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: MediaQuery.of(context).padding.top + 8.h,
              bottom: 24.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/carrot.png',
                  height: 190.h,
                  width: 190.h,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.analytics,
                    size: 100,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: 16.h),

                Container(
                  padding: EdgeInsets.all(20.0.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        spreadRadius: 0,
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Cuéntanos sobre ti',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        SizedBox(height: 20.h),

                        TextField(
                          controller: _firstNameCtl,
                          decoration: _inputDecoration('Tu nombre', Icons.person),
                        ),
                        SizedBox(height: 16.h),

                        TextField(
                          controller: _lastNameCtl,
                          decoration: _inputDecoration('Tu apellido', Icons.person_outline),
                        ),
                        SizedBox(height: 16.h),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          decoration: _inputDecoration('Selecciona tu género', Icons.person),
                          items: const [
                            DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                            DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedGender = value);
                          },
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _dateCtl,
                          readOnly: true,
                          decoration: _inputDecoration(
                            'Fecha de nacimiento (Opcional)',
                            Icons.calendar_today,
                          ),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Altura',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickHeight,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill, // Fondo gris
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "$_currentHeight cm",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Peso',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickWeight,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill, // Fondo gris
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "${_currentWeight.toStringAsFixed(1)} kg",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // --- Meal Configuration ---
                        
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
                          initialValue: _mealsPerDay,
                          isExpanded: true,
                          decoration: _inputDecoration('Cantidad de comidas al día'),
                          items: const [
                            DropdownMenuItem(value: 3, child: Align(alignment: Alignment.centerLeft, child: Text('3 comidas (Principal)'))),
                            DropdownMenuItem(value: 4, child: Align(alignment: Alignment.centerLeft, child: Text('4 comidas (1 colación)'))),
                            DropdownMenuItem(value: 5, child: Align(alignment: Alignment.centerLeft, child: Text('5 comidas (2 colaciones)'))),
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

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _saveData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.buttonDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Continuar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
