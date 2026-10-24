import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../theme/app_colors.dart';

class StreakCelebrationDialog extends StatefulWidget {
  final int streak;

  const StreakCelebrationDialog({super.key, required this.streak});

  static void showIfNecessary(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.justIncreasedStreak) {
      showDialog(
        context: context,
        builder: (ctx) => StreakCelebrationDialog(streak: appState.currentStreak),
      ).then((_) {
        appState.clearStreakIncreasedFlag();
      });
    }
  }

  @override
  State<StreakCelebrationDialog> createState() => _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<StreakCelebrationDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background Card
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 40.h), // Space for top icon
                Text(
                  "¡Racha Aumentada!",
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "Acabas de generar tu menú del día y llevas una racha de:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textLight,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "${widget.streak}",
                      style: TextStyle(
                        fontSize: 48.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFF5722),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      widget.streak == 1 ? "día" : "días",
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonDark,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      "¡Continuar!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Top Icon
          Positioned(
            top: -40.h,
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 10.r,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 48.sp,
                color: const Color(0xFFFF5722),
              ),
            ),
          ),
          // Confetti
          Positioned(
            top: -60.h,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.orange,
                Colors.deepOrange,
                Colors.amber,
                Colors.yellow,
                Colors.redAccent
              ],
            ),
          ),
        ],
      ),
    );
  }
}
