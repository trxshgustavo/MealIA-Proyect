import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/data/food_database.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

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

  void _addFoodItem() {
    if (_newFoodItemController.text.trim().isNotEmpty) {
      // Al añadir, por defecto la AppState lo creará con cantidad 1 y unidad "Unidades"
      Provider.of<AppState>(
        context,
        listen: false,
      ).addFood(_newFoodItemController.text.trim());
      _newFoodItemController.clear();
      // Also clear the autocomplete visual controller if it exists
      _autocompleteController?.clear();
    }
  }

  void _removeFoodItem(String foodKey) {
    Provider.of<AppState>(context, listen: false).removeFood(foodKey);
    String displayName = foodKey.isNotEmpty
        ? foodKey[0].toUpperCase() + foodKey.substring(1)
        : foodKey;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$displayName eliminado!')));
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
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Editar ${_capitalize(foodKey)}',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Define la cantidad exacta:",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
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
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
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
                    height: 430,
                    width: 430,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.hourglass_bottom,
                      size: 80,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Generando menú con IA...",
                    style: TextStyle(
                      fontSize: 25,
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
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final titleFontSize = ScreenUtils.getTitleFontSize(
      context,
      defaultSize: 28.0,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mi Despensa",
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // --- Search / Add Bar ---
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
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
                        // Sync the local controller with the Autocomplete controller
                        // so we can clear it or read from it manually if needed.
                        _autocompleteController = textEditingController;

                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText:
                                "Agrega los ingredientes que tienes en casa.",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.secondaryText,
                            ),
                            suffixIcon: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.buttonDark,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () {
                                // Sync text before adding
                                _newFoodItemController.text =
                                    textEditingController.text;
                                _addFoodItem();
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          onSubmitted: (String value) {
                            _newFoodItemController.text =
                                value; // Force value just in case
                            _addFoodItem();
                            focusNode.requestFocus();
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
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            child: Container(
                              width:
                                  ScreenUtils.getWidth(context) -
                                  (horizontalPadding * 2), // Match input width
                              constraints: const BoxConstraints(maxHeight: 250),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 12.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.restaurant_menu,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: const TextStyle(
                                                fontSize: 15,
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
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Tu despensa está vacía",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Agrega ingredientes para comenzar.",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          10,
                          24,
                          100,
                        ), // Padding bottom for button
                        itemCount: itemKeys.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final itemKey = itemKeys[index];
                          final itemData = inventoryMap[itemKey];
                          final double quantity = (itemData?['quantity'] ?? 0)
                              .toDouble();
                          final String unit = itemData?['unit'] ?? 'Unidades';

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  _showEditQuantityDialog(
                                    itemKey,
                                    quantity,
                                    unit,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon Placeholder or specific icon logic
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentColor
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          _capitalize(itemKey),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                      // Quantity Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardBackground,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          "${quantity.truncateToDouble() == quantity ? quantity.toInt() : quantity} $unit",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete Action
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () =>
                                            _removeFoodItem(itemKey),
                                        splashRadius: 20,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
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
            ],
          ),
        ),
        // --- Floating Action Button area for Generate ---
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: itemKeys.isNotEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Container(
                  width: double.infinity,
                  height: ScreenUtils.isSmallScreen(context) ? 56 : 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.buttonDark.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleGenerateMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonDark,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white),
                        SizedBox(
                          width: ScreenUtils.getElementSpacing(
                            context,
                            defaultSpacing: 10.0,
                          ),
                        ),
                        Text(
                          "Generemos nuestro menú",
                          style: TextStyle(
                            fontSize: ScreenUtils.getButtonFontSize(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
