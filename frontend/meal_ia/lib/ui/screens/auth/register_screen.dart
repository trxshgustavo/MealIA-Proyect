import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  bool _isLoading = false;

  // Decoración consistente con el Login (ahora con iconos)
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      prefixIcon: Icon(icon, color: AppColors.secondaryText), // Icono agregado
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

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Ocultar teclado
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // 2. Registro en Firebase
      final result = await appState.register(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text.trim(),
        firstName: _firstNameCtl.text.trim(),
      );

      if (!mounted) return;

      if (result == "OK") {
        // 3. Guardar datos extra si el registro fue exitoso
        appState.setPersonalData(
          firstName: _firstNameCtl.text.trim(),
          lastName: _lastNameCtl.text.trim(),
        );

        // Navegar al flujo de datos (Onboarding)
        Navigator.pushNamed(context, '/data');
      } else {
        setState(() => _isLoading = false);
        _showSnackBar(result, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error inesperado: $e", isError: true);
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

      if (result == "OK_NEW" || result == "OK_EXISTING") {
        Navigator.pushNamed(context, '/data');
      } else {
        _showSnackBar(result, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error con Google: $e", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector para cerrar teclado al tocar fuera
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 40.h), // Top spacing

                    Text(
                      '¡Empecemos!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Flexible image or fixed relative height
                    SizedBox(
                      height: 0.2.sh, // 20% of screen height
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
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
                              'Regístrate para comenzar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12.h),

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
                              label: const Text('Registrarse con Google'),
                              onPressed: _isLoading ? null : _submitGoogleLogin,
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
                              'O regístrate con tu correo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Fields compacted
                            TextFormField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                'Correo',
                                Icons.email_outlined,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 14,
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Correo no válido'
                                  : null,
                            ),
                            SizedBox(height: 8.h),

                            TextFormField(
                              controller: _passwordCtl,
                              obscureText: true,
                              decoration: _inputDecoration(
                                'Contraseña',
                                Icons.lock_outline,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 14,
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                            ),
                            SizedBox(height: 8.h),

                            // Fila para Nombre y Apellido
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameCtl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _inputDecoration(
                                      'Nombre',
                                      Icons.person_outline,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Requerido'
                                        : null,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameCtl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: _inputDecoration(
                                      'Apellido',
                                      Icons.person_outline,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 14,
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Requerido'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),

                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: _submitRegister,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12.h,
                                      ),
                                    ),
                                    child: Text(
                                      'Registrar y Continuar',
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                  ),

                            TextButton(
                              onPressed: () async {
                                FocusScope.of(context).unfocus();
                                await SystemChannels.textInput.invokeMethod(
                                  'TextInput.hide',
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 200),
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                '¿Ya tienes cuenta? Inicia sesión',
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
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
