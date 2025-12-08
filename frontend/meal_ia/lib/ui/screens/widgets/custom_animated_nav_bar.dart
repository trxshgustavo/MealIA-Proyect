import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomAnimatedNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomAnimatedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    const double barHeight = 70;         
    const double barMarginHorizontal = 20; 
    const double barPaddingHorizontal = 20;
    
    const double ovalHeight = 60;        
    const double iconSize = 30;          

    final double contentWidth = screenWidth - (barMarginHorizontal * 2);

    final double itemSlotWidth = contentWidth / 2;

    return Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(horizontal: barMarginHorizontal, vertical: 15), 
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        // ---
        borderRadius: BorderRadius.circular(barHeight / 2),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            
            left: (selectedIndex * itemSlotWidth),
            
            top: (barHeight - ovalHeight) / 2,
            child: Container(
              width: itemSlotWidth, 
              height: ovalHeight,
              decoration: BoxDecoration(
                color: AppColors.buttonDark, 
                borderRadius: BorderRadius.circular(ovalHeight / 2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: barPaddingHorizontal),
            child: Row(
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  isSelected: selectedIndex == 0,
                  onTap: () => onTap(0),
                  iconSize: iconSize,
                ),
                _buildNavItem(
                  icon: Icons.person,
                  isSelected: selectedIndex == 1,
                  onTap: () => onTap(1),
                  iconSize: iconSize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required double iconSize,
  }) {
    return Expanded( 
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center( 
          child: Icon(
            icon,
            size: iconSize,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}