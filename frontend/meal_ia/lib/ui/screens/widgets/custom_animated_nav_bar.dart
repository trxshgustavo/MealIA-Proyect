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
    const double barHeight = 70;
    const double barMarginHorizontal = 20;

    const double bigCircleSize = 75; // Slightly larger than bar
    const double normalIconSize = 30;
    const double bigIconSize = 40;

    return Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(
        horizontal: barMarginHorizontal,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(barHeight / 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Permanent Big Circle for Middle Button (Inventory)
          // We position it manually in the center
          Positioned(
            top:
                (barHeight - bigCircleSize) /
                2, // Centered vertically relative to bar, but potentially overflowing
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(1),
                child: Container(
                  width: bigCircleSize,
                  height: bigCircleSize,
                  decoration: BoxDecoration(
                    color: AppColors.buttonDark,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.buttonDark.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add,
                      size: bigIconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Icons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left: Plan
              _buildNavItem(
                icon: Icons.calendar_month_outlined,
                index: 0,
                selectedIndex: selectedIndex,
                onTap: onTap,
                iconSize: normalIconSize,
              ),

              // Spacer for the middle button
              const Expanded(child: SizedBox()),

              // Right: Profile
              _buildNavItem(
                icon: Icons.person_outline,
                index: 2,
                selectedIndex: selectedIndex,
                onTap: onTap,
                iconSize: normalIconSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required int selectedIndex,
    required Function(int) onTap,
    required double iconSize,
  }) {
    final bool isSelected = (index == selectedIndex);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.grey.withOpacity(0.2) // Subtle grey highlight
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isSelected
                  ? AppColors.buttonDark
                  : AppColors
                        .textDark, // Dark color if selected, otherwise textDark
            ),
          ),
        ),
      ),
    );
  }
}
