import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:convert';
import 'dart:ui'; // For BackdropFilter
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Export ScannedFood for use in InventoryScreen
class ScannedFood {
  String name; // Changed to mutable so we can update it from OpenFoodFacts
  final String calories;
  final String info;
  double quantity;
  String unit;
  bool isSelected;
  
  // Nutrition evidence. Macros should only be used for tracking when they come
  // from a trusted source or a clearly visible nutrition label.
  String? barcode;
  double? exactCalories;
  double? exactProteins;
  double? exactFats;
  double? exactCarbs;
  double? confidence;
  bool nutritionEstimated;
  String? nutritionSource;
  String? nutritionSourceUrl;
  Map<String, double> micronutrients;

  ScannedFood({
    required this.name,
    required this.calories,
    required this.info,
    this.quantity = 1.0,
    this.unit = 'Unidades',
    this.isSelected = false,
    this.barcode,
    this.exactCalories,
    this.exactProteins,
    this.exactFats,
    this.exactCarbs,
    this.confidence,
    this.nutritionEstimated = true,
    this.nutritionSource,
    this.nutritionSourceUrl,
    Map<String, double>? micronutrients,
  }) : micronutrients = micronutrients ?? {};

  bool get hasCompleteMacros =>
      exactCalories != null &&
      exactProteins != null &&
      exactFats != null &&
      exactCarbs != null;

  bool get isNutritionVerified {
    if (!hasCompleteMacros || nutritionEstimated) return false;
    final source = nutritionSource?.toLowerCase() ?? '';
    return source.contains('openfoodfacts') ||
        source.contains('open food facts') ||
        source.contains('fooddata central') ||
        source.contains('usda') ||
        source.contains('etiqueta') ||
        source.contains('label') ||
        source.contains('base nutricional');
  }

  bool get canUseNutritionForTracking => hasCompleteMacros;

  String get nutritionQualityLabel {
    if (isNutritionVerified) {
      return nutritionSource == null || nutritionSource!.isEmpty
          ? 'Nutrición verificada'
          : 'Fuente: $nutritionSource';
    }
    if (hasCompleteMacros) {
      return 'Estimado para conteo';
    }
    return 'Pendiente de estimación';
  }

  String get caloriesLabel {
    final text = calories.trim();
    if (text.isEmpty || text == '?') return '? kcal';
    return text.toLowerCase().contains('kcal') ? text : '$text kcal';
  }

  static double? asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static String? asString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, double> parseMicronutrients(dynamic value) {
    if (value is! Map) return {};
    final parsed = <String, double>{};
    value.forEach((key, rawValue) {
      final number = asDouble(rawValue);
      if (number != null) parsed[key.toString()] = number;
    });
    return parsed;
  }

  Map<String, dynamic> nutritionMetadataForApi() {
    return {
      'nutrition_source': nutritionSource,
      'nutrition_source_url': nutritionSourceUrl,
      'nutrition_confidence': confidence,
      'nutrition_estimated': nutritionEstimated,
      'micronutrients': micronutrients.isEmpty ? null : micronutrients,
    };
  }

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

    final nutritionSource = asString(
      json['nutrition_source'] ??
          json['source_name'] ??
          json['fuente_nutricional'] ??
          json['fuente'],
    );
    final nutritionSourceUrl = asString(
      json['nutrition_source_url'] ?? json['source_url'] ?? json['url_fuente'],
    );
    final verified = json['nutrition_verified'] == true ||
        json['verified'] == true ||
        json['datos_verificados'] == true ||
        nutritionSource != null;

    return ScannedFood(
      name: asString(json['alimento'] ?? json['name'] ?? json['nombre']) ??
          'Desconocido',
      calories: json['calorias']?.toString() ?? '?',
      info: json['info'] ?? '',
      quantity: q,
      unit: u,
      isSelected: true,
      barcode: json['codigo_barras']?.toString(),
      exactCalories: asDouble(json['calorias_exactas'] ?? json['calories']),
      exactProteins: asDouble(json['proteinas'] ?? json['protein']),
      exactFats: asDouble(json['grasas'] ?? json['fat']),
      exactCarbs: asDouble(json['carbohidratos'] ?? json['carbs']),
      confidence: asDouble(json['confidence'] ?? json['confianza']),
      nutritionEstimated: json['nutrition_estimated'] == true ||
          json['estimado'] == true ||
          !verified,
      nutritionSource: nutritionSource,
      nutritionSourceUrl: nutritionSourceUrl,
      micronutrients: parseMicronutrients(
        json['micronutrients'] ?? json['micronutrientes'],
      ),
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
    if (!kIsWeb) {
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
        ResolutionPreset.high,
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
    }
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isAnalyzing) {
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);

