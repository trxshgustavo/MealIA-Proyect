import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _isLoading = false;

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primaryColor),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
    );
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Ocultar teclado al presionar el botón
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      final result = await appState.login(
        _emailCtl.text.trim(),
        _passwordCtl.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result == "OK") {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submitGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final result = await appState.signInWithGoogle();

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result == "OK_EXISTING") {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else if (result == "OK_NEW") {
        Navigator.pushNamed(context, '/data');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. CORRECCIÓN: GestureDetector envuelve todo para cerrar teclado al tocar fuera
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 30.h), // Top spacing reduced

                      Text(
                        '¡Bienvenid@ a Meal.IA!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 28.sp, // Reduced font slightly
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.h), // Reduced spacing
                      // Flexible container
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: MediaQuery.of(context).viewInsets.bottom > 0
                            ? 0
                            : 0.25.sh,
                        child: Center(
                          child: Image.asset(
                            'assets/carrot.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.error,
                                  color: AppColors.primaryText,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),

                      // Form Container
                      Container(
                        padding: EdgeInsets.all(20.0.w),
                        decoration: BoxDecoration(
                          color: AppColors.formBackground,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 5.r,
                              blurRadius: 15.r,
                              offset: Offset(0, 5.h),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bienvenido de vuelta',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.primaryText,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 16.h),

                              ElevatedButton.icon(
                                icon: Image.asset(
                                  'assets/google_logo.png',
                                  height: 20.0.h,
                                  width: 20.0.w,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.g_mobiledata,
                                        color: Colors.black,
                                      ),
                                ),
                                label: const Text('Ingresar con Google'),
                                onPressed: _isLoading
                                    ? null
                                    : _submitGoogleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              SizedBox(height: 12.h),

                              const Text(
                                'O ingresa con tu correo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 12.h),

                              TextFormField(
                                controller: _emailCtl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration(
                                  'Correo Electrónico',
                                ),
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                ),
                                validator: (v) =>
                                    (v == null || !v.contains('@'))
                                    ? 'Correo no válido'
                                    : null,
                              ),
                              SizedBox(height: 10.h),

                              TextFormField(
                                controller: _passwordCtl,
                                obscureText: true,
                                decoration: _inputDecoration('Contraseña'),
                                style: const TextStyle(
                                  color: AppColors.primaryText,
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Ingresa tu contraseña'
                                    : null,
                              ),
                              SizedBox(height: 16.h),

                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton(
                                      onPressed: _submitLogin,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                      ),
                                      child: Text(
                                        'Ingresar',
                                        style: TextStyle(fontSize: 16.sp),
                                      ),
                                    ),

                              TextButton(
                                onPressed: () async {
                                  // Close keyboard to prevent auto-focus on return
                                  FocusScope.of(context).unfocus();
                                  await Future.delayed(
                                    const Duration(milliseconds: 200),
                                  );
                                  if (context.mounted) {
                                    Navigator.pushNamed(context, '/register');
                                  }
                                },
                                child: const Text(
                                  '¿No tienes cuenta? Regístrate aquí',
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h), // Bottom spacing
                    ],
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
