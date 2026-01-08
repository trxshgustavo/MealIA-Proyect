import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  Widget _buildGoalCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final app = Provider.of<AppState>(context);
    final bool isSelected = app.goal == value;

    return GestureDetector(
      onTap: () {
        Provider.of<AppState>(context, listen: false).saveUserGoal(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor.withValues(alpha: 0.1)
                    : AppColors.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24.sp,
                color: isSelected ? AppColors.primaryColor : Colors.grey,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryColor,
                size: 20.sp,
              ),
          ],
        ),
      ),
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
                    height: 200.h,
                    width: 200.w,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.flag,
                      size: 100.sp,
                      color: AppColors.primaryText,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  Container(
                    padding: EdgeInsets.all(20.0.w),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Cuál es tu meta principal?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        _buildGoalCard(
                          context,
                          title: 'Déficit calórico',
                          subtitle: 'Bajar de peso',
                          icon: Icons.local_fire_department,
                          value: 'Déficit Calórico',
                        ),
                        SizedBox(height: 12.h),
                        _buildGoalCard(
                          context,
                          title: 'Mantenimiento',
                          subtitle: 'Conservar tu peso actual',
                          icon: Icons.monitor_weight,
                          value: 'Mantenimiento',
                        ),
                        SizedBox(height: 12.h),
                        _buildGoalCard(
                          context,
                          title: 'Aumentar masa muscular',
                          subtitle: 'Ganar peso y músculo',
                          icon: Icons.fitness_center,
                          value: 'Aumentar masa muscular',
                        ),
                        SizedBox(height: 24.h),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/main',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: Text(
                            'Finalizar y continuar',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
