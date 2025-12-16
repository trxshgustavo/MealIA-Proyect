import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

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
                    height: 430,
                    width: 430,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.hourglass_bottom,
                      size: 80,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Regenerando menú...",
                    style: TextStyle(
                      fontSize: 25,
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              spreadRadius: 0,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$calories kcal",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.inputFill),
              const SizedBox(height: 16),
              Text(
                mealName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text(
                  'Sin ingredientes listados',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "• ",
                                style: TextStyle(
                                  color: AppColors.accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$item',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textDark,
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
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.primaryText,
        iconTheme: const IconThemeData(color: AppColors.primaryText, size: 32),
      ),
      body: SafeArea(
        bottom: false,
        child: menu == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aún no hay menú generado',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            // --- CAMBIO DE ESTRUCTURA PRINCIPAL ---
            : Column(
                children: [
                  // 1. Contenido Scrollable (Ocupa todo el espacio posible)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: ScreenUtils.getResponsiveHorizontalPadding(context),
                        vertical: ScreenUtils.getResponsiveVerticalPadding(context) * 0.5,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ScreenUtils.getMaxContainerWidth(context),
                        ),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/carrot.png',
                                  height: 140,
                                  width: 140,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.restaurant, size: 60),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Total de Hoy',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.secondaryText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "${app.totalCalories} kcal",
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryText,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

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

                          const SizedBox(height: 20),

                          if (menu['note'] != null)
                            Container(
                              padding: const EdgeInsets.all(16),
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
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          // Quitamos el SizedBox grande final aquí porque el botón está abajo
                          const SizedBox(height: 20),
                        ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Botones de Acción
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      ScreenUtils.getResponsiveHorizontalPadding(context), 
                      ScreenUtils.getResponsiveVerticalPadding(context) * 0.5, 
                      ScreenUtils.getResponsiveHorizontalPadding(context), 
                      ScreenUtils.getResponsiveVerticalPadding(context),
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.cardBackground,
                    ),
                    child: Row(
                      children: [
                        // Regenerate/Edit Button (Secondary - Left)
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _handleRegenerate, // FIX: In-place regeneration
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              side: const BorderSide(
                                color: AppColors.textLight,
                              ),
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Column(
                              // Using Column for tight icon+text stacking or Row
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 20),
                                Text(
                                  'Regenerar',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          // flex: 1 by default
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    setState(() => _isSaving = true);
                                    // debugPrint("Confirmar presionado");
                                    try {
                                      // FIX: Save for Today specifically
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
                                      // debugPrint("Error en Confirmar: $e");
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error guardando: $e',
                                            ),
                                          ),
                                        );
                                      }
                                      // Navegar de todos modos para no bloquear
                                      if (context.mounted) {
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
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Confirmar",
                                    style: TextStyle(
                                      fontSize: 16,
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
