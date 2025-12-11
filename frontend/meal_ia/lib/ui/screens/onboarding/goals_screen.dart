import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart'; 

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  Widget _buildGoalCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final app = Provider.of<AppState>(context);
    final bool isSelected = app.goal == value;
    
    return GestureDetector(
      onTap: () {
        Provider.of<AppState>(context, listen: false).saveUserGoal(value);
      },
      child: Card(
        elevation: isSelected ? 10 : 4,
        color: isSelected ? Colors.blueGrey[50] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isSelected ? Colors.blueGrey : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 36, color: Colors.blueGrey[700]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.blueGrey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/carrot.png',
                height: 280,
                width: 280,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag, size: 100, color: AppColors.primaryText),
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(20.0), // Padding interno de la tarjeta
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '¿Cuál es tu meta principal?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildGoalCard(
                      context,
                      title: 'Déficit calórico',
                      subtitle: 'Bajar de peso',
                      icon: Icons.local_fire_department,
                      value: 'Déficit Calórico',
                    ),
                    const SizedBox(height: 12),
                    _buildGoalCard(
                      context,
                      title: 'Mantenimiento',
                      subtitle: 'Conservar tu peso actual',
                      icon: Icons.monitor_weight,
                      value: 'Mantenimiento',
                    ),
                    const SizedBox(height: 12),
                    _buildGoalCard(
                      context,
                      title: 'Aumentar masa muscular',
                      subtitle: 'Ganar peso y músculo',
                      icon: Icons.fitness_center,
                      value: 'Aumentar masa muscular',
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Finalizar y continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}