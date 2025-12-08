import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAnnual = false; 

  // Colores locales
  final Color activeColor = AppColors.buttonDark;
  final Color darkText = AppColors.textDark;

  final List<Map<String, dynamic>> _slides = [
    {
      "title": "Libertad en tu cocina",
      "desc": "Genera menús ilimitados adaptados a lo que tienes en tu refrigerador.",
      "icon": Icons.kitchen_rounded,
    },
    {
      "title": "Nutrición Inteligente",
      "desc": "Seguimiento automático de macros y calorías para cumplir tus metas.",
      "icon": Icons.pie_chart_rounded,
    },
    {
      "title": "Modo Chef Pro",
      "desc": "Guarda recetas, crea listas de compras y cocina sin publicidad.",
      "icon": Icons.star_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Variables de precio
    final String price = _isAnnual ? "\$25.000" : "\$2.500";
    final String period = _isAnnual ? "/ año" : "/ mes";
    final String savings = _isAnnual ? "¡Ahorras un 20%!" : "Puedes cancelar tu suscripcion cuando quieras";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, 
        child: Column(
          children: [
            // --- 1. SECCIÓN SUPERIOR (CARRUSEL) ---
            Expanded(
              child: Stack(
                children: [
                   // Fondo decorativo
                  Positioned(
                    top: -80,
                    right: -80,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Contenido del Carrusel
                  Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemCount: _slides.length,
                          itemBuilder: (context, index) => _buildSlide(_slides[index]),
                        ),
                      ),
                      
                      // INDICADORES (Puntitos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: _currentPage == index ? 24 : 6,
                              decoration: BoxDecoration(
                                color: _currentPage == index 
                                    ? activeColor 
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- 2. SECCIÓN INFERIOR (PAGO) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  // Toggle Mensual / Anual
                  _buildPricingToggle(),

                  const SizedBox(height: 30),

                  // Precio Animado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 0),
                    child: Column(
                      key: ValueKey<bool>(_isAnnual),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              price,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: darkText,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          savings,
                          style: TextStyle(
                            fontSize: 14,
                            color: _isAnnual ? Colors.green[600] : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Botón de Acción
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Procesando suscripción...")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        elevation: 8,
                        shadowColor: activeColor.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Comenzar Ahora",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[500], // Color gris sutil al presionar
                    ),
                    child: const Text(
                      "Seguir con el plan actual",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey, // Texto gris para indicar secundario// Opcional: subrayado
                        decorationColor: Colors.grey,
                      )
                    )
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton("Mensual", !_isAnnual),
          _buildToggleButton("Anual", _isAnnual),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAnnual = text == "Anual";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.textDark : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(slide['icon'], size: 70, color: activeColor),
          ),
          const SizedBox(height: 25),
          Text(
            slide['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: darkText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide['desc'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}