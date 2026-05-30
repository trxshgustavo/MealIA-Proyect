import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';
import '../../../utils/screen_utils.dart';

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
    final imageSize = ScreenUtils.getResponsiveImageSize(
      context,
      baseSize: 280.0,
    );
    final horizontalPadding = ScreenUtils.getResponsiveHorizontalPadding(
      context,
    );
    final verticalSpacing = ScreenUtils.getVerticalSpacing(
      context,
      defaultSpacing: 20.0,
    );

    // If we can pop, it means we came from Profile/Data screen (Edit Mode)
    // If not, we are likely in Onboarding (Main is root of onboarding flow actually... wait)
    // Actually, in onboarding, the stack is / -> /welcome -> /register -> /data -> /goals
    // So canPop is TRUE in onboarding too.
    // We need a better heuristic.
    // Usually Onboarding finishes with pushNamedAndRemoveUntil to /main.
    // Setting/Edit mode should just pop or popUntil.
    // However, if we are editing, we are already logged in and MainShell is in the stack bottom or close to it.

    // Simple heuristic: If we are calling from Profile -> Data -> Goal, we want 'Guardar' behavior (which just pops back to data or profile).
    // BUT DataScreen also pushes /goals.

    // Let's rely on the user intention.
    // If I change the button to "Finalizar" it implies end of flow.
    // If I change it to "Guardar" it implies sub-screen.

    // I will use a simple check: is the user already fully authenticated and configured?
    // Hard to check in widget build synchronously without provider check.

    // Let's just assume if the user is here, they selected a goal.
    // Iwill change the button to pop to /main (refreshing it) OR simply pop if we want to go back.
    // The safest "Edit" behavior is pop. The safest "Onboarding" is pushNamedAndRemoveUntil.

    // I will add an optional argument to the route, but that requires changing routing.
    // Instead, I'll check if the route settings arguments contains "edit".

    // For now, I will change it to:
    // If we are deeper in the stack (more than just onboarding steps), maybe we can just pop to /main?
    // Actually, simply using pushNamedAndRemoveUntil is FINE for onboarding.
    // For editing, it's annoying because it resets the app state/tab.

    // I will enable the "Back" button in AppBar so users can just go back if they changed their mind,
    // and the "Finalizar" button will strictly go to Main.
    // This is consistent with "I am done editing everything".

    // Add AppBar to allow backing out.

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.primaryText,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ScreenUtils.getMaxContainerWidth(context),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/carrot.png',
                  height: imageSize,
                  width: imageSize,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.flag,
                    size: 100,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: verticalSpacing),

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
                        title: 'Déficit Calórico',
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
                          // If valid change, we just navigate.
                          // The change is saved INSTANTLY on tap of the card (see _buildGoalCard).
                          // So this button is just "Exit".

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
      ),
    );
  }
}
