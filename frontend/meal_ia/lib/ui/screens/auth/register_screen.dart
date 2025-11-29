import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtl = TextEditingController();
  final _lastNameCtl = TextEditingController();
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

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final result = await appState.register(
      email: _emailCtl.text.trim(),
      password: _passwordCtl.text.trim(),
      firstName: _firstNameCtl.text.trim(),
    );
    if (!mounted) return;

    if (result == "OK") {
      appState.setPersonalData(
        firstName: _firstNameCtl.text.trim(),
        lastName: _lastNameCtl.text.trim(),
      );
      Navigator.pushNamed(context, '/data');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogleLogin() async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final result = await appState.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == "OK_NEW" || result == "OK_EXISTING") {
      Navigator.pushNamed(context, '/data');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
      );
    }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

              const Text(
                '¡Empecemos!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),

              Image.asset(
                'assets/carrot.png',
                height: 300,
                width: 300,
                errorBuilder: (_, __, ___) => const Icon(Icons.error, color: AppColors.primaryText),
              ),
              const SizedBox(height: 60),

              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                    color: AppColors.formBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 5,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ]
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Regístrate para comenzar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        icon: Image.asset('assets/google_logo.png', height: 22.0, width: 22.0,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.black)),
                        label: const Text('Registrarse con Google'),
                        onPressed: _isLoading ? null : _submitGoogleLogin,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey[300]!)
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'O regístrate con tu correo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('Correo Electrónico'),
                        style: const TextStyle(color: AppColors.primaryText),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Correo no válido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtl,
                        obscureText: true,
                        decoration: _inputDecoration('Contraseña'),
                        style: const TextStyle(color: AppColors.primaryText),
                        validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firstNameCtl,
                        decoration: _inputDecoration('Nombre'),
                        style: const TextStyle(color: AppColors.primaryText),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu nombre' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameCtl,
                        decoration: _inputDecoration('Apellido'),
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 20),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _submitRegister,
                        child: const Text('Registrar y Continuar', style: TextStyle(fontSize: 16)),
                      ),

                      TextButton(
                        onPressed: () => Navigator.pop(context), // Vuelve a Login
                        child: const Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(color: AppColors.secondaryText, decoration: TextDecoration.underline, decorationColor: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}