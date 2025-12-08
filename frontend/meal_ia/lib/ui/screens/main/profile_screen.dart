import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  
  File? _imageFile; // Para la vista previa local
  final ImagePicker _picker = ImagePicker(); // Para acceder a la cámara/galería

  // --- LÓGICA DE SESIÓN ---
  Future<void> _logout() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // --- LÓGICA DE FOTOS ---
  
  // 1. Botón principal al tocar el avatar
  void _uploadPhoto() {
    _showImageSourceActionSheet(context);
  }

  // 2. Selector de imagen (Cámara / Galería)
  Future<void> _pickImage(ImageSource source) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        
        // Vista previa inmediata
        setState(() {
          _imageFile = imageFile;
        });

        // Subir al servidor
        final success = await appState.uploadProfilePicture(imageFile);

        if (!mounted) return;

        if (success) {
          setState(() {
            _imageFile = null; // Ya no necesitamos la local, usamos la URL
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Colors.green),
          );
        } else {
          setState(() {
            _imageFile = null; // Revertir si falla
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Error al subir la foto'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      // print("Error en _pickImage: $e");
    }
  }

  // 3. Función para borrar la foto
  Future<void> _deleteImage() async {
    setState(() { _imageFile = null; }); // Quita la vista previa local
    
    final appState = Provider.of<AppState>(context, listen: false);
    final success = await appState.deleteProfilePicture();

    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // 4. Menú inferior (Action Sheet)
  void _showImageSourceActionSheet(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    // Verificamos si hay una foto para decidir si mostramos el botón "Eliminar"
    final bool hasPhoto = _imageFile != null || (appState.photoUrl != null && appState.photoUrl!.isNotEmpty);

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
            
            // --- BOTÓN ELIMINAR (Solo si hay foto) ---
            if (hasPhoto) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Eliminar foto actual', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteImage();
                },
              ),
            ]
          ],
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
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsItem(
                    title: 'Configuracion general',
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  _buildSettingsItem(
                    title: 'Datos personales',
                    onTap: () {
                      Navigator.pushNamed(context, '/data');
                    },
                  ),
                ],
              ),
              _buildSettingsCard(
                context,
                children: [
                  _buildSettingsItem(
                    title: 'Suscripción',
                    onTap: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                  ),
                  _buildSettingsItem(
                    title: 'Invitar amigos',
                    onTap: () {
                      // TODO: Invitar
                    },
                  ),
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

  // --- WIDGETS AYUDANTES ---

  Widget _buildUserInfoCard(BuildContext context, AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // Fondo gris claro
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          GestureDetector(
            onTap: _uploadPhoto,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: AppColors.cardDark,
              // Lógica de visualización de imagen
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!) as ImageProvider // 1. Vista previa local
                  : (appState.photoUrl != null && appState.photoUrl!.isNotEmpty)
                      ? NetworkImage(appState.photoUrl!)     // 2. Imagen del backend
                      : null,                               // 3. (Usa backgroundColor)
              child: null, 
            ),
          ),
          const SizedBox(width: 50), 
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- AQUÍ ESTÁ EL CAMBIO DE NOMBRE Y APELLIDO ---
                Text(
                  "${appState.firstName ?? 'Usuario'} ${appState.lastName ?? ''}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  appState.goal, 
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 0,
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
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: AppColors.cardBackground),
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
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.secondaryText,
      ),
      onTap: onTap,
    );
  }
}