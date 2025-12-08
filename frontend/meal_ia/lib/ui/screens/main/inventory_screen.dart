import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _newFoodItemController = TextEditingController();
  
  // Variable para controlar la pantalla de carga
  bool _isLoading = false; 

  // Lista de unidades disponibles para el selector
  final List<String> _units = ['Unidades', 'Kg', 'g', 'L', 'ml', 'oz', 'lb', 'paquete'];

  @override
  void dispose() {
    _newFoodItemController.dispose();
    super.dispose();
  }

  void _addFoodItem() {
    if (_newFoodItemController.text.trim().isNotEmpty) {
      // Al añadir, por defecto la AppState lo creará con cantidad 1 y unidad "Unidades"
      Provider.of<AppState>(context, listen: false).addFood(_newFoodItemController.text.trim());
      _newFoodItemController.clear();
    }
  }

  void _removeFoodItem(String foodKey) {
    Provider.of<AppState>(context, listen: false).removeFood(foodKey);
    String displayName = foodKey.isNotEmpty 
        ? foodKey[0].toUpperCase() + foodKey.substring(1) 
        : foodKey;
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName eliminado!')),
    );
  }

  // --- Diálogo para editar cantidad y unidad ---
  Future<void> _showEditQuantityDialog(String foodKey, double currentQuantity, String currentUnit) async {
    final TextEditingController amountController = TextEditingController(
      text: currentQuantity > 0 
          ? currentQuantity.toStringAsFixed(currentQuantity.truncateToDouble() == currentQuantity ? 0 : 2) 
          : '',
    );

    // Validación: Si la unidad que viene de la BD no está en nuestra lista, usamos la primera por defecto.
    String selectedUnit = _units.contains(currentUnit) ? currentUnit : _units[0];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Editar ${_capitalize(foodKey)}',
                style: const TextStyle(color: AppColors.textDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Define la cantidad exacta:", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Input de número
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration('Cant.').copyWith(
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Selector de Unidad
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedUnit,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textDark),
                              items: _units.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: const TextStyle(color: AppColors.textDark)),
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
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final double? amount = double.tryParse(amountController.text.replaceAll(',', '.'));
                    if (amount != null) {
                      try {
                        Provider.of<AppState>(context, listen: false).updateFood(foodKey, amount, selectedUnit);
                      } catch (e) {
                        // print("Error llamando a updateFood: $e");
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.cardDark, 
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder( 
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueGrey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  // Lógica para generar menú con pantalla de carga
  Future<void> _handleGenerateMenu() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (appState.inventoryMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Añade alimentos antes de generar un menú!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await appState.generateMenuConIA();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    Navigator.pushNamed(context, '/menu');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final inventoryMap = appState.inventoryMap;
    final itemKeys = inventoryMap.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: Stack(
        children: [
          // CAPA 1: Contenido Principal
          SafeArea(
            bottom: false, 
            child: Column(
              children: [
                const SizedBox(height: 30),
                Image.asset(
                  'assets/carrot.png',
                  height: 180,
                  width: 180,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.shopping_basket, size: 80, color: AppColors.textDark),
                ),
                const SizedBox(height: 20),

                // Input para agregar nuevos items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newFoodItemController,
                          decoration: _inputDecoration('Añadir alimentos').copyWith(
                            fillColor: Colors.white, 
                          ),
                          style: const TextStyle(color: AppColors.textDark),
                          onSubmitted: (_) => _addFoodItem(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addFoodItem,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                          backgroundColor: AppColors.buttonDark,
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de items
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 24.0),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), 
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(20), 
                    ),
                    child: itemKeys.isEmpty
                        ? Column(
                            children: [
                              const SizedBox(height: 40),
                              Text(
                                'Tu inventario está vacío, ¡agrega alimentos para generar recetas!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: itemKeys.length,
                                  itemBuilder: (context, index) {
                                    final itemKey = itemKeys[index];
                                    final itemData = inventoryMap[itemKey];

                                    // Lógica corregida: Extracción directa de datos
                                    // Usamos operadores nulos (??) por seguridad
                                    final double quantity = (itemData?['quantity'] ?? 0).toDouble();
                                    final String unit = itemData?['unit'] ?? 'Unidades';

                                    return Card(
                                      color: AppColors.cardBackground, 
                                      elevation: 0,
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        title: Text(
                                          _capitalize(itemKey),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textDark),
                                        ),
                                        // Botón para eliminar
                                        leading: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                          onPressed: () => _removeFoodItem(itemKey),
                                        ),
                                        // Widget de cantidad y unidad (Clickable)
                                        trailing: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () {
                                            _showEditQuantityDialog(itemKey, quantity, unit);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.cardDark,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  // Formato: 2.0 -> "2", 2.5 -> "2.5"
                                                  "${quantity.truncateToDouble() == quantity ? quantity.toInt() : quantity} $unit",
                                                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.edit, size: 14, color: AppColors.textLight),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Botón Generar Menú
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleGenerateMenu,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cardDark,
                                  foregroundColor: AppColors.textDark,
                                ),
                                child: const Text('Generar menu con lo ingresado'),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // CAPA 2: Pantalla de Carga
          if (_isLoading)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/animation.gif', 
                    height: 300,
                    width: 300,
                    // Fallback por si la animación falla
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.hourglass_bottom, size: 80, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Generando menú con IA...",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}