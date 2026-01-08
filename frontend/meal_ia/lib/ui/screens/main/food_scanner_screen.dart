import 'dart:io';
import 'dart:convert';
import 'dart:ui'; // For BackdropFilter
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Export ScannedFood for use in InventoryScreen
class ScannedFood {
  final String name;
  final String calories;
  final String info;
  double quantity;
  String unit;
  bool isSelected;

  ScannedFood({
    required this.name,
    required this.calories,
    required this.info,
    this.quantity = 1.0,
    this.unit = 'Unidades',
    this.isSelected = false,
  });

  factory ScannedFood.fromJson(Map<String, dynamic> json) {
    // Helper to parse "2 kg", "500 g", etc.
    double q = 1.0;
    String u = 'Unidades';

    if (json['cantidad_estimada'] != null) {
      // Try to parse number
      q = double.tryParse(json['cantidad_estimada'].toString()) ?? 1.0;
    }

    if (json['unidad_estimada'] != null) {
      u = json['unidad_estimada'].toString();
    }

    return ScannedFood(
      name: json['alimento'] ?? 'Desconocido',
      calories: json['calorias']?.toString() ?? '?',
      info: json['info'] ?? '',
      quantity: q,
      unit: u,
      isSelected: true,
    );
  }
}

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
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
    var status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de cámara.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Error camera: $e");
    }
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isAnalyzing) {
      return;
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falta GEMINI_API_KEY'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _detectedItems.clear();
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // Updated model list based on user's successful access
      final modelsToTry = [
        'gemini-2.5-flash',
        'gemini-flash-latest',
        'gemini-2.0-flash',
        'gemini-2.0-flash-exp',
      ];

      String? resultText;
      Object? firstError;

      for (final modelName in modelsToTry) {
        try {
          debugPrint("Attempting model: $modelName");
          final model = GenerativeModel(model: modelName, apiKey: apiKey);

          final prompt = Content.multi([
            TextPart(
              'Analiza la imagen y detecta los alimentos. '
              'Devuelve un JSON ARRAY estrictamente válido. '
              'Schema: [{"alimento": "Nombre", "cantidad_estimada": 1.0, "unidad_estimada": "Unidades/Kg/g/L/ml/oz/lb/paquete", "calorias": 100, "info": "breve descripción"}]. '
              'Intenta estimar la cantidad visible (ej: 2 manzanas -> cantidad=2, unidad=Unidades). '
              'Usa "Unidades" si es contable. Usa "g" o "Kg" si es peso. '
              'Si no ves alimentos, devuelve []. '
              'NO uses markdown. Solo JSON plano.',
            ),
            DataPart('image/jpeg', bytes),
          ]);

          final response = await model.generateContent([prompt]);
          resultText = response.text;

          if (resultText != null) {
            debugPrint("Success with model: $modelName");
            break;
          }
        } catch (e) {
          debugPrint("Failed with model $modelName: $e");
          firstError ??= e;
        }
      }

      if (resultText != null) {
        String cleanJson = resultText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        try {
          final List<dynamic> decoded = jsonDecode(cleanJson);
          setState(() {
            _detectedItems = decoded
                .map((e) => ScannedFood.fromJson(e))
                .toList();
            // Validate units against allowlist
            for (var item in _detectedItems) {
              if (!_validUnits.contains(item.unit)) {
                item.unit = 'Unidades'; // Fallback
              }
            }
          });

          if (_detectedItems.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No detecté comida clara.')),
              );
            }
          }
        } catch (e) {
          debugPrint("Error parsing JSON: $resultText");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al interpretar la IA. Intenta otra vez.'),
              ),
            );
          }
        }
      } else {
        // Debug fallback
        String debugInfo = "No info";
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
          );
          final debugResponse = await http.get(url);
          if (debugResponse.statusCode == 200) {
            final json = jsonDecode(debugResponse.body);
            final models = (json['models'] as List)
                .map((m) => m['name'])
                .where((n) => n.toString().toLowerCase().contains('gemini'))
                .join('\n');
            debugInfo = "Modelos DISPONIBLES:\n$models";
          } else {
            debugInfo = "Error listando: ${debugResponse.statusCode}";
          }
        } catch (e) {
          debugInfo = "Falló debug: $e";
        }
        throw Exception(
          "Fallo total. Primer error: $firstError. \n\n$debugInfo",
        );
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: SingleChildScrollView(
              child: Text(e.toString().replaceAll('Exception:', '')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
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
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

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
                "Apunta a la comida",
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
                        "Analizando alimentos...",
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

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
  }

  void _updateQuantity(double newVal) {
    if (newVal < 0) return;
    setState(() {
      widget.item.quantity = newVal;
      // Handle floating point nicely for display
      _qtyController.text = (newVal % 1 == 0)
          ? newVal.toInt().toString()
          : newVal.toString();
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
                          Text(
                            "${widget.item.calories} kcal • ${widget.item.info}",
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[500],
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