    setState(() {
      _isAnalyzing = true;
      _detectedItems.clear();
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // 1. Intentar análisis con backend (OpenAI GPT-4o Vision)
      final backendItems = await appState.scanFridge(bytes, image.name);

      if (backendItems != null && backendItems.isNotEmpty) {
        _applyDetectedItems(backendItems);
        return;
      }

      // 2. Fallback con Gemini si está configurado en el cliente
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        final modelsToTry = [
          'gemini-2.5-flash',
          'gemini-flash-latest',
          'gemini-2.0-flash',
          'gemini-2.0-flash-exp',
        ];

        String? resultText;
        for (final modelName in modelsToTry) {
          try {
            final model = GenerativeModel(model: modelName, apiKey: apiKey);
            final prompt = Content.multi([
              TextPart(
                'Analiza la imagen minuciosamente y detecta el alimento o producto principal. Si ves una etiqueta nutricional, léela detalladamente. '
                'Devuelve un JSON ARRAY estrictamente válido. '
                'Schema: [{"alimento": "Nombre", "cantidad_estimada": 1.0, "unidad_estimada": "Unidades/Kg/g/L/ml/oz/lb/paquete", "calorias": 100, "calorias_exactas": 100.0, "proteinas": 5.0, "grasas": 2.0, "carbohidratos": 15.0, "micronutrientes": {"fiber": 0.0, "sugars": 0.0, "sodium": 0.0, "calcium": 0.0, "iron": 0.0, "vitamin_c": 0.0}, "confidence": 0.0, "nutrition_estimated": true, "nutrition_source": "Estimación IA basada en imagen", "nutrition_source_url": null, "info": "breve descripción"}]. '
                'REGLAS DE PRECISIÓN:\n'
                '1. Identifica el alimento visible; si la imagen no es clara, devuelve [] y no adivines.\n'
                '2. Si hay etiqueta nutricional o fuente impresa visible, usa esos valores y marca nutrition_estimated=false.\n'
                '3. Si no hay etiqueta, aproxima calorías, macros y micronutrientes para la porción visible usando valores nutricionales típicos del alimento. No dejes nutrientes nulos si el alimento fue identificado.\n'
                '4. Cuando aproximes, marca nutrition_estimated=true y nutrition_source="Estimación IA basada en imagen".\n'
                '5. Estima cantidad con la mayor precisión posible y marca confidence entre 0 y 1. Usa "Unidades" si es contable. Usa "g" o "Kg" si es peso.\n'
                '6. Si no ves alimentos, devuelve [].\n'
                'NO uses markdown. Solo JSON plano.',
              ),
              DataPart('image/jpeg', bytes),
            ]);

            final response = await model.generateContent([prompt]);
            resultText = response.text;
            if (resultText != null) break;
          } catch (_) {}
        }

        if (resultText != null) {
          String cleanJson = resultText
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          final decoded = _decodeFoodJson(cleanJson);
          final parsedItems = _parseDetectedItems(decoded);
          if (parsedItems.isNotEmpty) {
            _applyDetectedItems(parsedItems);
            return;
          }
        }
      }

      if (_detectedItems.isEmpty && mounted) {
        _showNoFoodDetectedSnackBar();
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al analizar imagen: $e')),
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

  dynamic _decodeFoodJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (arrayMatch != null) {
        return jsonDecode(arrayMatch.group(0)!);
      }

      final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (objectMatch != null) {
        return jsonDecode(objectMatch.group(0)!);
      }

      rethrow;
    }
  }

  List<dynamic> _parseDetectedItems(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().toList();
    }

    if (decoded is Map) {
      for (final key in ['items', 'alimentos', 'foods', 'productos']) {
        final value = decoded[key];
        if (value is List) {
          return value.whereType<Map>().toList();
        }
      }

      if (decoded.containsKey('alimento') ||
          decoded.containsKey('name') ||
          decoded.containsKey('nombre')) {
        return [decoded];
      }
    }

    return [];
  }

  void _applyDetectedItems(List<dynamic> rawItems) {
    if (!mounted) return;

    setState(() {
      _detectedItems = rawItems
          .whereType<Map>()
          .map((item) => ScannedFood.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.name.trim().isNotEmpty && item.name != 'Desconocido')
          .toList();

      for (var item in _detectedItems) {
        if (!_validUnits.contains(item.unit)) {
          item.unit = 'Unidades';
        }
      }
    });
  }

  void _showNoFoodDetectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No se detectó con claridad. Puedes intentarlo con más luz o agregarlo manualmente.',
        ),
        action: SnackBarAction(
          label: 'Agregar',
          onPressed: _showManualFoodDialog,
        ),
      ),
    );
  }

  Future<void> _showManualFoodDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar alimento'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del alimento',
              hintText: 'Ej. Manzana, yogurt, arroz',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) return;

    setState(() {
      _detectedItems = [
        ScannedFood(
          name: trimmedName,
          calories: '?',
          info: 'Agregado manualmente',
          isSelected: true,
        ),
      ];
    });
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hemos encontrado esto",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "Los nutrientes pueden ser verificados o estimados. Revisa la cantidad antes de agregar.",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

class _NutritionQualityChip extends StatelessWidget {
  final ScannedFood item;

  const _NutritionQualityChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final isVerified = item.isNutritionVerified;
    final color = isVerified
        ? AppColors.accentColor
        : item.hasCompleteMacros
            ? Colors.orange
            : Colors.grey;
    final icon = isVerified
        ? Icons.verified
        : item.hasCompleteMacros
            ? Icons.warning_amber_rounded
            : Icons.info_outline;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              item.nutritionQualityLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                          Text(
                            "${widget.item.caloriesLabel} • ${widget.item.info}",
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          _NutritionQualityChip(item: widget.item),
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
