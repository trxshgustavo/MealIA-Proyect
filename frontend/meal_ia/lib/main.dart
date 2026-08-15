import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
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
  }

  // Pantalla completa: oculta barra de navegación y barra de estado
  // immersiveSticky: las barras reaparecen brevemente al deslizar desde el borde
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
  // SOLO en release: En debug, App Check genera errores 403 que bloquean Firebase Auth
  // y causan que Google Sign-In se cuelgue con timeout.
  if (!kDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      debugPrint('✓ App Check activado (release mode)');
    } catch (e) {
      debugPrint('⚠️ APP CHECK ACTIVATION ERROR (no crítico): $e');
    }
  } else {
    debugPrint('⚠️ App Check desactivado en debug mode (evita errores 403)');
    debugPrint(
      '💡 Para activar App Check en debug, registra tu debug token en Firebase Console → App Check',
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
              pageTransitionsTheme: PageTransitionsTheme(
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
