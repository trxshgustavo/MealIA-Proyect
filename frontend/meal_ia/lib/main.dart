import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/providers/app_state.dart';
import 'ui/screens/theme/app_colors.dart';
import 'ui/screens/auth/auth_check_screen.dart';
import 'ui/screens/auth/welcome_screen.dart';
import 'ui/screens/auth/register_screen.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/main/profile_screen.dart';
import 'ui/screens/onboarding/data_screen.dart';
import 'ui/screens/onboarding/goals_screen.dart';
import 'ui/screens/main/inventory_screen.dart';
import 'ui/screens/main/menu_screen.dart';
import 'ui/screens/main/recipe_screen.dart';
import 'ui/screens/main/subscription_screen.dart'; 

import 'ui/screens/main_shell.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load environment variables
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MealIAApp());
}

class MealIAApp extends StatelessWidget {
  const MealIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'MEAL.IA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        initialRoute: '/auth_check',
        routes: {
          '/auth_check': (_) => const AuthCheckScreen(),
          '/': (_) => const WelcomeScreen(),
          '/register': (_) => const RegisterScreen(),
          '/login': (_) => const LoginScreen(),
          '/main': (_) => const MainShell(),
          '/profile': (_) => const ProfileScreen(),
          '/data': (_) => const DataScreen(),
          '/goals': (_) => const GoalsScreen(),
          '/inventory': (_) => const InventoryScreen(),
          '/menu': (_) => const MenuScreen(),
          '/recipe': (_) => const RecipeScreen(),
          '/subscription': (context) => const SubscriptionScreen(),

        },
      ),
    );
  }
}
