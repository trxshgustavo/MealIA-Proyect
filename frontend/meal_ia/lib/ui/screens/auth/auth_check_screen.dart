import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);
  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}
class _AuthCheckScreenState extends State<AuthCheckScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutBack),
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final isLoggedIn = await appState.checkLoginStatus();
    if (!mounted) return;
    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/carrot.png',
              width: 150,
              height: 150,
              errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_menu, size: 120, color: AppColors.primaryText),
            ),
          ),
        ),
      ),
    );
  }
}