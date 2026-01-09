import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../../../utils/screen_utils.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Configuración de Animaciones
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtener valores responsive usando ScreenUtils
    final titleFontSize = ScreenUtils.getTitleFontSize(context);
    final subtitleFontSize = ScreenUtils.getSubtitleFontSize(context);
    final buttonFontSize = ScreenUtils.getButtonFontSize(context);
    final imageHeight = ScreenUtils.getImageHeight(context);
    final verticalSpacing = ScreenUtils.getVerticalSpacing(context);
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalPadding = ScreenUtils.getResponsiveVerticalPadding(context);
    final isVerySmall = ScreenUtils.isVerySmallHeight(context);
    final isSmall = ScreenUtils.isSmallScreen(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isVerySmall) const Spacer(flex: 1),

                        // --- Título ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            '¡Hola!\n¡Bienvenid@ a MealApp!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: verticalSpacing * 0.6),

                        // --- Subtítulo ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 0 : 20.0,
                            ),
                            child: Text(
                              "Soy 'Meal.IA' y te estaré ayudando a planificar \ntus menús para que cumplas tus objetivos",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: subtitleFontSize,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: verticalSpacing),

                        // --- IMAGEN ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: imageHeight,
                              ),
                              child: Image.asset(
                                'assets/saludo_carrot.png',
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),

                        if (!isVerySmall) const Spacer(flex: 1),
                        if (isVerySmall)
                          SizedBox(height: verticalSpacing * 0.5),

                        // --- Botón "Comencemos" ---
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.inputFill,
                                foregroundColor: AppColors.primaryText,
                                padding: ScreenUtils.getButtonPadding(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Comencemos',
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isVerySmall ? 20.0 : 40.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
