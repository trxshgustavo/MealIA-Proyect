// lib/ui/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:meal_ia/ui/screens/main/inventory_screen.dart';
import 'package:meal_ia/ui/screens/main/profile_screen.dart';
import 'package:meal_ia/ui/screens/widgets/custom_animated_nav_bar.dart';
import 'package:meal_ia/ui/screens/theme/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Lista de las pantallas que se mostrarán
  final List<Widget> _screens = [
    const InventoryScreen(),
    const ProfileScreen(),
  ];

  void _onNavBarTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El IndexedStack mantiene el estado de las pantallas
      // (así no pierdes lo que escribiste en InventoryScreen)
      backgroundColor: AppColors.cardBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomAnimatedNavBar(
        selectedIndex: _currentIndex,
        onTap: _onNavBarTap,
      ),
    );
  }
}