import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
=======
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  Animation<double>? _animation;
  final Set<int> _completedSteps = {};
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutExpo,
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Animation<double> get safeAnimation =>
      _animation ?? const AlwaysStoppedAnimation(1.0);

  void _toggleStep(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );

    final Map<String, dynamic>? recipeData =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String name = recipeData?['name'] ?? 'Receta';
    final int calories = recipeData?['calories'] ?? 0;
    final List<dynamic> steps = recipeData?['steps'] ?? [];

    // STRICT DATA PARSING
    final int carbs = recipeData?['carbs'] ?? 0;
    final int protein = recipeData?['protein'] ?? 0;
    final int fat = recipeData?['fat'] ?? 0;

    // Safety handling for doubles that might be ints in JSON
    double toDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final double fiber = toDouble(recipeData?['fiber']);
    final double sugar = toDouble(recipeData?['sugar']);
    final double vitamins = toDouble(recipeData?['vitamins']);
    final double minerals = toDouble(recipeData?['minerals']);

    final int sodium = recipeData?['sodium'] ?? 0;
    final int cholesterol = recipeData?['cholesterol'] ?? 0;

    final String time = recipeData?['time'] ?? '20 min';

    final nutrientData = _NutrientData(
      calories: calories,
      carbs: carbs,
      protein: protein,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      vitamins: vitamins,
      minerals: minerals,
      sodium: sodium,
      cholesterol: cholesterol,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // DEBUG OVERLAY
            Container(
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                "DEBUG DATA: ${recipeData.toString()}",
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),

            // HEADER
            _buildHeader(context, name, calories, time),

            // CUSTOM TAB SELECTOR
            _buildTabSelector(),

            // CONTENT
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedTabIndex == 0
                    ? _buildNutritionTab(nutrientData)
                    : _buildRecipeTab(name, steps),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    int calories,
    String time,
  ) {
    return Container(
      // Remove horizontal padding from container, keep vertical
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Softer shadow
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row (Nav) - Using Stack for perfect centering
          SizedBox(
            height: 40.h, // Fixed height for the nav bar area
            child: Stack(
              children: [
<<<<<<< HEAD
                // Back Button - Aligned left
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.w), // Minimal padding
                    child: const BackButton(color: Colors.black87),
                  ),
                ),
                // Title - Perfectly centered
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Detalle de la Receta",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Recipe Name & Icon - Add padding back here
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
=======
                // Zanahoria a color, visible
                // Contenido de la cabecera
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    100,
                    horizontalPadding,
                    0,
                  ),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20.sp, // Slightly reduced
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 237, 236, 236),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color.fromARGB(255, 189, 189, 189),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFF212121),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "$calories kcal",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF212121),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 237, 236, 236),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color.fromARGB(255, 189, 189, 189),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFF212121),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF212121),
                                  ),
                                ),
                              ],
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
<<<<<<< HEAD
        ],
      ),
