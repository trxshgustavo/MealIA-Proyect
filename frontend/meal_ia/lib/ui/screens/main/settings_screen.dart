import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- ESTADO LOCAL ---
  bool _notificationsEnabled = true;
  bool _emailUpdates = false;
  String _selectedLanguage = 'Español';
  
  // Controladores de texto para el formulario
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  @override
  void dispose() {
    // Limpiamos memoria al salir
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Ajustes",
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // --- GENERAL ---
            _buildSectionHeader("General"),
            _buildSettingsCard(
              children: [
                _buildListTile(
                  icon: Icons.language,
                  title: "Idioma",
                  subtitle: _selectedLanguage,
                  onTap: _showLanguageDialog,
                ),
              ],
            ),

            const SizedBox(height: 25),

            // --- NOTIFICACIONES ---
            _buildSectionHeader("Notificaciones"),
            _buildSettingsCard(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: "Push Notifications",
                  subtitle: "Avisos de comidas y rutinas",
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.mail_outline,
                  title: "Newsletter",
                  subtitle: "Recibe tips y actualizaciones",
                  value: _emailUpdates,
                  onChanged: (val) => setState(() => _emailUpdates = val),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // --- SEGURIDAD ---
            _buildSectionHeader("Seguridad"),
            _buildSettingsCard(
              children: [
                _buildListTile(
                  icon: Icons.lock_outline,
                  title: "Cambiar contraseña",
                  onTap: _showChangePasswordDialog,
                ),
              ],
            ),

            const SizedBox(height: 25),

            // --- INFORMACIÓN ---
            _buildSectionHeader("Información"),
            _buildSettingsCard(
              children: [
                _buildListTile(
                  icon: Icons.description_outlined,
                  title: "Términos y Condiciones",
                  onTap: () => _showLegalInfo("Términos y Condiciones"),
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "Política de Privacidad",
                  onTap: () => _showLegalInfo("Política de Privacidad"),
                ),
                _buildDivider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.code, color: Colors.grey),
                  ),
                  title: const Text("Versión de la App", style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Text("v1.0.2", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE CAMBIO DE CONTRASEÑA (ROBUSTA) ---

  Future<void> _changePassword() async {
    // 1. Validaciones previas (Sin llamar a Firebase aún)
    if (_newPassController.text != _confirmPassController.text) {
      _showMessage("Las contraseñas nuevas no coinciden", isError: true);
      return;
    }
    if (_newPassController.text.length < 6) {
      _showMessage("La contraseña debe tener al menos 6 caracteres", isError: true);
      return;
    }

    // 2. Mostrar Indicador de Carga
    // Usamos una variable para rastrear si el diálogo está abierto
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'No hay usuario activo');
      }

      // IMPORTANTE: Firebase requiere re-autenticar antes de cambios sensibles
      final email = user.email;
      if (email == null) {
         throw FirebaseAuthException(code: 'no-email', message: 'Usuario sin email');
      }

      // 3. Re-autenticación
      AuthCredential credential = EmailAuthProvider.credential(
        email: email, 
        password: _currentPassController.text.trim() // trim limpia espacios
      );

      await user.reauthenticateWithCredential(credential);

      // 4. Actualizar contraseña
      await user.updatePassword(_newPassController.text.trim());

      // 5. ÉXITO: Cerrar Carga y luego Cerrar Formulario
      if (mounted) Navigator.pop(context); // Cierra Carga
      if (mounted) Navigator.pop(context); // Cierra Diálogo de Formulario

      _showMessage("¡Contraseña actualizada correctamente!", isError: false);
      
      // Limpiar campos
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();

    } on FirebaseAuthException catch (e) {
      // 6. ERROR DE FIREBASE: Primero cerramos la carga
      if (mounted) Navigator.pop(context); 

      String errorMsg = "Ocurrió un error.";
      switch (e.code) {
        case 'wrong-password':
          errorMsg = "La contraseña actual es incorrecta.";
          break;
        case 'weak-password':
          errorMsg = "La nueva contraseña es muy débil.";
          break;
        case 'requires-recent-login':
          errorMsg = "Por seguridad, cierra sesión y vuelve a entrar.";
          break;
        default:
          errorMsg = "Error: ${e.message}";
      }
      _showMessage(errorMsg, isError: true);

    } catch (e) {
      // 7. OTROS ERRORES: Primero cerramos la carga
      if (mounted) Navigator.pop(context);
      _showMessage("Error inesperado: $e", isError: true);
    }
  }

  // Método auxiliar para mostrar mensajes seguros
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.buttonDark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.buttonDark, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value ? AppColors.buttonDark.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: value ? AppColors.buttonDark : Colors.grey, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
      value: value,
      activeTrackColor: AppColors.buttonDark,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, indent: 60, endIndent: 0);
  }

  // --- DIÁLOGOS ---

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Seguridad"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Confirma tu contraseña actual para establecer una nueva.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña actual",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Nueva contraseña",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirmar nueva",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.check_circle_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Limpiamos al cancelar
              _currentPassController.clear();
              _newPassController.clear();
              _confirmPassController.clear();
              Navigator.pop(context);
            },
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Actualizar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Seleccionar Idioma", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Text("🇪🇸", style: TextStyle(fontSize: 24)),
                title: const Text("Español"),
                trailing: _selectedLanguage == 'Español' ? const Icon(Icons.check, color: AppColors.buttonDark) : null,
                onTap: () {
                  setState(() => _selectedLanguage = 'Español');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
                title: const Text("English"),
                trailing: _selectedLanguage == 'English' ? const Icon(Icons.check, color: AppColors.buttonDark) : null,
                onTap: () {
                  setState(() => _selectedLanguage = 'English');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegalInfo(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
                style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Entendido", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}