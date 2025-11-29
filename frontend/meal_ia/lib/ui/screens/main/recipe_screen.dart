import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class RecipeScreen extends StatelessWidget {
  const RecipeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? recipeData =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String name = recipeData?['name'] ?? 'Receta Desconocida';
    final int calories = recipeData?['calories'] ?? 0;
    final List<dynamic> ingredients = recipeData?['ingredients'] ?? [];
    final List<dynamic> steps = recipeData?['steps'] ?? [];

    // Color de texto oscuro para la cabecera clara
    final Color headerTextColor = AppColors.primaryText;

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      extendBodyBehindAppBar: true,
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          "Detalle de la Receta",
          // Título en oscuro
          style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold),
        ),
        // Flecha oscura sin fondo
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headerTextColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      
      body: Stack(
        children: [
          // 1. CABECERA HERO (CLARA Y LUMINOSA - DISEÑO CORRECTO)
          Container(
            height: 280,
            width: double.infinity,
            decoration: const BoxDecoration(
              // Degradado suave de blanco al gris de fondo
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white, 
                  AppColors.cardBackground
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Stack(
              children: [
                // Zanahoria a color, visible
                // Contenido de la cabecera
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge de Calorías (Estilo claro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: AppColors.accentColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "$calories kcal",
                              style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Título Grande (Texto oscuro)
                      Text(
                        name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: headerTextColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. TARJETA FLOTANTE (Blanca)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 260, 16, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECCIÓN INGREDIENTES ---
                      _SectionHeader(icon: Icons.shopping_basket_outlined, title: "Ingredientes"),
                      const SizedBox(height: 16),
                      if (ingredients.isEmpty)
                        const Text("No hay ingredientes listados", style: TextStyle(color: Colors.grey)),
                      ...ingredients.map((item) => _IngredientItem(text: item.toString())).toList(),

                      const SizedBox(height: 32),
                      const Divider(color: AppColors.inputFill),
                      const SizedBox(height: 24),

                      // --- SECCIÓN PASOS ---
                      _SectionHeader(icon: Icons.format_list_numbered_rounded, title: "Pasos de preparación"),
                      const SizedBox(height: 20),
                      if (steps.isEmpty)
                        const Text("No hay pasos listados", style: TextStyle(color: Colors.grey)),
                        
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        itemBuilder: (context, index) {
                          return _StepItem(index: index + 1, text: steps[index].toString());
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
      
      // BOTONES FLOTANTES INFERIORES (Estilo oscuro)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.buttonDark),
                  foregroundColor: AppColors.buttonDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Volver"),
              ),
            ),
            const SizedBox(width: 16),
            
            // --- BOTÓN GUARDAR CONECTADO ---
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (recipeData == null) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Guardando receta..."), duration: Duration(seconds: 1))
                  );

                  final appState = Provider.of<AppState>(context, listen: false);
                  final success = await appState.saveRecipeToFavorites(recipeData);

                  if (!context.mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("¡Receta guardada en favoritos!"), backgroundColor: Colors.green)
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error: Ya guardaste esta receta o hubo un fallo."), backgroundColor: Colors.redAccent)
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.bookmark_border_rounded),
                label: const Text("Guardar"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES (Estilo Limpio) ---

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accentColor, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class _IngredientItem extends StatelessWidget {
  final String text;
  const _IngredientItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: AppColors.secondaryText, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String text;
  const _StepItem({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.buttonDark, 
              shape: BoxShape.circle,
            ),
            child: Text(
              "$index",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, color: AppColors.primaryText, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}