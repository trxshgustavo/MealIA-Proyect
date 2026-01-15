import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

  // Cargar variables de entorno (no crítico si falla)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✓ Variables de entorno cargadas');
  } catch (e) {
    debugPrint('⚠️ No se pudo cargar .env (no crítico): $e');
    debugPrint(
      '💡 La app funcionará, pero algunas funciones pueden requerir configuración',
    );
  }

  // ignore: unawaited_futures
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Inicializar Firebase (crítico, pero manejamos errores)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✓ Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ ERROR CRÍTICO: No se pudo inicializar Firebase: $e');
    debugPrint(
      '💡 Verifica tu configuración de Firebase en firebase_options.dart',
    );
    // Continuamos de todas formas, pero algunas funciones no funcionarán
  }
  // Initialize App Check
  // We use a "Debug" provider for non-PlayStore builds on Android to avoid 403 errors
  // IMPORTANT: You must register the Debug Token printed in console in Firebase Console
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider
                .debug, // FORCE DEBUG FOR NOW (Physical Device Release)
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );

    // DEBUG: Print Token for Registration
    // Note: El token de debug se imprime automáticamente por Firebase en los logs de Android
    // Busca en los logs: "Enter this debug secret into the allow list"
    try {
      // Intentamos obtener el token, pero no es crítico si falla
      await Future.delayed(const Duration(seconds: 2));
      debugPrint(
        '💡 Si ves un token de debug en los logs de Android, regístralo en Firebase Console → App Check',
      );
    } catch (e) {
      debugPrint('⚠️ APP CHECK TOKEN ERROR (no crítico): $e');
      debugPrint(
        '💡 La app funcionará, pero algunas funciones de Firebase pueden estar limitadas',
      );
    }
  } catch (e) {
    debugPrint('⚠️ APP CHECK ACTIVATION ERROR (no crítico): $e');
    debugPrint(
      '💡 La app funcionará normalmente, pero App Check no está activo',
    );
  }
  runApp(const MealIAApp());
}

class MealIAApp extends StatelessWidget {
  const MealIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: ScreenUtilInit(
        designSize: const Size(390, 844), // Modern baseline (iPhone 12/13/14)
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'MEAL.IA',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blueGrey,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              scaffoldBackgroundColor: const Color(0xFFFFFFFF),
              // GLOBAL TRANSITION: Instagram/iOS style Slide transition
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
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
          );
        },
      ),
    );
  }
}
