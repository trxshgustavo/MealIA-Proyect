import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isSaving = false;

  // Lógica para regenerar menú con pantalla de carga (Copiado y adaptado de InventoryScreen)
  Future<void> _handleRegenerate() async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Mostrar diálogo de carga (fullscreen)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/animation1_transparent.gif',
                    height: 430.h,
                    width: 430.w,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.hourglass_bottom,
                      size: 80.sp,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Regenerando menú...",
                    style: TextStyle(
                      fontSize: 25.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Ejecutar la generación (Esto actualiza el estado en AppState)
    await appState.generateMenuConIA();

    if (!mounted) return;

    // Cerrar el diálogo
    Navigator.of(context).pop();

    // Al cerrar el diálogo, el Provider notificará y la pantalla se redibujará con el nuevo menú
  }

  // --- Widget para cada Tarjeta de Comida (Sin cambios) ---
  // --- Widget para cada Tarjeta de Comida (Refinado) ---
  Widget _buildMealCard(
    BuildContext context, {
    required String title,
    required String mealName,
    required IconData icon,
    required Color iconColor,
    required List<dynamic> items,
    required int calories,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h), // Reducido de 16
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            20.r,
          ), // Radio sutilmente reducido
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), // Sombra más sutil
              spreadRadius: 0,
              blurRadius: 10.r, // Reducido de 15
              offset: Offset(0, 4.h), // Offset reducido
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.0.w), // Padding interno reducido de 20
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w), // Reducido de 10
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20.sp,
                      color: iconColor,
                    ), // Icono más pequeño
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp, // Reducido de 16
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: Text(
                      "$calories kcal",
                      style: TextStyle(
                        fontSize: 12.sp, // Reducido
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h), // Espacio reducido
              const Divider(
                height: 1,
                color: AppColors.inputFill,
                thickness: 0.5,
              ),
              SizedBox(height: 12.h),
              Text(
                mealName,
                style: TextStyle(
                  fontSize: 17.sp, // Reducido de 18
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 6.h),
              if (items.isEmpty)
                Text(
                  'Sin ingredientes listados',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 13.sp,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "• ",
                                style: TextStyle(
                                  color: AppColors.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$item',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.textDark,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final menu = app.generatedMenu;

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: SafeArea(
        bottom: false,
        child: menu == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 60.sp,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Aún no hay menú generado',
                      style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                    ),
                  ],
                ),
              )
            // --- CAMBIO DE ESTRUCTURA PRINCIPAL ---
            : Column(
                children: [
                  // 1. Contenido Scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.0.w,
                        vertical: 10.0.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // HEADER "Total de Hoy" COMPACTO
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/carrot.png',
                                  height: 140.h, // Reducido de 140
                                  width: 140.w,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.restaurant, size: 40.sp),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Total calorias de hoy',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "${app.totalCalories} kcal",
                                  style: TextStyle(
                                    fontSize: 32.sp, // Reducido de 36
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryText,
                                    letterSpacing: -1.0,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24.h), // Reducido de 30

                          _buildMealCard(
                            context,
                            title: 'Desayuno',
                            icon: Icons.wb_sunny_rounded,
                            iconColor: Colors.orange,
                            mealName:
                                menu['breakfast']?['name'] ?? 'Sugerencia',
                            items:
                                menu['breakfast']?['ingredients'] as List? ??
                                [],
                            calories: menu['breakfast']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/recipe',
                              arguments: menu['breakfast'],
                            ),
                          ),

                          _buildMealCard(
                            context,
                            title: 'Almuerzo',
                            icon: Icons.restaurant,
                            iconColor: Colors.redAccent,
                            mealName: menu['lunch']?['name'] ?? 'Sugerencia',
                            items: menu['lunch']?['ingredients'] as List? ?? [],
                            calories: menu['lunch']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/recipe',
                              arguments: menu['lunch'],
                            ),
                          ),

                          _buildMealCard(
                            context,
                            title: 'Cena',
                            icon: Icons.nights_stay_rounded,
                            iconColor: Colors.indigo,
                            mealName: menu['dinner']?['name'] ?? 'Sugerencia',
                            items:
                                menu['dinner']?['ingredients'] as List? ?? [],
                            calories: menu['dinner']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/recipe',
                              arguments: menu['dinner'],
                            ),
                          ),

                          SizedBox(height: 16.h),

                          if (menu['note'] != null)
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blueGrey.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                menu['note'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.secondaryText,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          SizedBox(height: 16.h),

                          // --- MOVED BUTTONS HERE ---
                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),

                  // 2. Botones de Acción (Compactos)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Regenerate
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleRegenerate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              side: const BorderSide(
                                color: AppColors.textLight,
                                width: 1,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 18.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Regenerar',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Confirm
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    setState(() => _isSaving = true);
                                    try {
                                      await app.saveMenuForDate(
                                        DateTime.now(),
                                        menu,
                                      );
                                      if (!context.mounted) return;
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/main',
                                        (route) => false,
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                        // Aún así navegamos
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/main',
                                          (route) => false,
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSaving = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Confirmar",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
