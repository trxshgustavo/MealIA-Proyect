import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
<<<<<<< HEAD
import 'package:flutter_screenutil/flutter_screenutil.dart';
=======
import '../../../utils/screen_utils.dart';
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

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
    final titleFontSize = ScreenUtils.getTitleFontSize(
      context,
      defaultSize: 40.0,
    );
    final imageSize = ScreenUtils.getResponsiveImageSize(
      context,
      baseSize: 180.0,
    );
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalSpacing = ScreenUtils.getVerticalSpacing(
      context,
      defaultSpacing: 40.0,
    );
    final formPadding = ScreenUtils.getFormPadding(context);
    final topSpacing = ScreenUtils.getHeight(context) * 0.02;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
<<<<<<< HEAD
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0.w),
=======
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black54),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ScreenUtils.getMaxContainerWidth(context),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
<<<<<<< HEAD
                    SizedBox(height: 40.h), // Top spacing
=======
                    SizedBox(height: topSpacing),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

                    Text(
                      '¡Empecemos!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryText,
<<<<<<< HEAD
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
=======
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: verticalSpacing),

                    Image.asset(
                      'assets/carrot.png',
                      height: imageSize,
                      width: imageSize,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error, color: AppColors.primaryText),
                    ),
                    SizedBox(height: verticalSpacing),

                    Container(
                      padding: formPadding,
                      decoration: BoxDecoration(
                        color: AppColors.formBackground,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.2),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
<<<<<<< HEAD
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
=======
                          children: [
                            const Text(
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                              'Regístrate para comenzar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primaryText,
<<<<<<< HEAD
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12.h),
=======
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

                            ElevatedButton.icon(
                              icon: Image.asset(
                                'assets/google_logo.png',
<<<<<<< HEAD
                                height: 20.0.h,
                                width: 20.0.w,
=======
                                height: 22.0,
                                width: 22.0,
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
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
<<<<<<< HEAD
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
=======
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
<<<<<<< HEAD
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
=======
                            const SizedBox(height: 16),
                            const Text(
                              'O regístrate con tu correo',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 16),

                            // --- CAMPOS DE TEXTO ---
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                            TextFormField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
<<<<<<< HEAD
                                'Correo',
=======
                                'Correo Electrónico',
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                                Icons.email_outlined,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
<<<<<<< HEAD
                                fontSize: 14,
=======
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Correo no válido'
                                  : null,
                            ),
<<<<<<< HEAD
                            SizedBox(height: 8.h),
=======
                            const SizedBox(height: 12),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

                            TextFormField(
                              controller: _passwordCtl,
                              obscureText: true,
                              decoration: _inputDecoration(
                                'Contraseña',
                                Icons.lock_outline,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
<<<<<<< HEAD
                                fontSize: 14,
=======
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                            ),
<<<<<<< HEAD
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
=======
                            const SizedBox(height: 12),

                            // Fila para Nombre y Apellido (Opcional: los dejé en columna para seguridad en pantallas chicas)
                            TextFormField(
                              controller: _firstNameCtl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecoration(
                                'Nombre',
                                Icons.person_outline,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Ingresa tu nombre'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _lastNameCtl,
                              textCapitalization: TextCapitalization.words,
                              decoration: _inputDecoration(
                                'Apellido',
                                Icons.person_outline,
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                              ),
                            ),

                            const SizedBox(height: 20),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f

                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: _submitRegister,
<<<<<<< HEAD
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12.h,
                                      ),
                                    ),
                                    child: Text(
                                      'Registrar y Continuar',
                                      style: TextStyle(fontSize: 16.sp),
=======
                                    child: const Text(
                                      'Registrar y Continuar',
                                      style: TextStyle(fontSize: 16),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                                    ),
                                  ),

                            TextButton(
<<<<<<< HEAD
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
=======
                              onPressed: () =>
                                  Navigator.pop(context), // Vuelve a Login
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                              child: const Text(
                                '¿Ya tienes cuenta? Inicia sesión',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.secondaryText,
<<<<<<< HEAD
                                  fontSize: 12,
=======
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
<<<<<<< HEAD
                    SizedBox(height: 20.h),
=======
                    SizedBox(height: ScreenUtils.getElementSpacing(context)),
>>>>>>> f07a5d1764c53e5a13e8d8f232938d6fa0f8b50f
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
