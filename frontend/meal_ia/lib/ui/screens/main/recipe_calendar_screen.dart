import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import 'recipe_screen.dart';
import 'add_extra_meal_bottomsheet.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../utils/screen_utils.dart';

class RecipeCalendarScreen extends StatefulWidget {
  const RecipeCalendarScreen({super.key});

  @override
  State<RecipeCalendarScreen> createState() => _RecipeCalendarScreenState();
}

class _RecipeCalendarScreenState extends State<RecipeCalendarScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    ); // Strip time for comparison

    // FIX: Start 3 days ago
    final startDate = _selectedDate.subtract(const Duration(days: 3));

    _weekDays = List.generate(
      14, // Show 2 weeks total (3 past + 11 future)
      (index) => startDate.add(Duration(days: index)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        // Fetch plans for the range (3 days ago to +11 days)
        appState.fetchMealPlans(_weekDays.first, _weekDays.last);
      }
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  void _navigateToRecipe(
    BuildContext context,
    Map<String, dynamic> mealData,
    String mealType,
    String timeString,
  ) {
    // Create a mutable copy to safe inject time
    final args = Map<String, dynamic>.from(mealData);
    args['time'] = timeString;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipeScreen(),
        settings: RouteSettings(arguments: args),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final titleFontSize = ScreenUtils.getTitleFontSize(
      context,
      defaultSize: 28.0,
    );

    final dailyMenu = appState.getMenuForDate(_selectedDate);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Plan de Comidas",
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _getFullDateLabel(_selectedDate),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  _buildStreakBadge(context, appState),
                ],
              ),
            ),

            // Horizontal Calendar Strip
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SizedBox(
                height: 95.h,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.horizontal,
                  itemCount: _weekDays.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final date = _weekDays[index];
                    final isSelected = _isSameDay(date, _selectedDate);
                    return _buildDateBubble(date, isSelected);
                  },
                ),
              ),
            ),

            SizedBox(height: 16.h), // Espacio reducido de 16
            // Content Body
            Expanded(
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 15.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15.r, // Sombra reducida
                      offset: Offset(4.h, 4.h),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding,
                    100.h, // Added extra padding for navbar
                  ),
                  child: _buildMealList(context, dailyMenu, isToday, appState),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBubble(DateTime date, bool isSelected) {
    return GestureDetector(
      onTap: () => _onDateSelected(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58.w, // Ancho reducido de 65
        decoration: BoxDecoration(
          color: isSelected ? AppColors.buttonDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r), // Radio ajustado
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1.5.w,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getDayShortName(date.weekday),
              style: TextStyle(
                color: isSelected ? Colors.white70 : AppColors.textLight,
                fontSize: 12.sp, // Reducido de 13
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h), // Espacio reducido
            Text(
              date.day.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontSize: 18.sp, // Reducido de 20
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealList(
    BuildContext context,
    Map<String, dynamic>? menu,
    bool isToday,
    AppState appState,
  ) {
    // 1. Data Exists -> Show Menu (Always, for any date)
    if (menu != null && menu.isNotEmpty) {
      final extraMeals = (menu['extra_meals'] is List)
          ? List<dynamic>.from(menu['extra_meals'] as List)
          : <dynamic>[];

      // Si el usuario tiene configuradas 4 o 5 comidas y este día aún no tenía colaciones,
      // generamos colaciones automáticas basadas en su objetivo para que siempre vea sus 4 o 5 comidas.
      if (appState.mealsPerDay == 4 && extraMeals.isEmpty) {
        extraMeals.add({
          'name': 'Colación: Snack Saciante',
          'ingredients': ['1 porción de fruta fresca o frutos secos'],
          'steps': ['Listo para consumir.'],
          'calories': 150,
          'carbs': 20,
          'protein': 5,
          'fat': 4,
          'time': '5 min',
        });
      } else if (appState.mealsPerDay >= 5 && extraMeals.length < 2) {
        while (extraMeals.length < 2) {
          final idx = extraMeals.length + 1;
          extraMeals.add({
            'name': idx == 1 ? 'Colación 1: Snack Energético' : 'Colación 2: Snack Saludable',
            'ingredients': ['1 porción de yogurt, fruta o avena'],
            'steps': ['Listo para consumir.'],
            'calories': 150,
            'carbs': 20,
            'protein': 5,
            'fat': 4,
            'time': '5 min',
          });
        }
      }

      final hasSnack1 = extraMeals.isNotEmpty;
      final hasSnack2 = extraMeals.length >= 2;
      final int scheduledSnackCount = appState.mealsPerDay == 4 ? 1 : (appState.mealsPerDay >= 5 ? 2 : 0);
      final additionalExtras = extraMeals.length > scheduledSnackCount
          ? extraMeals.sublist(scheduledSnackCount)
          : <dynamic>[];

      return Column(
        children: [
          _buildMacroTracker(menu),
          SizedBox(height: 16.h),
          _buildSectionHeader(
            isToday
                ? "Tu Menú de Hoy (${appState.mealsPerDay} comidas)"
                : "Menú del ${_getDayShortName(_selectedDate.weekday)} ${_selectedDate.day} (${appState.mealsPerDay} comidas)",
          ),
          SizedBox(height: 12.h),

          // 1. Desayuno
          if (menu['breakfast'] != null)
            _buildMealCard(
              context,
              "Desayuno",
              "breakfast",
              Icons.wb_sunny_outlined,
              menu['breakfast'],
              Colors.orangeAccent,
              menu['breakfast_eaten'] ?? false,
              appState,
            ),

          // 2. Colación 1 (Media Mañana) - Si mealsPerDay >= 4 y hasSnack1
          if (appState.mealsPerDay >= 4 && hasSnack1)
            _buildMealCard(
              context,
              appState.mealsPerDay == 4 ? "Colación / Snack" : "Colación 1 (Media Mañana)",
              "extra_0",
              Icons.apple_rounded,
              extraMeals[0],
              Colors.amber.shade800,
              (extraMeals[0] is Map && extraMeals[0]['eaten'] == true) || (menu['extra_0_eaten'] == true),
              appState,
            ),

          // 3. Almuerzo
          if (menu['lunch'] != null)
            _buildMealCard(
              context,
              "Almuerzo",
              "lunch",
              Icons.restaurant_outlined,
              menu['lunch'],
              Colors.redAccent,
              menu['lunch_eaten'] ?? false,
              appState,
            ),

          // 4. Colación 2 (Media Tarde) - Si mealsPerDay >= 5 y hasSnack2
          if (appState.mealsPerDay >= 5 && hasSnack2)
            _buildMealCard(
              context,
              "Colación 2 (Media Tarde)",
              "extra_1",
              Icons.local_cafe_rounded,
              extraMeals[1],
              Colors.teal,
              (extraMeals[1] is Map && extraMeals[1]['eaten'] == true) || (menu['extra_1_eaten'] == true),
              appState,
            ),

          // 5. Cena
          if (menu['dinner'] != null)
            _buildMealCard(
              context,
              "Cena",
              "dinner",
              Icons.nightlight_round_outlined,
              menu['dinner'],
              Colors.indigoAccent,
              menu['dinner_eaten'] ?? false,
              appState,
            ),

          // 6. Comidas Extras Adicionales (manuales o fuera de la rutina)
          if (additionalExtras.isNotEmpty || (appState.mealsPerDay == 3 && extraMeals.isNotEmpty)) ...[
            SizedBox(height: 16.h),
            _buildSectionHeader("Comidas Extras Adicionales"),
            SizedBox(height: 8.h),
            ...((appState.mealsPerDay == 3 ? extraMeals : additionalExtras).asMap().entries.map((entry) {
              final originalIdx = appState.mealsPerDay == 3
                  ? entry.key
                  : (appState.mealsPerDay == 4 ? entry.key + 1 : entry.key + 2);
              final isExtraEaten = (entry.value is Map && entry.value['eaten'] == true) ||
                  (menu['extra_${originalIdx}_eaten'] == true);
              return _buildMealCard(
                context,
                "Extra ${entry.key + 1}",
                "extra_$originalIdx",
                Icons.fastfood_outlined,
                entry.value,
                Colors.green,
                isExtraEaten,
                appState,
              );
            }).toList()),
          ],

          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showAddExtraMealSheet(context, appState, _selectedDate),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text("Añadir Extra", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
        ],
      );
    }

    // 2. No Data -> Clean Empty States
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Future Date
    if (_selectedDate.isAfter(today)) {
      // 2a. No Premium -> Locked
      if (!appState.isPremium) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_clock_outlined,
                  size: 32.sp,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Plan Futuro",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 6.h),
              const Text(
                "Suscríbete a Premium para\nplanificar tus comidas futuras.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Ser Premium",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }

      // 2b. Premium -> Generate Button (Actionable Empty State)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 40.sp,
                color: AppColors.accentColor,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "Sin plan para este día",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "Genera un menú personalizado\npara ${_getDayShortName(_selectedDate.weekday)} ${_selectedDate.day}.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () =>
                  _handleGenerateMenuForDate(context, _selectedDate),
              icon: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                "Generar Menú",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonDark,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Past Date -> Empty History
    if (_selectedDate.isBefore(today)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.w), // Reducido
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_outlined,
                size: 32.sp, // Reducido
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              "Sin registro",
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6.h),
            const Text(
              "No hay recetas guardadas\npara este día.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    // Today -> Actionable Empty State
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16.w), // Reducido
            decoration: BoxDecoration(
              color: AppColors.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.soup_kitchen_outlined,
              size: 40.sp, // Reducido de 48
              color: AppColors.accentColor,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "¡Hora de planificar!",
            style: TextStyle(
              fontSize: 18.sp, // Reducido
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Ve a tu Inventario y genera\ntu menú para hoy.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp, // Reducido
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp, // Reducido de 18
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    String timeLabel,
    String mealTypeKey,
    IconData icon,
    dynamic mealData,
    Color accentColor,
    bool isEaten,
    AppState appState,
  ) {
    String title = "Plato desconocido";
    String description = "Toca para ver la receta completa";
    String calories = "--- kcal";
    int carbs = 0;
    int protein = 0;
    int fat = 0;
    
    // Assuming mealData format, extract info
    if (mealData is Map) {
      title = mealData['name'] ?? title;
      if (mealData.containsKey('calories')) {
        calories = "${mealData['calories']} kcal";
      }
      carbs = (mealData['carbs'] ?? 0) as int;
      protein = (mealData['protein'] ?? 0) as int;
      fat = (mealData['fat'] ?? 0) as int;
    } else if (mealData is String) {
      title = mealData;
    }

    final String timeString = _calculatePrepTime(mealData);

    return Padding(
      padding: EdgeInsets.only(bottom: 8.0.h), // Reducido de 12
      child: GestureDetector(
        onTap: () => _navigateToRecipe(
          context,
          mealData is Map<String, dynamic> ? mealData : {},
          timeLabel,
          timeString,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r), // Reducido de 24
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), // Sombra más sutil
                blurRadius: 10.r, // Reducido
                offset: Offset(0, 5.h), // Reducido
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Strip with Icon and Time
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 8.h,
                ), // Vertical reducido de 10
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.r),
                    topRight: Radius.circular(20.r),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16.sp, color: accentColor), // Reducido
                    SizedBox(width: 8.w),
                    Text(
                      (mealData is Map && mealData['eating_time'] != null) ? "$timeLabel • ${mealData['eating_time']}" : timeLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp, // Reducido
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w, // Reducido
                        vertical: 3.h, // Reducido
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            size: 10.sp,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Checkbox for eaten
                    GestureDetector(
                      onTap: () async {
                        final depleted = await appState.markMealEaten(_selectedDate, mealTypeKey, !isEaten);
                        if (depleted != null && depleted.isNotEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Se agotaron: ${depleted.join(", ")}'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          color: isEaten ? accentColor : Colors.white,
                          border: Border.all(
                            color: isEaten ? accentColor : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: isEaten 
                            ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(12.w), // Reducido de 16
                child: Row(
                  children: [
                    // Meal Image Placeholder
                    Container(
                      width: 50.w, // Reducido de 60
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14.r), // Reducido
                      ),
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          color: Colors.grey,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.sp, // Reducido de 17
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12.sp, // Reducido de 13
                              color: AppColors.textLight,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 4.h,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 12.sp,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    calories,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                              if (carbs > 0 || protein > 0 || fat > 0)
                                Text(
                                  "•  C: ${carbs}g  P: ${protein}g  G: ${fat}g",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculatePrepTime(dynamic mealData) {
    if (mealData is Map) {
      // 1. Check for explicit time
      if (mealData['time'] != null) {
        final time = mealData['time'].toString();
        // Evitar doble sufijo "min min"
        return time.contains('min') ? time : "$time min";
      }
      // 2. Heuristic: Base 10m + 5m per step
      final steps = mealData['steps'];
      if (steps is List && steps.isNotEmpty) {
        final calculated = 10 + (steps.length * 5);
        return "$calculated min";
      }
    }
    // Default fallback
    return "20 min";
  }

  Widget _buildMacroTracker(Map<String, dynamic> menu) {
    // Collect daily goals (simplified logic: target total is stored, macros are roughly calculated)
    int targetCalories = menu['total_calories'] ?? 2000;
    int targetCarbs = (targetCalories * 0.50 / 4).round();
    int targetProtein = (targetCalories * 0.25 / 4).round();
    int targetFat = (targetCalories * 0.25 / 9).round();

    int consumedCalories = 0;
    int consumedCarbs = 0;
    int consumedProtein = 0;
    int consumedFat = 0;

    void addMacros(dynamic meal) {
      if (meal == null) return;
      consumedCalories += (meal['calories'] ?? 0) as int;
      consumedCarbs += (meal['carbs'] ?? 0) as int;
      consumedProtein += (meal['protein'] ?? 0) as int;
      consumedFat += (meal['fat'] ?? 0) as int;
    }

    if (menu['breakfast_eaten'] == true) addMacros(menu['breakfast']);
    if (menu['lunch_eaten'] == true) addMacros(menu['lunch']);
    if (menu['dinner_eaten'] == true) addMacros(menu['dinner']);
    
    if (menu['extra_meals'] != null && menu['extra_meals'] is List) {
      final extraList = menu['extra_meals'] as List;
      for (int i = 0; i < extraList.length; i++) {
        final extra = extraList[i];
        final isExtraEaten = (extra is Map && extra['eaten'] == true) || (menu['extra_${i}_eaten'] == true);
        if (isExtraEaten) {
          addMacros(extra);
        }
      }
    }

    double proteinPercent = (consumedProtein / targetProtein).clamp(0.0, 1.0);
    double carbsPercent = (consumedCarbs / targetCarbs).clamp(0.0, 1.0);
    double fatPercent = (consumedFat / targetFat).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15.r,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Resumen Diario",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                "$consumedCalories / $targetCalories kcal",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularMacro(
                title: "Carbos",
                amount: consumedCarbs,
                target: targetCarbs,
                percent: carbsPercent,
                color: Colors.orange,
              ),
              _buildCircularMacro(
                title: "Proteína",
                amount: consumedProtein,
                target: targetProtein,
                percent: proteinPercent,
                color: Colors.redAccent,
              ),
              _buildCircularMacro(
                title: "Grasas",
                amount: consumedFat,
                target: targetFat,
                percent: fatPercent,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMacro({
    required String title,
    required int amount,
    required int target,
    required double percent,
    required Color color,
  }) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 30.r,
          lineWidth: 6.w,
          animation: true,
          percent: percent,
          center: Text(
            "${(percent * 100).toInt()}%",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: color,
          backgroundColor: Colors.grey.shade200,
        ),
        SizedBox(height: 8.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          "${amount}g / ${target}g",
          style: TextStyle(
            fontSize: 10.sp,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  // --- Helpers ---

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayShortName(int weekday) {
    const days = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return days[weekday - 1];
  }

  String _getFullDateLabel(DateTime date) {
    // Example: "Viernes, 12 de Octubre"
    final dayName = _getDayNameLong(date.weekday);
    final monthName = _getMonthName(date.month);
    return "$dayName, ${date.day} de $monthName";
  }

  String _getDayNameLong(int weekday) {
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  Future<void> _handleGenerateMenuForDate(
    BuildContext context,
    DateTime date,
  ) async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Check inventory first
    if (appState.inventoryMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Añade alimentos antes de generar un menú!'),
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            insetPadding: EdgeInsets.zero,
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reuse animation logic or simple indicator
                  CircularProgressIndicator(color: AppColors.buttonDark),
                  SizedBox(height: 20),
                  Text(
                    "Planificando el futuro...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await appState.generateMenuConIA(date: date);

    if (context.mounted) {
      Navigator.of(context).pop();
      // Refrescar el día
      setState(() {});
    }
  }

  Widget _buildStreakBadge(BuildContext context, AppState appState) {
    final streak = appState.currentStreak;
    final hasStreak = streak > 0;

    final bgColor = hasStreak
        ? const Color(0xFFFFF3E0)
        : Colors.grey.shade100;

    final borderColor = hasStreak
        ? Colors.orange.shade300
        : Colors.grey.shade300;

    final iconColor = hasStreak
        ? const Color(0xFFFF5722)
        : Colors.grey.shade500;

    final textColor = hasStreak
        ? const Color(0xFFE65100)
        : Colors.grey.shade700;

    return GestureDetector(
      onTap: () => _showStreakDetailsModal(context, appState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: hasStreak
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 8.r,
                    offset: Offset(0, 2.h),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: iconColor,
              size: 20.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              "$streak",
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStreakDetailsModal(BuildContext context, AppState appState) {
    final streak = appState.currentStreak;
    final hasStreak = streak > 0;
    final completed = appState.todayCompletedMealsCount;
    final total = appState.todayTotalMealsCount;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: hasStreak ? const Color(0xFFFFF3E0) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasStreak ? Colors.orange.shade300 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 44.sp,
                  color: hasStreak ? const Color(0xFFFF5722) : Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                hasStreak ? "¡$streak ${streak == 1 ? 'Día' : 'Días'} de Racha!" : "¡Empieza tu Racha!",
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                hasStreak
                    ? "¡Estás encendido! Completa todas tus comidas de hoy para mantener tu racha activa y seguir avanzando."
                    : "Marca todas tus comidas del día ($total comidas) para encender tu fuego de racha saludable.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Comidas de hoy",
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          "$completed de $total completadas",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: completed == total ? Colors.green.shade700 : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10.h,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completed == total ? Colors.green : const Color(0xFFFF9800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonDark,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    "¡Entendido!",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
