import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:ui'; // For BackdropFilter
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'food_scanner_screen.dart'; // Import ScannedFood from here

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _cameraError;
  bool _isAnalyzing = false;

  // Results
  List<ScannedFood> _detectedItems = [];

  // Standard Inventory Units
  final List<String> _validUnits = [
    'Unidades',
    'Kg',
    'g',
    'L',
    'ml',
    'oz',
    'lb',
    'paquete',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se necesita permiso de cámara.')),
          );
          setState(() => _cameraError = 'La cámara no tiene permiso. Puedes seleccionar una foto.');
        }
        return;
      }
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No hay cámara disponible. Selecciona una foto.');
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Error camera: $e");
      if (mounted) setState(() => _cameraError = 'No se pudo abrir la cámara. Puedes seleccionar una foto.');
    }
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isAnalyzing) return;
    try {
      final image = await _controller!.takePicture();
      await _analyzeImage(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo tomar la foto: $e')),
        );
      }
    }
  }

  Future<void> _pickImageAndAnalyze() async {
    if (_isAnalyzing) return;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) await _analyzeImage(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la imagen: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage(XFile image) async {
    if (_isAnalyzing || !mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    setState(() {
      _isAnalyzing = true;
      _detectedItems.clear();
    });

    try {
      final bytes = await image.readAsBytes();

      // 1. Intentar análisis con backend (OpenAI GPT-4o Vision + OpenFoodFacts)
      final backendItems = await appState.scanReceipt(bytes, image.name);

      if (backendItems != null && backendItems.isNotEmpty) {
        final List<ScannedFood> parsedItems = backendItems.map((e) {
          final barcode = e['codigo_barras']?.toString();
          final name = e['alimento']?.toString() ?? 'Producto';
          final qty = (e['cantidad_estimada'] is num) ? (e['cantidad_estimada'] as num).toDouble() : 1.0;
          final unit = e['unidad_estimada']?.toString() ?? 'Unidades';
          final cals = (e['calorias'] is num) ? (e['calorias'] as num).toDouble() : 100.0;
          final carbs = (e['carbs'] is num) ? (e['carbs'] as num).toDouble() : 10.0;
          final prot = (e['proteinas'] is num) ? (e['proteinas'] as num).toDouble() : 5.0;
          final fat = (e['grasas'] is num) ? (e['grasas'] as num).toDouble() : 2.0;

          return ScannedFood(
            name: name,
            calories: '${cals.toInt()} kcal',
            info: barcode != null && barcode.isNotEmpty ? 'Código: $barcode' : 'Producto de boleta',
            quantity: qty,
            unit: _validUnits.contains(unit) ? unit : 'Unidades',
            barcode: barcode,
            exactCalories: cals,
            exactProteins: prot,
            exactFats: fat,
            exactCarbs: carbs,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _detectedItems = parsedItems;
          });
        }
        return;
      }

      if (_detectedItems.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectaron productos en la boleta. Asegúrate de enfocar bien el texto.'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al analizar boleta: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _finish() {
    // Return structured list
    final selected = _detectedItems.where((i) => i.isSelected).toList();
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized)
            CameraPreview(_controller!)
          else if (_cameraError != null)
            Center(child: Padding(padding: const EdgeInsets.all(32),
              child: Text(_cameraError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            ))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(top: 50.h, right: 20.w,
            child: _GlassIconButton(icon: Icons.photo_library_outlined,
              onPressed: _pickImageAndAnalyze),
          ),

          // 2. Guide Overlay (Corners) for Scanning area
          if (_detectedItems.isEmpty && !_isAnalyzing)
            const _ScanGuideOverlay(),

          // 3. Close Button (Glassmorphic)
          Positioned(
            top: 50.h,
            left: 20.w,
            child: _GlassIconButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 4. Main Action or Results
          if (_detectedItems.isEmpty && !_isAnalyzing) ...[
            // Shutter Button
            Positioned(
              bottom: 40.h,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _takePictureAndAnalyze,
                  child: const _ShutterButton(),
                ),
              ),
            ),
            Positioned(
              bottom: 120.h,
              left: 0,
              right: 0,
              child: Text(
                "Apunta a la boleta",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 4.r, color: Colors.black87)],
                ),
              ),
            ),
          ] else if (_detectedItems.isNotEmpty) ...[
            // Results Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: _ResultsSheet(
                detectedItems: _detectedItems,
                onFinish: _finish,
                onRetry: _takePictureAndAnalyze,
                validUnits: _validUnits,
                onUpdate: () => setState(() {}),
              ),
            ),
          ],

          // 5. Loading Overlay (Glassmorphic)
          if (_isAnalyzing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.accentColor,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Analizando boleta...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10.r,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component Widgets
// -----------------------------------------------------------------------------

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.2),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _ScanGuideOverlay extends StatelessWidget {
  const _ScanGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerPainter(),
      child: Container(), // Fills the screen
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.w
      ..strokeCap = StrokeCap.round;

    double cornerSize = 40.w;
    double padding = 50.w;

    // Top Left
    canvas.drawLine(
      Offset(padding, padding + cornerSize),
      Offset(padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding + cornerSize, padding),
      paint,
    );

    // Top Right
    canvas.drawLine(
      Offset(size.width - padding - cornerSize, padding),
      Offset(size.width - padding, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerSize),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(padding, size.height - padding - cornerSize),
      Offset(padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerSize, size.height - padding),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(size.width - padding - cornerSize, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80.w,
      height: 80.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4.w),
      ),
      child: Center(
        child: Container(
          width: 64.w,
          height: 64.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ResultsSheet extends StatelessWidget {
  final List<ScannedFood> detectedItems;
  final VoidCallback onFinish;
  final VoidCallback onRetry;
  final VoidCallback onUpdate;
  final List<String> validUnits;

  const _ResultsSheet({
    required this.detectedItems,
    required this.onFinish,
    required this.onRetry,
    required this.onUpdate,
    required this.validUnits,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = detectedItems.any((i) => i.isSelected);

    return Container(
      height: 0.75.sh,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20.r,
            offset: Offset(0, -5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 16.h, bottom: 8.h),
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: detectedItems.length + 1, // +1 for header
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Hemos encontrado esto",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                    ),
                  );
                }

                final item = detectedItems[index - 1];
                return _FoodItemCard(
                  item: item,
                  validUnits: validUnits,
                  onChanged: onUpdate,
                );
              },
            ),
          ),

          // Bottom Actions
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10.r,
                  offset: Offset(0, -5.h),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55.h,
                  child: ElevatedButton(
                    onPressed: hasSelection ? onFinish : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      "Agregar al Inventario",
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text("Escanear de nuevo"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatefulWidget {
  final ScannedFood item;
  final List<String> validUnits;
  final VoidCallback onChanged;

  const _FoodItemCard({
    required this.item,
    required this.validUnits,
    required this.onChanged,
  });

  @override
  State<_FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<_FoodItemCard> {
  late TextEditingController _qtyController;

  String _formatQuantity(double qty) {
    if ((qty - qty.round()).abs() < 0.0001) {
      return qty.round().toString();
    }
    String formatted = qty.toStringAsFixed(2);
    if (formatted.contains('.')) {
      formatted = formatted
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: _formatQuantity(widget.item.quantity),
    );
  }

  void _updateQuantity(double newVal) {
    if (newVal < 0) return;
    setState(() {
      widget.item.quantity = newVal;
      _qtyController.text = _formatQuantity(newVal);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15.r,
            offset: Offset(0, 4.h),
          ),
        ],
        border: widget.item.isSelected
            ? Border.all(color: AppColors.accentColor, width: 2.w)
            : Border.all(color: Colors.transparent, width: 2.w),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          onTap: () {
            setState(() {
              widget.item.isSelected = !widget.item.isSelected;
            });
            widget.onChanged();
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Checkbox
                    Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: Icon(
                        widget.item.isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: widget.item.isSelected
                            ? AppColors.accentColor
                            : Colors.grey[300],
                        size: 28.sp,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          if (widget.item.exactCalories != null)
                            Text(
                              "${widget.item.exactCalories?.toStringAsFixed(0)} kcal/100g • P: ${widget.item.exactProteins?.toStringAsFixed(1)}g | G: ${widget.item.exactFats?.toStringAsFixed(1)}g | C: ${widget.item.exactCarbs?.toStringAsFixed(1)}g",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.green[600],
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Text(
                              "Macros no encontrados para este código",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.orange[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.item.isSelected) ...[
                  SizedBox(height: 15.h), // Divider improved
                  const Divider(),
                  SizedBox(height: 15.h),
                  Row(
                    children: [
                      // Quantity Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, size: 18.sp),
                              onPressed: () =>
                                  _updateQuantity(widget.item.quantity - 1),
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(
                              width: 50.w,
                              child: TextField(
                                controller: _qtyController,
                                textAlign: TextAlign.center,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                onChanged: (val) {
                                  final n = double.tryParse(val);
                                  if (n != null) {
                                    widget.item.quantity = n;
                                    widget.onChanged();
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () =>
                                  _updateQuantity(widget.item.quantity + 1),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Unit Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  widget.validUnits.contains(widget.item.unit)
                                  ? widget.item.unit
                                  : 'Unidades',
                              isExpanded: true,
                              items: widget.validUnits.map((u) {
                                return DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    u,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => widget.item.unit = val);
                                  widget.onChanged();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
