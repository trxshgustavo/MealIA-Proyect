import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
    final titleFontSize = ScreenUtils.getTitleFontSize(
      context,
      defaultSize: 40.0,
    );
    final imageSize = ScreenUtils.getResponsiveImageSize(
      context,
      baseSize: 300.0,
    );
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalSpacing = ScreenUtils.getVerticalSpacing(
      context,
      defaultSpacing: 80.0,
    );
    final formPadding = ScreenUtils.getFormPadding(context);
    final topSpacing = ScreenUtils.getHeight(context) * 0.05;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topSpacing),

                    Text(
                      '¡Bienvenid@ a Meal.IA!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryText,
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
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Bienvenido de vuelta',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),

                            ElevatedButton.icon(
                              icon: Image.asset(
                                'assets/google_logo.png',
                                height: 22.0,
                                width: 22.0,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.g_mobiledata,
                                      color: Colors.black,
                                    ),
                              ),
                              label: const Text('Ingresar con Google'),
                              onPressed: _isLoading ? null : _submitGoogleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'O ingresa con tu correo',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                'Correo Electrónico',
                              ),
                              style: const TextStyle(
                                color: AppColors.primaryText,
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Correo no válido'
                                  : null,
                            ),
                            const SizedBox(height: 12),

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
                            const SizedBox(height: 24),

                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: _submitLogin,
                                    child: const Text(
                                      'Ingresar',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),

                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/register'),
                              child: const Text(
                                '¿No tienes cuenta? Regístrate aquí',
                                style: TextStyle(
                                  color: AppColors.secondaryText,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: ScreenUtils.getElementSpacing(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
