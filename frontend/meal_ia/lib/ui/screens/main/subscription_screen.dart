import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  final Color premiumColor = AppColors.buttonDark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Fondo gris muy suave
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Título claro y directo
            const Text(
              "Mejora tu experiencia",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Saca el máximo provecho a tus ingredientes con MealIA Premium.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),

            // --- PLAN PREMIUM (Destacado pero limpio) ---
            _buildPremiumCard(context),

            const SizedBox(height: 20),

            // --- PLAN GRATIS (Simple) ---
            _buildFreeCard(),

            const SizedBox(height: 30),
            Text(
              "Suscripcion premium puede ser cancelada cuando quieras.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: premiumColor, width: 2), // Borde naranja elegante
        boxShadow: [
          BoxShadow(
            color: premiumColor.withOpacity(0.15), // Sombra suave naranja
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Etiqueta superior sutil
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: premiumColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Text(
              "RECOMENDADO",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  "MealIA Premium",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("\$2.500", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: premiumColor)),
                    Text(" /mes", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 25),
                
                // Lista de beneficios limpia
                _buildFeatureRow("Generación de menús ilimitada", true),
                _buildFeatureRow("Cálculo de macros exactos", true),
                _buildFeatureRow("Sin publicidad", true),
                _buildFeatureRow("Recetas guardadas ilimitadas", true),

                const SizedBox(height: 30),

                // Botón de acción
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Iniciando pago... (Próximamente)")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: premiumColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0, // Flat design
                    ),
                    child: const Text(
                      "Obtener Premium",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!), // Borde gris sutil
      ),
      child: Column(
        children: [
          const Text(
            "Plan Gratuito",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 20),
          _buildFeatureRow("Generación de menú (5 al día)", false),
          _buildFeatureRow("Gestión de inventario básica", false),
          _buildFeatureRow("Recetas con anuncios", false),
          const SizedBox(height: 20),
          const Text(
            "Tu plan actual",
            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            Icons.check,
            color: isPremium ? AppColors.buttonDark : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isPremium ? AppColors.textDark : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}