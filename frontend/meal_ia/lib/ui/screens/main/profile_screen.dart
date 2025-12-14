import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../legal/legal_screen.dart';
import '../../../utils/screen_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _imageFile; // Para la vista previa local
  final ImagePicker _picker = ImagePicker();

  // --- ESTADO LOCAL (Migrado de Settings) ---

  // Controladores de texto para el formulario
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE SESIÓN ---
  Future<void> _logout() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // --- LÓGICA DE FOTOS ---
  void _uploadPhoto() {
    _showImageSourceActionSheet(context);
  }

  Future<void> _pickImage(ImageSource source) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        setState(() {
          _imageFile = imageFile;
        });

        final success = await appState.uploadProfilePicture(imageFile);

        if (!mounted) return;

        if (success) {
          setState(() {
            _imageFile = null;
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil actualizada'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _imageFile = null;
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Error al subir la foto'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      // print("Error en _pickImage: $e");
    }
  }

  Future<void> _deleteImage() async {
    setState(() {
      _imageFile = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);
    final success = await appState.deleteProfilePicture();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto eliminada'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    final bool hasPhoto = _imageFile != null;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto (Cámara)'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (hasPhoto) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Eliminar foto actual',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteImage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE CAMBIO DE CONTRASEÑA ---

  Future<void> _changePassword() async {
    if (_newPassController.text != _confirmPassController.text) {
      _showMessage("Las contraseñas nuevas no coinciden", isError: true);
      return;
    }
    if (_newPassController.text.length < 6) {
      _showMessage(
        "La contraseña debe tener al menos 6 caracteres",
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var user = FirebaseAuth.instance.currentUser;
      final appState = Provider.of<AppState>(context, listen: false);

      if (user == null) {
        final email = appState.email;
        if (email != null) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: _currentPassController.text.trim(),
            );
            user = FirebaseAuth.instance.currentUser;
          } catch (e) {
            String errorMsg = "La contraseña no coincide con la de Firebase.";
            if (e is FirebaseAuthException) {
              if (e.code == 'wrong-password' ||
                  e.code == 'INVALID_LOGIN_CREDENTIALS') {
                errorMsg = "Contraseña actual incorrecta.";
              }
            }
            _showMessage(errorMsg, isError: true);
            if (mounted) Navigator.pop(context);
            return;
          }
        }
      }

      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No hay usuario activo.',
        );
      }
      final email = user.email;
      if (email == null) {
        throw FirebaseAuthException(
          code: 'no-email',
          message: 'Usuario sin email',
        );
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPassController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPassController.text.trim());

      final backendResult = await appState.updateBackendPassword(
        _newPassController.text.trim(),
      );

      if (backendResult != "OK") {
        _showMessage(
          "Actualizado en Firebase pero falló en servidor: $backendResult",
          isError: true,
        );
      }

      if (mounted) Navigator.pop(context); // Cierra Carga
      if (mounted) Navigator.pop(context); // Cierra Diálogo

      _showMessage("¡Contraseña actualizada correctamente!", isError: false);

      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage("Error: ${e.message}", isError: true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showMessage("Error inesperado: $e", isError: true);
    }
  }

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

  // --- DIÁLOGOS Y HELPERS ---

  void _showChangePasswordDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool hasPasswordProvider = user.providerData.any(
        (u) => u.providerId == 'password',
      );
      if (!hasPasswordProvider) {
        _showMessage(
          "Iniciaste sesión con red social. No puedes cambiar contraseña aquí.",
          isError: true,
        );
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(
              ScreenUtils.getResponsiveHorizontalPadding(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Cambiar Contraseña",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ScreenUtils.getSubtitleFontSize(context),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: _currentPassController,
                  label: "Contraseña actual",
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 15),
                _buildPasswordField(
                  controller: _newPassController,
                  label: "Nueva contraseña",
                  icon: Icons.vpn_key_outlined,
                ),
                const SizedBox(height: 15),
                _buildPasswordField(
                  controller: _confirmPassController,
                  label: "Confirmar nueva",
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonDark,
                        ),
                        child: const Text(
                          "Actualizar",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildUserInfoCard(context, appState),

              // 1. CUENTA
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsItem(
                    title: 'Datos personales',
                    onTap: () => Navigator.pushNamed(context, '/data'),
                  ),
                  _buildSettingsItem(
                    title: 'Cambiar contraseña',
                    onTap: _showChangePasswordDialog,
                  ),
                  _buildSettingsItem(
                    title: 'Suscripción',
                    onTap: () => Navigator.pushNamed(context, '/subscription'),
                  ),
                ],
              ),

              // 4. LEGAL
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsItem(
                    title: 'Términos y Condiciones',
                    onTap: () => _openLegal(
                      context,
                      'Términos',
                      'terms_and_conditions.md',
                    ),
                  ),
                  _buildSettingsItem(
                    title: 'Política de Privacidad',
                    onTap: () =>
                        _openLegal(context, 'Privacidad', 'privacy_policy.md'),
                  ),
                  _buildSettingsItem(
                    title: 'Descargo de Responsabilidad',
                    onTap: () =>
                        _openLegal(context, 'Descargo', 'disclaimer.md'),
                  ),
                ],
              ),

              // 5. CERRAR SESIÓN
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsItem(
                    title: 'Cerrar Sesión',
                    onTap: _logout,
                    isDestructive: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openLegal(BuildContext context, String title, String file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalScreen(title: title, mdFileName: file),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, AppState appState) {
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalPadding = ScreenUtils.getResponsiveVerticalPadding(context);
    final isSmallScreen = ScreenUtils.isSmallScreen(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(horizontalPadding),
      margin: EdgeInsets.fromLTRB(
        horizontalPadding * 0.67,
        horizontalPadding * 0.67,
        horizontalPadding * 0.67,
        verticalPadding * 0.67,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadPhoto,
            child: CircleAvatar(
              radius: isSmallScreen ? 50 : 70,
              backgroundColor: AppColors.cardDark,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!) as ImageProvider
                  : (appState.photoUrl != null && appState.photoUrl!.isNotEmpty)
                  ? NetworkImage(appState.photoUrl!)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${appState.firstName ?? 'Usuario'} ${appState.lastName ?? ''}",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                Text(
                  appState.goal,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalSpacing = ScreenUtils.getVerticalSpacing(
      context,
      defaultSpacing: 10.0,
    );

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding * 0.67,
        vertical: verticalSpacing * 0.5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == 0) return children[index];
          return Column(
            children: [
              const Divider(height: 1, indent: 16, endIndent: 16),
              children[index],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    String? subtitle,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : AppColors.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.secondaryText,
      ),
      onTap: onTap,
    );
  }
}
