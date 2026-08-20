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
  Map<String, dynamic>? _baseAnalyzedMeal;
  double _quantity = 1.0;
  final TextEditingController _qtyController = TextEditingController(text: "1");

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

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
      _baseAnalyzedMeal = null;
      _quantity = 1.0;
      _qtyController.text = "1";
    });

    final result = await widget.appState.analyzeFood(text: text, imagePath: imagePath);

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        if (result != null) {
          _baseAnalyzedMeal = Map.from(result);
          _analyzedMeal = Map.from(result);
        } else {
          _analyzedMeal = null;
        }
      });

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo identificar la comida. Intenta de nuevo o toma una foto más clara.'),
          ),
        );
      }
    }
  }

  void _updateQuantity(double newQty) {
    if (newQty < 0.1) return;
    if (_baseAnalyzedMeal == null) return;
    
    setState(() {
      _quantity = newQty;
      _qtyController.text = _quantity.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      
      // Multiplicar base
      _analyzedMeal!['calories'] = ((_baseAnalyzedMeal!['calories'] as num) * _quantity).round();
      _analyzedMeal!['protein'] = ((_baseAnalyzedMeal!['protein'] as num) * _quantity).round();
      _analyzedMeal!['carbs'] = ((_baseAnalyzedMeal!['carbs'] as num) * _quantity).round();
      _analyzedMeal!['fat'] = ((_baseAnalyzedMeal!['fat'] as num) * _quantity).round();
      
      if (_baseAnalyzedMeal!['vitamin_a'] != null) _analyzedMeal!['vitamin_a'] = double.parse(((_baseAnalyzedMeal!['vitamin_a'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['vitamin_c'] != null) _analyzedMeal!['vitamin_c'] = double.parse(((_baseAnalyzedMeal!['vitamin_c'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['calcium'] != null) _analyzedMeal!['calcium'] = double.parse(((_baseAnalyzedMeal!['calcium'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['iron'] != null) _analyzedMeal!['iron'] = double.parse(((_baseAnalyzedMeal!['iron'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['fiber'] != null) _analyzedMeal!['fiber'] = double.parse(((_baseAnalyzedMeal!['fiber'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['sugar'] != null) _analyzedMeal!['sugar'] = double.parse(((_baseAnalyzedMeal!['sugar'] as num) * _quantity).toStringAsFixed(1));
      if (_baseAnalyzedMeal!['sodium'] != null) _analyzedMeal!['sodium'] = ((_baseAnalyzedMeal!['sodium'] as num) * _quantity).round();
    });
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _analyzedMeal!['name'] ?? "Desconocido",
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                onPressed: () => _updateQuantity(_quantity - 0.25),
                                visualDensity: VisualDensity.compact,
                              ),
                              SizedBox(
                                width: 45.w,
                                child: TextField(
                                  controller: _qtyController,
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.textDark),
                                  onSubmitted: (val) {
                                    final n = double.tryParse(val);
                                    if (n != null) _updateQuantity(n);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () => _updateQuantity(_quantity + 0.25),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
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
