import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});
  @override
  State<DataScreen> createState() => _DataScreenState();
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
            ),
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
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);

    try {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none, // Sin borde
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(
          color: AppColors.primaryColor,
        ), // Borde en foco
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.all(24.0.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/carrot.png',
                    height: 220.h,
                    width: 220.w,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.analytics,
                      size: 100.sp,
                      color: AppColors.primaryText,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  Container(
                    padding: EdgeInsets.all(24.0.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          spreadRadius: 0,
                          blurRadius: 10.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Cuéntanos sobre ti',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          SizedBox(height: 20.h),

                          TextFormField(
                            controller: _dateCtl,
                            readOnly: true,
                            decoration: _inputDecoration(
                              'Fecha de nacimiento (Opcional)',
                              Icons.calendar_today,
                            ),
                            onTap: _pickDate,
                          ),
                          SizedBox(height: 20.h),

                          _buildSelectorField(
                            label: 'Altura',
                            value: "$_currentHeight cm",
                            icon: Icons.height,
                            onTap: _pickHeight,
                          ),
                          SizedBox(height: 16.h),

                          _buildSelectorField(
                            label: 'Peso',
                            value: "${_currentWeight.toStringAsFixed(1)} kg",
                            icon: Icons.monitor_weight_outlined,
                            onTap: _pickWeight,
                          ),
                          SizedBox(height: 24.h),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _saveData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.buttonDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                  ),
                                  child: Text(
                                    'Continuar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _inputDecoration(label, icon),
        child: Text(
          value,
          style: TextStyle(fontSize: 16.sp, color: AppColors.primaryText),
        ),
      ),
    );
  }
}
