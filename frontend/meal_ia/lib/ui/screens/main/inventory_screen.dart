import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/data/food_database.dart';
import '../theme/app_colors.dart';
// import '../../screens/main/food_scanner_screen.dart'; // No longer needed if we don't link it here directly? Wait, the modal uses it.
import '../../screens/main/food_scanner_screen.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _newFoodItemController = TextEditingController();

  // Lista de unidades disponibles para el selector
  final List<String> _units = [
    'Unidades',
    'Kg',
    'g',
    'L',
    'ml',
    'oz',
    'lb',
    'paquete',
  ];

  // We need to capture the autocomplete controller to clear it after selection
  TextEditingController? _autocompleteController;

  @override
  void dispose() {
    _newFoodItemController.dispose();
    super.dispose();
  }

  Future<void> _addFoodItem() async {
    final text = _newFoodItemController.text.trim();
    if (text.isNotEmpty) {
      _newFoodItemController.clear();
      _autocompleteController?.clear();
      FocusScope.of(context).unfocus(); // Close keyboard

      // Show loading indicator or optimistic add is handled by provider
      final success = await Provider.of<AppState>(
        context,
        listen: false,
      ).addFood(text);

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ Se agregó localmente, pero falló la sincronización.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeFoodItem(String foodKey) {
    Provider.of<AppState>(context, listen: false).removeFood(foodKey);
  }

  // --- Diálogo para editar cantidad y unidad ---
  Future<void> _showEditQuantityDialog(
    String foodKey,
    double currentQuantity,
    String currentUnit,
  ) async {
    final TextEditingController amountController = TextEditingController(
      text: currentQuantity > 0
          ? currentQuantity.toStringAsFixed(
              currentQuantity.truncateToDouble() == currentQuantity ? 0 : 2,
            )
          : '',
    );

    // Validación: Si la unidad que viene de la BD no está en nuestra lista, usamos la primera por defecto.
    String selectedUnit = _units.contains(currentUnit)
        ? currentUnit
        : _units[0];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
              title: Text(
                'Editar ${_capitalize(foodKey)}',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Define la cantidad exacta:",
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      // Input de número
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Cant.',
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Selector de Unidad
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedUnit,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textDark,
                              ),
                              items: _units.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setDialogState(() => selectedUnit = newValue);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    final double? amount = double.tryParse(
                      amountController.text.replaceAll(',', '.'),
                    );
                    if (amount != null) {
                      try {
                        Provider.of<AppState>(
                          context,
                          listen: false,
                        ).updateFood(foodKey, amount, selectedUnit);
                      } catch (e) {
                        // ignore: avoid_print
                        // print("Error llamando a updateFood: $e");
                      }
                      FocusScope.of(
                        context,
                      ).unfocus(); // Close keyboard explicitly
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1);
  }

  // Lógica para generar menú con pantalla de carga
  Future<void> _handleGenerateMenu() async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.inventoryMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Añade alimentos antes de generar un menú!'),
        ),
      );
      return;
    }

    // Mostrar diálogo de carga (fullscreen)
    showDialog(
      context: context,
      barrierDismissible: false, // El usuario no puede cerrarlo tocando fuera
      builder: (context) {
        return PopScope(
          canPop: false, // Bloquear el botón de atrás
          child: Dialog(
            backgroundColor: Colors.white, // Volvemos a blanco puro
            surfaceTintColor: Colors.transparent,
            insetPadding: EdgeInsets.zero, // Ocupar toda la pantalla
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white, // Blanco puro
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/animation1_transparent.gif',
                    height: 400.h,
                    width: 400.w,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.hourglass_bottom,
                      size: 80.sp,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    "Generando menú con IA...",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Ejecutar la generación
    await appState.generateMenuConIA();

    if (!mounted) return;

    // Cerrar el diálogo
    Navigator.of(context).pop();

    // Navegar al menú
    Navigator.pushNamed(context, '/menu');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final inventoryMap = appState.inventoryMap;
    final itemKeys = inventoryMap.keys.toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h), // Reducido
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mi Despensa",
                      style: TextStyle(
                        fontSize: 24.sp, // Reducido de 22
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // --- Search / Add Bar ---
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 8.h,
                ), // Márgenes ajustados
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r), // Radio ajustado
                  border: Border.all(color: Colors.grey.shade200, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.08,
                      ), // Sombra más marcada
                      blurRadius: 15.r,
                      offset: Offset(0, 5.h),
                    ),
                  ],
                ),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return FoodDatabase.search(textEditingValue.text);
                  },
                  onSelected: (String selection) {
                    _newFoodItemController.text = selection;
                    _addFoodItem(); // Auto-add on selection
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        _autocompleteController = textEditingController;

                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                "Agrega tus ingredientes...", // Texto más corto
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15.sp,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.secondaryText,
                              size: 25.sp, // Icono más pequeño
                            ),
                            suffixIcon: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6), // Reducido
                                decoration: const BoxDecoration(
                                  color: AppColors.buttonDark,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 30.sp, // Reducido
                                ),
                              ),
                              onPressed: () {
                                if (textEditingController.text
                                    .trim()
                                    .isNotEmpty) {
                                  _newFoodItemController.text =
                                      textEditingController.text;
                                  _addFoodItem();
                                } else {
                                  _showAddOptions(focusNode);
                                }
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 14.h, // Altura reducida
                            ),
                          ),
                          onSubmitted: (String value) {
                            if (value.trim().isNotEmpty) {
                              _newFoodItemController.text = value;
                              _addFoodItem();
                              focusNode.requestFocus();
                            }
                          },
                        );
                      },
                  optionsViewBuilder:
                      (
                        BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            child: Container(
                              width: MediaQuery.of(context).size.width - 48,
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.0.w,
                                        vertical: 10.0.h,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant_menu,
                                            size: 16.sp,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                ),
              ),

              // --- Inventory List ---
              Expanded(
                child: itemKeys.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.kitchen_outlined,
                              size: 60.sp, // Reducido
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              "Tu despensa está vacía",
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              "Agrega ingredientes para comenzar.",
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          10.w, // Reducido
                          10.h,
                          10.w,
                          10.h, // Reduced padding
                        ),
                        itemCount: itemKeys.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          // --- Normal Inventory Item ---
                          final itemKey = itemKeys[index];
                          final itemData = inventoryMap[itemKey];
                          final double quantity = (itemData?['quantity'] ?? 0)
                              .toDouble();
                          final String unit = itemData?['unit'] ?? 'Unidades';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: 0.08,
                                  ), // Sombra más marcada
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14.r),
                                onTap: () {
                                  _showEditQuantityDialog(
                                    itemKey,
                                    quantity,
                                    unit,
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 6.h, // Padding reducido
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon Placeholder
                                      Container(
                                        padding: EdgeInsets.all(8.w),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.accentColor,
                                          size: 18.sp,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Text(
                                          _capitalize(itemKey),
                                          style: TextStyle(
                                            fontSize: 15.sp, // Tono abajo
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                      // Quantity Badge
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 5.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBackground,
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: Text(
                                          "${quantity.truncateToDouble() == quantity ? quantity.toInt() : quantity} $unit",
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      // Delete Action
                                      IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 16.sp,
                                          color: Colors.grey.shade400,
                                        ),
                                        onPressed: () =>
                                            _removeFoodItem(itemKey),
                                        splashRadius: 18,
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.all(6.w),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // --- Fixed Generate Menu Button (Now at bottom of Column) ---
              if (itemKeys.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 110.h),
                  child: Container(
                    width: double.infinity,
                    height: 50.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.buttonDark.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _handleGenerateMenu,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonDark,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            "Generar Menú",
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // --- Floating Action Button area REMOVED (integrated into list) ---
      ),
    );
  }

  void _showAddOptions(FocusNode focusNode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Agregar Alimento",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.accentColor,
                  ),
                ),
                title: const Text(
                  "Escanear Refrigerador",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Usa la cámara para detectar alimentos"),
                onTap: () async {
                  Navigator.pop(sheetContext); // Close modal
                  // Navigate to Scanner
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FoodScannerScreen(),
                    ),
                  );

                  if (!mounted) return;

                  if (result != null && result is List) {
                    final appState = Provider.of<AppState>(
                      context,
                      listen: false,
                    );

                    // Show loading loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Guardando alimentos..."),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    int addedCount = 0;
                    int failedCount = 0;

                    for (var item in result) {
                      bool success = false;
                      if (item is ScannedFood) {
                        debugPrint(
                          "InventoryScreen: Adding ScannedFood ${item.name}",
                        );
                        success = await appState.addFood(
                          item.name,
                          quantity: item.quantity,
                          unit: item.unit,
                        );
                      } else if (item is String) {
                        debugPrint("InventoryScreen: Adding String $item");
                        success = await appState.addFood(item);
                      } else {
                        debugPrint(
                          "InventoryScreen: Unknown item type ${item.runtimeType}",
                        );
                      }

                      if (success) {
                        addedCount++;
                      } else {
                        failedCount++;
                      }
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      String msg =
                          "Se agregaron $addedCount alimentos correctamente.";
                      if (failedCount > 0) {
                        msg += " ($failedCount fallaron)";
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: failedCount > 0
                              ? Colors.orange
                              : null,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard, color: Colors.black54),
                ),
                title: const Text(
                  "Escribir Manualmente",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text("Busca o escribe el nombre"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  focusNode.requestFocus();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
