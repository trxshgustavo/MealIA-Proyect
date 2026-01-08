import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    // Responsive dimensions
    final double barHeight = 70.h;
    final double barMarginHorizontal = 10.w;

    final double bigCircleSize = 85.h; // Relativo a la altura para consistencia
    final double normalIconSize = 30.sp;
    final double bigIconSize = 40.sp;

    return Container(
      height: barHeight,
      margin: EdgeInsets.symmetric(
        horizontal: barMarginHorizontal,
        vertical: 15.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(barHeight / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
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

          // Center: Add Button (Aligned)
          GestureDetector(
            onTap: () => onTap(1),
            child: Container(
              width: bigCircleSize,
              height: bigCircleSize,
              decoration: BoxDecoration(
                color: AppColors.buttonDark,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.buttonDark.withValues(alpha: 0.4),
                    blurRadius: 10.r,
                    offset: Offset(0, 5.h),
                  ),
                ],
                // No border
              ),
              child: Center(
                child: Icon(Icons.add, size: bigIconSize, color: Colors.white),
              ),
            ),
          ),

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
            width: 60.w,
            height: 60
                .w, // Keep it square based on width or height scale? .w usually safe for small tap targets
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.grey.withValues(alpha: 0.2) // Subtle grey highlight
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isSelected ? AppColors.buttonDark : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
