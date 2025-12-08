import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(color: AppColors.accentColor, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            '$item',
                            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
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
        iconTheme: const IconThemeData(color: AppColors.primaryText, size: 32,),
      ),
      body: SafeArea(
        bottom: false,
        child: menu == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/carrot.png',
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, size: 60),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Total de Hoy',
                                  style: TextStyle(fontSize: 16, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
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
                            mealName: menu['breakfast']?['name'] ?? 'Sugerencia',
                            items: menu['breakfast']?['ingredients'] as List? ?? [],
                            calories: menu['breakfast']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(context, '/recipe', arguments: menu['breakfast']),
                          ),

                          _buildMealCard(
                            context,
                            title: 'Almuerzo',
                            icon: Icons.restaurant,
                            iconColor: Colors.redAccent,
                            mealName: menu['lunch']?['name'] ?? 'Sugerencia',
                            items: menu['lunch']?['ingredients'] as List? ?? [],
                            calories: menu['lunch']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(context, '/recipe', arguments: menu['lunch']),
                          ),

                          _buildMealCard(
                            context,
                            title: 'Cena',
                            icon: Icons.nights_stay_rounded,
                            iconColor: Colors.indigo,
                            mealName: menu['dinner']?['name'] ?? 'Sugerencia',
                            items: menu['dinner']?['ingredients'] as List? ?? [],
                            calories: menu['dinner']?['calories'] ?? 0,
                            onTap: () => Navigator.pushNamed(context, '/recipe', arguments: menu['dinner']),
                          ),

                          const SizedBox(height: 20),

                          if (menu['note'] != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
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

                  // 2. Botón Fijo al Final
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30), // 30 de Padding Bottom
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground, // El mismo fondo para que se funda
                      // Opcional: Una pequeña sombra superior si quieres separarlo
                      // boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, -2))]
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar inventario'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}