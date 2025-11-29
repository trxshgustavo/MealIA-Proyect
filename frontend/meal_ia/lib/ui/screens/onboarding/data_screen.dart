import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({Key? key}) : super(key: key);
  @override
  _DataScreenState createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthdate;
  int _currentHeight = 170;
  double _currentWeight = 70.5;
  final _dateCtl = TextEditingController();
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.height != null) {
      _currentHeight = (appState.height! * 100).round();
    }
    if (appState.weight != null) {
      _currentWeight = appState.weight!;
    }
    if (appState.birthdate != null) {
      _birthdate = appState.birthdate;
      _dateCtl.text = DateFormat('dd/MM/yyyy').format(_birthdate!);
    }
  }

  @override
  void dispose() {
    _dateCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) {
      setState(() {
        _birthdate = d;
        _dateCtl.text = DateFormat('dd/MM/yyyy').format(d);
      });
    }
  }

  Future<void> _pickHeight() async {
    await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona tu altura (cm)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return NumberPicker(
                value: _currentHeight,
                minValue: 100,
                maxValue: 230,
                step: 1,
                onChanged: (value) {
                  setState(() => _currentHeight = value);
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {}); 
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _pickWeight() async {
    await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecciona tu peso (kg)'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DecimalNumberPicker(
                value: _currentWeight,
                minValue: 30,
                maxValue: 180,
                decimalPlaces: 1,
                onChanged: (value) {
                  setState(() => _currentWeight = value);
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {});
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    final lastName = Provider.of<AppState>(context, listen: false).lastName;
    
    final success = await appState.saveUserPhysicalData(
      firstName: appState.firstName, 
      lastName: lastName, 
      birthdate: _birthdate,
      height: _currentHeight / 100.0,
      weight: _currentWeight,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.pushNamed(context, '/goals');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar tus datos. Intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: AppColors.secondaryText),
      hintStyle: const TextStyle(color: AppColors.secondaryText),
      filled: true,
      fillColor: AppColors.inputFill, // Fondo gris claro
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Sin borde
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryColor), // Borde en foco
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground, 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/carrot.png',
                height: 280,
                width: 280,
                errorBuilder: (_, __, ___) => const Icon(Icons.analytics, size: 100, color: AppColors.primaryText),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Para el botón
                    children: [
                      const Text(
                        'Cuéntanos sobre ti',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: _dateCtl,
                        readOnly: true,
                        decoration: _inputDecoration('Fecha de nacimiento (Opcional)', Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 20),

                      Text('Altura', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickHeight,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill, // Fondo gris
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "$_currentHeight cm",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Peso', style: TextStyle(fontSize: 16, color: AppColors.secondaryText)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickWeight,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill, // Fondo gris
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "${_currentWeight.toStringAsFixed(1)} kg",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _saveData,
                              child: const Text('Continuar'),
                            )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}