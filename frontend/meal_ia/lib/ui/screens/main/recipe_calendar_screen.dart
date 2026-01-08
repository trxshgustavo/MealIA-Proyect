import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import 'recipe_screen.dart';

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

    // FIX: Get menu specifically for the selected date
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
                20.w,
                16.h,
                20.w,
                10.h,
              ), // Espaciado reducido
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plan de Comidas",
                    style: TextStyle(
                      fontSize: 24.sp, // Reducido de 20
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _getFullDateLabel(_selectedDate),
                    style: TextStyle(
                      fontSize: 14.sp, // Reducido de 16
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Calendar Strip
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              child: SizedBox(
                height: 70.h, // Reducido de 70
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.horizontal,
                  itemCount: _weekDays.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: 10.w), // Reducido
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
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 100.h),
                  child: _buildMealList(context, dailyMenu, isToday),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.buttonDark.withValues(alpha: 0.3),
                    blurRadius: 6.r, // Sombra reducida
                    offset: Offset(0, 3.h),
                  ),
                ]
              : [],
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
  ) {
    // 1. Data Exists -> Show Menu (Always, for any date)
    if (menu != null && menu.isNotEmpty) {
      return Column(
        children: [
          _buildSectionHeader(
            isToday
                ? "Tu Menú de Hoy"
                : "Menú del ${_getDayShortName(_selectedDate.weekday)} ${_selectedDate.day}",
          ),
          SizedBox(height: 12.h), // Reducido de 20
          if (menu['breakfast'] != null)
            _buildMealCard(
              context,
              "Desayuno",
              Icons.wb_sunny_outlined,
              menu['breakfast'],
              Colors.orangeAccent,
            ),
          if (menu['lunch'] != null)
            _buildMealCard(
              context,
              "Almuerzo",
              Icons.restaurant_outlined,
              menu['lunch'],
              Colors.redAccent,
            ),
          if (menu['dinner'] != null)
            _buildMealCard(
              context,
              "Cena",
              Icons.nightlight_round_outlined,
              menu['dinner'],
              Colors.indigoAccent,
            ),
        ],
      );
    }

    // 2. No Data -> Clean Empty States
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Future Date -> Locked
    if (_selectedDate.isAfter(today)) {
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
                Icons.lock_clock_outlined,
                size: 32.sp, // Reducido de 40
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              "Plan Futuro",
              style: TextStyle(
                fontSize: 16.sp, // Reducido de 18
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6.h),
            const Text(
              "Los menús futuros se generarán\nautomáticamente o son Premium.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight),
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
    IconData icon,
    dynamic mealData,
    Color accentColor,
  ) {
    String title = "Plato desconocido";
    String description = "Toca para ver la receta completa";
    String calories = "--- kcal";
    // Assuming mealData format, extract info
    if (mealData is Map) {
      title = mealData['name'] ?? title;
      if (mealData.containsKey('calories')) {
        calories = "${mealData['calories']} kcal";
      }
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
                      timeLabel,
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
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 12.sp, // Reducido
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                calories,
                                style: TextStyle(
                                  fontSize: 11.sp, // Reducido
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLight,
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
        return "${mealData['time']} min";
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
}
