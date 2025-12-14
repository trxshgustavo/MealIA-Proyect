import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'recipe_screen.dart';
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
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipeScreen(),
        settings: RouteSettings(arguments: mealData),
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
              child: Column(
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
                  const SizedBox(height: 4),
                  Text(
                    _getFullDateLabel(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Calendar Strip
            SizedBox(
              height: 90,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                scrollDirection: Axis.horizontal,
                itemCount: _weekDays.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final date = _weekDays[index];
                  final isSelected = _isSameDay(date, _selectedDate);
                  return _buildDateBubble(date, isSelected);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Content Body
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(horizontalPadding),
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
        width: 65,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.buttonDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.buttonDark.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date.day.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontSize: 20,
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
      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSectionHeader(
            isToday
                ? "Tu Menú de Hoy"
                : "Menú del ${_getDayShortName(_selectedDate.weekday)} ${_selectedDate.day}",
          ),
          const SizedBox(height: 16),
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

          const SizedBox(height: 80), // Bottom padding for navbar
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Plan Futuro",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off_outlined,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Sin registro",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.soup_kitchen_outlined,
              size: 48,
              color: AppColors.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "¡Hora de planificar!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Ve a tu Inventario y genera\ntu menú para hoy.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        // Optional: Add "See Nutritional Info" button here
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: () => _navigateToRecipe(
          context,
          mealData is Map<String, dynamic> ? mealData : {},
          timeLabel,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Strip with Icon and Time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            size: 10,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _calculatePrepTime(mealData),
                            style: const TextStyle(
                              fontSize: 10,
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Meal Image Placeholder
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                calories,
                                style: const TextStyle(
                                  fontSize: 12,
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
