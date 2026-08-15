import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'qr_scanner_screen.dart';

Future<void> showAddExtraMealSheet(BuildContext context, AppState appState, DateTime date) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: AddExtraMealBottomSheet(appState: appState, date: date),
    ),
  );
}

class AddExtraMealBottomSheet extends StatefulWidget {
  final AppState appState;
  final DateTime date;

  const AddExtraMealBottomSheet({super.key, required this.appState, required this.date});

  @override
  State<AddExtraMealBottomSheet> createState() => _AddExtraMealBottomSheetState();
}

class _AddExtraMealBottomSheetState extends State<AddExtraMealBottomSheet> {
  final ImagePicker _picker = ImagePicker();
  
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analyzedMeal;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      _analyze(imagePath: image.path);
    }
  }

  Future<void> _analyze({String? text, String? imagePath}) async {
    if (text != null && text.trim().isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analyzedMeal = null;
    });

    final result = await widget.appState.analyzeFood(text: text, imagePath: imagePath);

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _analyzedMeal = result;
      });
    }
  }

  Future<void> _saveMeal() async {
    if (_analyzedMeal == null) return;
    
    setState(() => _isAnalyzing = true); // Repurpose for loading state
    
    final success = await widget.appState.addExtraMeal(widget.date, _analyzedMeal!);
    
    if (mounted) {
      setState(() => _isAnalyzing = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comida extra agregada exitosamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar comida extra')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.all(24.w),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _analyzedMeal == null ? "Añadir Comida Extra" : "Verificar Comida",
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            if (_isAnalyzing) ...[
              SizedBox(height: 40.h),
              const Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
              SizedBox(height: 16.h),
              const Center(
                child: Text(
                  "Analizando con IA...",
                  style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 40.h),
            ] else if (_analyzedMeal != null) ...[
              // RESULT VIEW
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _analyzedMeal!['name'] ?? "Desconocido",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMacroText("Calorías", "${_analyzedMeal!['calories']} kcal"),
                        _buildMacroText("Prot", "${_analyzedMeal!['protein']}g"),
                        _buildMacroText("Carbs", "${_analyzedMeal!['carbs']}g"),
                        _buildMacroText("Grasa", "${_analyzedMeal!['fat']}g"),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMacroText("Vit A", "${_analyzedMeal!['vitamin_a']} mcg"),
                        _buildMacroText("Vit C", "${_analyzedMeal!['vitamin_c']} mg"),
                        _buildMacroText("Calcio", "${_analyzedMeal!['calcium']} mg"),
                        _buildMacroText("Hierro", "${_analyzedMeal!['iron']} mg"),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _analyzedMeal = null),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: const Text("Reintentar"),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveMeal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonDark,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // INPUT VIEW
              Text("¿Cómo quieres añadir tu comida?", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildImageOption(
                      icon: Icons.camera_alt_outlined,
                      label: "Tomar Foto",
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildImageOption(
                      icon: Icons.photo_library_outlined,
                      label: "Galería",
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildImageOption(
                      icon: CupertinoIcons.barcode,
                      label: "Código",
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                        );
                        if (result != null && result is String) {
                          _analyze(text: result);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacroText(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12.sp, color: AppColors.textLight)),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ],
    );
  }

  Widget _buildImageOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32.sp, color: AppColors.textDark),
            SizedBox(height: 8.h),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}
