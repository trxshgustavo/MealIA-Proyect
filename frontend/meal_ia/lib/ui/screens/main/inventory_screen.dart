import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _newFoodItemController = TextEditingController();
  
  // 1. NUEVA VARIABLE DE ESTADO
  bool _isLoading = false; 

  @override
  void dispose() {
    _newFoodItemController.dispose();
    super.dispose();
  }

  void _addFoodItem() {
    if (_newFoodItemController.text.trim().isNotEmpty) {
      Provider.of<AppState>(context, listen: false).addFood(_newFoodItemController.text.trim());
      _newFoodItemController.clear();
    }
  }

  void _removeFoodItem(String foodKey) {
    Provider.of<AppState>(context, listen: false).removeFood(foodKey);
    String displayName = foodKey[0].toUpperCase() + foodKey.substring(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName eliminado!')),
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

  // 2. NUEVA FUNCIÓN PARA MANEJAR LA GENERACIÓN Y LA CARGA
  Future<void> _handleGenerateMenu() async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (appState.inventoryMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Añade alimentos antes de generar un menú!')),
      );
      return;
    }

    // Activar pantalla de carga
    setState(() {
      _isLoading = true;
    });

    // Llamar a la IA
    await appState.generateMenuConIA();

    if (!mounted) return;

    // Desactivar pantalla de carga
    setState(() {
      _isLoading = false;
    });

    // Navegar al menú
    Navigator.pushNamed(context, '/menu');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final inventoryMap = appState.inventoryMap;
    final itemKeys = inventoryMap.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      
      // 3. USAMOS UN STACK PARA SUPERPONER LA PANTALLA DE CARGA
      body: Stack(
        children: [
          // --- CAPA 1: El contenido normal de la pantalla ---
          SafeArea(
            bottom: false, 
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Mi inventario',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Image.asset(
                  'assets/carrot.png',
                  height: 100,
                  width: 100,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shopping_basket, size: 80, color: AppColors.textDark),
                ),
                const SizedBox(height: 20),

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
                                    final quantity = inventoryMap[itemKey] ?? 0;

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
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardDark, 
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "Cantidad: $quantity",
                                            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        onTap: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Aquí se abrirá el editor de cantidad (próximo paso).')),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Botón Generar
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleGenerateMenu, // Desactiva si está cargando
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

          // --- CAPA 2: La Pantalla de Carga (Solo visible si _isLoading es true) ---
          if (_isLoading)
            Container(
              color: const Color.fromARGB(255, 255, 255, 255), // Fondo blanco total
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Aquí va tu "video png" (o GIF). 
                  // Si no tienes uno, usa el 'assets/carrot.png' o cámbialo por tu GIF.
                  Image.asset(
                    'assets/animation.gif', // <-- ¡CAMBIA ESTO POR TU GIF/VIDEO PNG!
                    height: 450,
                    width: 450,
                  ),
                  
                  // Texto de carga
                  const Text(
                    "Generando menú...",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      decoration: TextDecoration.none, // Quita subrayado por si acaso
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