=======

          // 2. TARJETA FLOTANTE (Blanca)
          Container(
            margin: EdgeInsets.fromLTRB(
              horizontalPadding * 0.67,
              260,
              horizontalPadding * 0.67,
              0,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECCIÓN INGREDIENTES ---
                      const _SectionHeader(
                        icon: Icons.shopping_basket_outlined,
                        title: "Ingredientes",
                      ),
                      const SizedBox(height: 16),
                      if (ingredients.isEmpty)
                        const Text(
                          "No hay ingredientes listados",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ...ingredients.map(
                        (item) => _IngredientItem(text: item.toString()),
                      ),

                      const SizedBox(height: 32),
                      const Divider(color: AppColors.inputFill),
                      const SizedBox(height: 24),

                      // --- SECCIÓN PASOS ---
                      const _SectionHeader(
                        icon: Icons.format_list_numbered_rounded,
                        title: "Pasos de preparación",
                      ),
                      const SizedBox(height: 20),
                      if (steps.isEmpty)
                        const Text(
                          "No hay pasos listados",
                          style: TextStyle(color: Colors.grey),
                        ),

                      ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        itemBuilder: (context, index) {
                          return _StepItem(
                            index: index + 1,
                            text: steps[index].toString(),
                          );
                        },
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // BOTONES FLOTANTES INFERIORES
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(horizontalPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        // DIFFERENT BUTTONS IF PREVIEW OR VIEW MODE
        child: isPreview
            ? Row(
                // PREVIEW MODE (Generate Flow)
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleRegenerate(mealType, recipeData!),
                      icon: const Icon(Icons.refresh),
                      label: const Text("Regenerar"),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.buttonDark),
                        foregroundColor: AppColors.buttonDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleSave(context, mealType, recipeData!),
                      icon: const Icon(Icons.check),
                      label: const Text("Guardar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                // VIEW MODE (Calendar View) - Maybe just "Back" or "Favorite"
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.buttonDark),
                        foregroundColor: AppColors.buttonDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Volver"),
                    ),
                  ),
                  // KEEP FAVORITE BUTTON IF NEEDED OR REMOVE
                ],
              ),
      ),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      height: 50.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(0, "Macros", Icons.pie_chart_outline_rounded),
          _buildTabButton(1, "Preparación", Icons.menu_book_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: 35.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF212121) : Colors.transparent,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16.sp,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionTab(_NutrientData nutrients) {
    return SingleChildScrollView(
      key: const ValueKey('nutrition'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: AnimatedBuilder(
        animation: safeAnimation,
        builder: (context, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MAIN MACROS CARD
              _buildMacrosCard(nutrients),

              SizedBox(height: 20.h),

              // DETAILED NUTRIENTS
              _buildNutrientsSection(nutrients),

              SizedBox(height: 100.h),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMacrosCard(_NutrientData data) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 120.w, // Reduced for safety
                height: 120.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(120.w, 120.w),
                      painter: _CleanDonutPainter(
                        progress: safeAnimation.value,
                        carbsPct:
                            data.carbsPct /
                            (data.carbsPct + data.proteinPct + data.fatPct),
                        proteinPct:
                            data.proteinPct /
                            (data.carbsPct + data.proteinPct + data.fatPct),
                        fatPct:
                            data.fatPct /
                            (data.carbsPct + data.proteinPct + data.fatPct),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${data.calories}",
                          style: TextStyle(
                            fontSize: 22.sp, // Reduced font size slightly
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          "kcal",
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w), // Gap
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroLegendItem(
                      "Carbohidratos",
                      "${data.carbs}g",
                      const Color(0xFF4CAF50),
                      (data.carbs * 4) /
                          data.calories, // Approximate progress for visual
                    ),
                    SizedBox(height: 14.h),
                    _buildMacroLegendItem(
                      "Proteínas",
                      "${data.protein}g",
                      const Color(0xFFFF9800),
                      (data.protein * 4) / data.calories,
                    ),
                    SizedBox(height: 14.h),
                    _buildMacroLegendItem(
                      "Grasas",
                      "${data.fat}g",
                      const Color(0xFF2196F3),
                      (data.fat * 9) / data.calories,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLegendItem(
    String label,
    String value,
    Color color,
    double pct,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible Label Side
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp, // Reduced slightly
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            // Value Side (Fixed-ish width content)
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        // Progress bar
        Container(
          height: 5.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(3.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (pct * safeAnimation.value).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientsSection(_NutrientData data) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Detalle Nutricional",
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 20.h),

          // Nutrient rows
          _buildNutrientRow(
            "Fibra",
            "${data.fiber}",
            "g",
            const Color(0xFFFF7043),
          ),
          Divider(height: 24.h, color: Colors.grey.shade100),

          _buildNutrientRow(
            "Azúcares",
            "${data.sugar}",
            "g",
            const Color(0xFFEC407A),
          ),
          Divider(height: 24.h, color: Colors.grey.shade100),

          _buildNutrientRow(
            "Vitamina C",
            "${data.vitamins}",
            "mg",
            const Color(0xFFAB47BC),
          ),
          Divider(height: 24.h, color: Colors.grey.shade100),

          _buildNutrientRow(
            "Hierro",
            "${data.minerals}",
            "mg",
            const Color(0xFF5C6BC0),
          ),
          Divider(height: 24.h, color: Colors.grey.shade100),

          _buildNutrientRow(
            "Sodio",
            "${data.sodium}",
            "mg",
            const Color(0xFF78909C),
          ),
          Divider(height: 24.h, color: Colors.grey.shade100),

          _buildNutrientRow(
            "Colesterol",
            "${data.sodium}",
            "mg",
            const Color(0xFFEF5350),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(
    String name,
    String value,
    String unit,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 20.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              TextSpan(
                text: " $unit",
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeTab(String name, List<dynamic> steps) {
    return ListView(
      key: const ValueKey('recipe'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      children: [
        // Progress indicator
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 230, 230, 230),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF757575).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "${_completedSteps.length}/${steps.isEmpty ? '1' : steps.length}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Progreso de preparación",
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: steps.isEmpty
                            ? 0
                            : _completedSteps.length / steps.length,
                        backgroundColor: Colors.white,
                        color: const Color.fromARGB(255, 83, 81, 81),
                        minHeight: 6.h,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        if (steps.isEmpty)
          // Empty state UI...
          Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Text(
                "No hay pasos definidos",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

        ...steps.asMap().entries.map((entry) {
          int idx = entry.key;
          String step = entry.value.toString();
          bool isCompleted = _completedSteps.contains(idx);

          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: GestureDetector(
              onTap: () => _toggleStep(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r), // More rounded
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFF81C784)
                        : Colors.transparent,
                    width: isCompleted ? 1.5 : 0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCompleted
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(7.r),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: isCompleted
                              ? Colors.white
                              : Colors.transparent,
                          size: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    // Text
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 1.5,
                          fontWeight: isCompleted
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: isCompleted
                              ? Colors.grey.shade600
                              : const Color(0xFF1A1A1A),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        SizedBox(height: 100.h),
      ],
    );
  }
}

// --- CLEAN DONUT PAINTER ---
class _CleanDonutPainter extends CustomPainter {
  final double progress;
  final double carbsPct;
  final double proteinPct;
  final double fatPct;

  _CleanDonutPainter({
    required this.progress,
    required this.carbsPct,
    required this.proteinPct,
    required this.fatPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 14.w; // Slightly thinner
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.shade100;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;
    final gap = 0.08; // Slightly larger gap

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweep = (2 * math.pi * pct - gap) * progress;
      if (sweep <= 0) return;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;

      canvas.drawArc(rect, startAngle + gap / 2, sweep, false, paint);
      startAngle += 2 * math.pi * pct;
    }

    drawSegment(carbsPct, const Color(0xFF4CAF50));
    drawSegment(proteinPct, const Color(0xFFFF9800));
    drawSegment(fatPct, const Color(0xFF2196F3));
  }

  @override
  bool shouldRepaint(covariant _CleanDonutPainter old) {
    return old.progress != progress;
  }
}

// --- DETERMINISTIC NUTRIENT CALCULATOR REMOVED ---
class _NutrientData {
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
  final double fiber;
  final double vitamins;
  final double minerals;
  final double sugar;
  final int sodium;
  final int cholesterol;

  _NutrientData({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.vitamins,
    required this.minerals,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
  });

  double get carbsPct => calories > 0 ? (carbs * 4) / calories : 0;
  double get proteinPct => calories > 0 ? (protein * 4) / calories : 0;
  double get fatPct => calories > 0 ? (fat * 9) / calories : 0;
}
