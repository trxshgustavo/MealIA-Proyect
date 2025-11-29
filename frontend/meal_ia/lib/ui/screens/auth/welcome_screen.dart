import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}
class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Animación de 1 segundo
    );

    // Animación de desvanecimiento para todo
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    // Animación de deslizamiento para la zanahoria y el botón
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // --- Título ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  '¡Hola!\n¡Bienvenid@ a MealApp!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ),
              const SizedBox(height: 60),

              // --- Subtítulo ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Soy 'Meal.IA' y te estaré ayudando a planificar \ntus menús para que cumplas tus objetivos",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 20,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 100),

              // --- Imagen de la Zanahoria ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Image.asset(
                    'assets/saludo_carrot.png',
                    height: 400, // Más grande, como en la foto
                    errorBuilder: (_, __, ___) => const Icon(Icons.error, color: AppColors.primaryText, size: 150),
                  ),
                ),
              ),
              const Spacer(),

              // --- Botón "Comencemos" ---
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navega a la pantalla de Login
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inputFill, // Gris claro
                      foregroundColor: AppColors.primaryText, // Texto oscuro
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Comencemos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40), // Espacio inferior
            ],
          ),
        ),
      ),
    );
  }
}