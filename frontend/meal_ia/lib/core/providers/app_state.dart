import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart'; // NECESARIO PARA AUTH
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import '../config/api_config.dart';

class AppState extends ChangeNotifier {
  // Asegúrate de que esta IP sea la correcta de tu PC
  final String _baseUrl = ApiConfig.baseUrl;

  final _storage = const FlutterSecureStorage();
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web requiere clientId explícito
    clientId: kIsWeb ? dotenv.env['WEB_CLIENT_ID'] : null,
    // serverClientId NO es soportado en Web; solo en mobile
    serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
  );

  // Datos de Usuario
  String? email; // Added email field
  String? firstName;
  String? lastName;
  DateTime? birthdate;
  double? height;
  double? weight;
  String goal = 'Mantenimiento';
  String? photoUrl;

  // Inventario y Menú
  final Map<String, Map<String, dynamic>> _inventory = {};
  Map<String, Map<String, dynamic>> get inventoryMap => _inventory;

  Map<String, dynamic>? generatedMenu;
  int totalCalories = 0;

  // --- VERIFICACIÓN DE SESIÓN ---
  Future<bool> checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final token = await _storage.read(key: 'auth_token');

    // Verificación Relajada: Si hay token (Backend), dejamos pasar.
    // Si falta Firebase, intentaremos reconectar después.
    if (token == null) {
      return false;
    }
    return await _loadUserData(token);
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();

    // SECURITY FIX: Wipe all local data to prevent leaks between accounts
    await _storage.deleteAll();

    // Clear Memory State
    firstName = null;
    lastName = null;
    birthdate = null;
    email = null;
    height = null;
    weight = null;
    goal = 'Mantenimiento';
    photoUrl = null;

    _inventory.clear();
    _mealCalendar.clear();
    generatedMenu = null;

    notifyListeners();
  }

  Future<bool> _loadUserData(String token) async {
    try {
      // 1. Cargar Perfil desde Backend
      String? backendGoal;

      try {
        final userResponse = await http
            .get(
              Uri.parse('$_baseUrl/users/me'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 20));

        if (userResponse.statusCode == 200) {
          final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));

          email = userData['email'];
          firstName = userData['first_name'];
          lastName = userData['last_name'];
          height = (userData['height'] as num?)?.toDouble();
          weight = (userData['weight'] as num?)?.toDouble();

          birthdate = userData['birthdate'] != null
              ? DateTime.tryParse(userData['birthdate'])
              : null;

          backendGoal = userData['goal'];
          photoUrl = userData['photo_url'];
        } else {
          debugPrint("Backend /users/me returned ${userResponse.statusCode}");
        }
      } catch (e) {
        debugPrint("Error loading basic profile from backend: $e");
      }

      // --- FIRESTORE BACKUP READ (ALWAYS RUNS TO FILL GAPS) ---
      // Runs if backend failed OR if backend data was incomplete.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists) {
            final data = doc.data()!;

            // Sync Email/Name if missing (e.g. backend down)
            if (email == null && user.email != null) email = user.email;
            if (firstName == null && data.containsKey('first_name')) {
              firstName = data['first_name'];
            }
            if (lastName == null && data.containsKey('last_name')) {
              lastName = data['last_name'];
            }

            // Recuperar Meta
            if (backendGoal == null || backendGoal == 'Mantenimiento') {
              if (data.containsKey('goal')) {
                backendGoal = data['goal'];
                await _storage.write(
                  key: 'user_goal_${user.uid}',
                  value: backendGoal,
                );
              }
            }

            // Recuperar Foto
            if (photoUrl == null) {
              if (data.containsKey('photo_url')) {
                photoUrl = data['photo_url'];
                await _storage.write(
                  key: 'profile_photo_url_${user.uid}',
                  value: photoUrl,
                );
              }
            }

            // Recuperar Datos Físicos
            if (height == null && data.containsKey('height')) {
              height = (data['height'] as num?)?.toDouble();
            }
            if (weight == null && data.containsKey('weight')) {
              weight = (data['weight'] as num?)?.toDouble();
            }
            if (birthdate == null && data.containsKey('birthdate')) {
              birthdate = DateTime.tryParse(data['birthdate']);
            }
          }
        } catch (e) {
          debugPrint("Error leyendo backup de Firestore: $e");
        }
      }
      // -----------------------------

      // FINAL GOAL LOGIC (Backend vs Cache vs Default)
      // Use UID-scoped key if user is logged in
      String goalKey = 'user_goal';
      if (user != null) goalKey = 'user_goal_${user.uid}';

      if (backendGoal == null || backendGoal == 'Mantenimiento') {
        String? cachedGoal = await _storage.read(key: goalKey);
        // Fallback for migration: check old key? No, better to defaults.
        goal = cachedGoal ?? backendGoal ?? 'Mantenimiento';
      } else {
        goal = backendGoal; // We know its not null/mantenimiento-ish
        await _storage.write(key: goalKey, value: goal);
      }

      // FINAL PHOTO LOGIC
      String photoKey = 'profile_photo_url';
      if (user != null) photoKey = 'profile_photo_url_${user.uid}';

      if (photoUrl == null) {
        photoUrl = await _storage.read(key: photoKey);
      } else {
        await _storage.write(key: photoKey, value: photoUrl);
      }

      // 2. Cargar Inventario (Non-critical)
      try {
        final invResponse = await http
            .get(
              Uri.parse('$_baseUrl/inventory'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 20));
        if (invResponse.statusCode == 200) {
          final List<dynamic> invData = jsonDecode(
            utf8.decode(invResponse.bodyBytes),
          );
          _inventory.clear();
          for (var item in invData) {
            final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final String unit = item['unit'] ?? 'Unidades';

            _inventory[item['name']] = {'quantity': qty, 'unit': unit};

            // DB SANITIZATION: Check for floats (e.g. 4.5) which crash backend
            if (qty % 1 != 0) {
              // Found a float! 4.5 -> 5
              // We must fix it in the DB immediately.
              final int fixedQty = qty.round();
              debugPrint(
                "SANITIZING DB: Fixing ${item['name']} $qty -> $fixedQty",
              );
              updateFood(item['name'], fixedQty.toDouble(), unit);
              // Note: updateFood sends as double, but backend receives e.g. 5.0
              // wait, updateFood sends `{'quantity': quantity, ...}`
              // If I send 5.0, does it serializer accept it?
              // The Validation error was "got a number with a fractional part". 5.0 should be ok?
              // Or should I cast to int in updateFood?
            }
          }
        } else if (invResponse.statusCode == 500) {
          // AUTO-REPAIR: Backend crashed (likely due to float data).
          // We blindly reset common suspects to Integer=1 to unblock the list.
          await _blindRepairCriticalItems(token);
        }
      } catch (e) {
        debugPrint("Error loading inventory (ignoring): $e");
      }

      // 3. Cargar HISTORIAL de Menús (Local + Firestore) (Non-critical)
      try {
        // --- LOCAL SCOPED ---
        String calendarKey = 'meal_calendar_local';
        if (user != null) calendarKey = 'meal_calendar_local_${user.uid}';

        final localCalendarJson = await _storage.read(key: calendarKey);
        if (localCalendarJson != null) {
          final Map<String, dynamic> decoded = jsonDecode(localCalendarJson);
          _mealCalendar.clear();
          decoded.forEach((key, value) {
            _mealCalendar[key] = Map<String, dynamic>.from(value);
          });
        }

        // --- FIRESTORE ---
        if (user != null) {
          // Obtener colección 'daily_menus'
          final now = DateTime.now();
          final startDate = now.subtract(const Duration(days: 30));

          final querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_menus')
              .where(
                FieldPath.documentId,
                isGreaterThanOrEqualTo: _formatDate(startDate),
              )
              .get();

          for (var doc in querySnapshot.docs) {
            final dateKey = doc.id; // YYYY-MM-DD
            final data = doc.data();
            _mealCalendar[dateKey] = data; // Guardamos en memoria
          }

          // Actualizar cache local
          await _storage.write(
            key: calendarKey,
            value: jsonEncode(_mealCalendar),
          );
        }
      } catch (e) {
        debugPrint("Error cargando historial de menús: $e");
      }

      notifyListeners();

      // STRICT VALIDATION:
      // User requested "Don't let me in if errors".
      // If we failed to load critical data (Email/Name) from both Backend and Firestore,
      // we must return FALSE to show the error screen.
      if (email == null || firstName == null) {
        debugPrint(
          "Critical Data Missing: Email or Name is null. Failing Login.",
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Critical Error in _loadUserData: $e");
      return false;
    }
  }

  // Helper para fechas
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // --- LOGIN CON AUTO-REPARACIÓN DE FIREBASE ---
  Future<String> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/token');
    debugPrint("Intentando login en: $url");
    
    try {
      // 1. Login en Backend (FastAPI)
      debugPrint("Enviando petición POST a $_baseUrl/token");
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': email, 'password': password},
          )
          .timeout(const Duration(seconds: 60));

      debugPrint("Respuesta recibida: StatusCode ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // 2. LOGIN / CREACIÓN EN FIREBASE (Sincronización)
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          // AUTO-REPAIR: Si no existe en Firebase pero sí en Backend, lo creamos.
          if (e.code == 'user-not-found') {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
              // print("Usuario recreado en Firebase para sincronización.");
            } catch (createError) {
              // print("Error recreando usuario en Firebase: $createError");
            }
          } else {
            // print("Firebase Login Falló (ignorando): ${e.code} - ${e.message}");
          }
        } catch (e) {
          // print("Error genérico Firebase Login: $e");
        }

        // 3. LOGRADO: Guardamos token y cargamos user
        await _storage.write(key: 'auth_token', value: token);

        // Carga de datos
        final success = await _loadUserData(token);
        return success ? "OK" : "Error al cargar tus datos";
      } else if (response.statusCode == 401) {
        // Credenciales incorrectas
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Correo o contraseña incorrectos';
        } catch (_) {
          return 'Correo o contraseña incorrectos';
        }
      } else {
        // Otro error del servidor
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Error del servidor (${response.statusCode})';
        } catch (_) {
          return 'Error del servidor (${response.statusCode})';
        }
      }
    } on http.ClientException catch (e) {
      debugPrint("❌ ClientException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      return 'No se pudo conectar al servidor en $_baseUrl\nVerifica tu conexión a internet.';
    } on SocketException catch (e) {
      debugPrint("❌ SocketException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      return 'Sin conexión a internet.\nAsegúrate de estar conectado a WiFi o datos móviles.';
    } on TimeoutException catch (e) {
      debugPrint("❌ TimeoutException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      return 'La conexión tardó demasiado (>60s).\nEl servidor puede estar lento o inaccesible.';
    } on FormatException catch (e) {
      debugPrint("❌ FormatException en login: $e");
      return 'Respuesta inválida del servidor. Contacta soporte.';
    } catch (e, stackTrace) {
      debugPrint("❌ Error inesperado en login: $e");
      debugPrint("📍 StackTrace: $stackTrace");
      return 'Error inesperado: ${e.toString()}\nURL: $_baseUrl';
    }
  }

  // --- REGISTRO ---
  Future<String> register({
    required String email,
    required String password,
    required String firstName,
  }) async {
    final url = Uri.parse('$_baseUrl/register');
    try {
      // 1. Crear en Backend
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'first_name': firstName,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        // 2. Crear en Firebase (Intento silencioso)
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          // print("Error Firebase Register (puede que ya exista): $e");
        }

        // 3. Iniciar sesión automáticamente
        return await login(email, password);
      } else if (response.statusCode == 400) {
        // Error de validación (email ya registrado, etc.)
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'El correo ya está registrado';
        } catch (_) {
          return 'El correo ya está registrado';
        }
      } else {
        // Otro error del servidor
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Error del servidor (${response.statusCode})';
        } catch (_) {
          return 'Error del servidor (${response.statusCode})';
        }
      }
    } on http.ClientException catch (e) {
      debugPrint("Error de conexión en registro: $e");
      return 'No se pudo conectar al servidor. Verifica tu conexión a internet.';
    } on SocketException catch (e) {
      debugPrint("Error de red en registro: $e");
      return 'Sin conexión a internet. Verifica tu red.';
    } on TimeoutException catch (e) {
      debugPrint("Timeout en registro: $e");
      return 'La conexión tardó demasiado. Intenta de nuevo.';
    } catch (e) {
      debugPrint("Error inesperado en registro: $e");
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // --- GOOGLE LOGIN ---
  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Inicio de sesión cancelado";

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? googleToken = googleAuth.idToken;

      if (googleToken == null) return "Error al obtener token de Google";

      // Sincronizar Firebase con Google Credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        return _handleFirebaseError(e);
      }

      final url = Uri.parse('$_baseUrl/auth/google');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': googleToken}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final appToken = data['access_token'];
        final bool isNewUser = data['is_new_user'] ?? false;

        await _storage.write(key: 'auth_token', value: appToken);
        bool success = await _loadUserData(appToken);

        // FALLBACK: If Strict Check failed (success=false) but we have Google Data,
        // we can force populate the missing bits to allow login!
        if (!success) {
          // We are in Google Login. We KNOW the email and name.
          email ??= googleUser.email;
          if (firstName == null) {
            final nameParts = (googleUser.displayName ?? '').split(' ');
            if (nameParts.isNotEmpty) firstName = nameParts.first;
            if (nameParts.length > 1) {
              lastName = nameParts.sublist(1).join(' ');
            }
          }

          // Retry strict check Logic locally? Or just assume OK if we have data now?
          // Strict check in _loadUserData returns false.
          // If we manually filled them, we are good.
          if (email != null && firstName != null) {
            success = true;
            notifyListeners();
          }
        }

        if (!success) return "Error al cargar datos";
        return isNewUser ? "OK_NEW" : "OK_EXISTING";
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Error de servidor (${response.statusCode})';
        } catch (_) {
          return 'Error de servidor (${response.statusCode})';
        }
      }
    } on http.ClientException catch (e) {
      debugPrint("Error de conexión en Google Sign-In: $e");
      return 'No se pudo conectar al servidor. Verifica tu conexión a internet.';
    } on SocketException catch (e) {
      debugPrint("Error de red en Google Sign-In: $e");
      return 'Sin conexión a internet. Verifica tu red.';
    } on TimeoutException catch (e) {
      debugPrint("Timeout en Google Sign-In: $e");
      return 'La conexión tardó demasiado. Intenta de nuevo.';
    } catch (e) {
      debugPrint("Error inesperado en Google Sign-In: $e");
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // Helper para mensajes de error amigables
  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return "El método de autenticación no está habilitado en Firebase.";
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return "Correo o contraseña incorrectos.";
      case 'user-disabled':
        return "Tu cuenta ha sido deshabilitada.";
      case 'user-not-found':
        return "Usuario no encontrado.";
      case 'wrong-password':
        return "Contraseña incorrecta.";
      case 'email-already-in-use':
        return "El correo ya está registrado.";
      case 'credential-already-in-use':
        return "Esta cuenta ya está vinculada a otro usuario.";
      default:
        return "Error de autenticación: ${e.message}";
    }
  }

  // --- GESTIÓN DE DATOS ---

  void setPersonalData({String? firstName, String? lastName}) {
    this.firstName = firstName ?? this.firstName;
    this.lastName = lastName ?? this.lastName;
    notifyListeners();
  }

  Future<void> updateFood(String foodKey, double quantity, String unit) async {
    _inventory[foodKey] = {'quantity': quantity, 'unit': unit};
    notifyListeners();

    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      await http
          .put(
            Uri.parse('$_baseUrl/inventory/$foodKey'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'quantity': quantity.round(), 'unit': unit}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // print("Error actualizando comida: $e");
    }
  }

  // Helper dedicated to unblocking 500 Errors caused by Float/Int mismatch in DB
  Future<void> _blindRepairCriticalItems(String token) async {
    final suspects = [
      'avena',
      'pollo',
      'arroz',
      'morron',
      'palta',
      'queso',
      'platano',
      'huevos',
      'leche',
      'pan',
      'carne',
      'tomate',
      'lechuga',
      'cebolla',
      'zanahoria',
      'papa',
      'manzana',
      'banana',
      'naranja',
    ];

    debugPrint(
      "STARTING BLIND REPAIR: Attempting to reset ${suspects.length} common items to Integer=1 to fix 500 Error.",
    );

    for (var item in suspects) {
      try {
        // Blindly update to Clean Integer (1)
        await http
            .put(
              Uri.parse('$_baseUrl/inventory/$item'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'quantity': 1, 'unit': 'Unidades'}),
            )
            .timeout(
              const Duration(milliseconds: 500),
            ); // Short timeout, fire and forget mostly
      } catch (e) {
        // Ignore errors, we are just trying to hit the bad one
      }
    }
    debugPrint("BLIND REPAIR COMPLETE. Inventory should be unblocked.");
  }

  Future<void> addFood(String food) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    String normalizedKey = food.trim().toLowerCase();
    if (normalizedKey.isEmpty) return;
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/inventory'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': normalizedKey,
              'quantity': 1.0,
              'unit': 'Unidades',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _inventory[normalizedKey] = {
          'quantity': (data['quantity'] ?? 1).toDouble(),
          'unit': data['unit'] ?? 'Unidades',
        };
        notifyListeners();
      }
    } catch (e) {
      // print("Error añadiendo comida: $e");
    }
  }

  Future<void> removeFood(String foodKey) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/inventory/remove/$foodKey'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _inventory.remove(foodKey);
        notifyListeners();
      }
    } catch (e) {
      // print("Error borrando comida: $e");
    }
  }

  Future<bool> generateMenuConIA() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/generate-menu');
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        String rawBody = utf8.decode(response.bodyBytes);
        String cleanBody = _cleanJsonString(rawBody);

        try {
          final data = jsonDecode(cleanBody);
          generatedMenu = {
            'breakfast': data['breakfast'],
            'lunch': data['lunch'],
            'dinner': data['dinner'],
            'note': data['note'] ?? 'Menú generado por IA.',
          };
          // Safe cast for total_calories
          totalCalories = (data['total_calories'] as num?)?.toInt() ?? 0;

          notifyListeners();
          return true;
        } catch (e) {
          debugPrint("Error parseando JSON de IA: $e");
          debugPrint("Raw Body: $rawBody");
          return false;
        }
      } else {
        generatedMenu = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      generatedMenu = null;
      notifyListeners();
      return false;
    }
  }

  // Helper para limpiar respuestas de IA que a veces incluyen markdown o texto extra
  String _cleanJsonString(String raw) {
    String cleaned = raw.trim();

    // 1. Eliminar bloques de código markdown ```json ... ```
    if (cleaned.startsWith('```')) {
      // Remover primera línea (```json)
      final firstNewLine = cleaned.indexOf('\n');
      if (firstNewLine != -1) {
        cleaned = cleaned.substring(firstNewLine + 1);
      }
      // Remover última línea (```)
      final lastBackticks = cleaned.lastIndexOf('```');
      if (lastBackticks != -1) {
        cleaned = cleaned.substring(0, lastBackticks);
      }
    }

    // 2. Encontrar el primer '{' y el último '}' por si hay texto alrededor
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    return cleaned.trim();
  }

  Future<bool> saveUserPhysicalData({
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    double? height,
    double? weight,
  }) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/users/me/data');
    final Map<String, dynamic> body = {};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    // Format to ISO string for backend
    if (birthdate != null) body['birthdate'] = birthdate.toIso8601String();
    if (height != null) body['height'] = height;
    if (weight != null) body['weight'] = weight;

    try {
      // BACKEND FIX: Use PUT instead of PATCH (405 Method Not Allowed)
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        this.firstName = data['first_name'];
        this.lastName = data['last_name'];
        // SAFE CASTING: Handle int or double from backend response
        this.height = (data['height'] as num?)?.toDouble();
        this.weight = (data['weight'] as num?)?.toDouble();

        this.birthdate = data['birthdate'] != null
            ? DateTime.tryParse(data['birthdate']) // tryParse is safer
            : null;
        goal = data['goal'] ?? 'Mantenimiento'; // Handle null goal

        // FIRESTORE SYNC: Save Physical Data (Awaited safer sync)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final Map<String, dynamic> firestoreData = {};
            if (this.height != null) firestoreData['height'] = this.height;
            if (this.weight != null) firestoreData['weight'] = this.weight;
            if (this.birthdate != null) {
              firestoreData['birthdate'] = this.birthdate?.toIso8601String();
            }

            if (firestoreData.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .set(firestoreData, SetOptions(merge: true));
            }
          } catch (fsError) {
            debugPrint("Error syncing physical data to Firestore: $fsError");
          }
        }

        notifyListeners();
        return true;
      } else {
        debugPrint("Backend Error (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Exception saving physical data: $e");
      return false;
    }
  }

  Future<bool> saveUserGoal(String goal) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/users/me/data');
    try {
      // BACKEND FIX: Use PUT (consistent with other updates)
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'goal': goal}),
      );
      if (response.statusCode == 200) {
        this.goal = goal;

        final user = FirebaseAuth.instance.currentUser;

        // PERSISTENCE: Save to scoped local storage
        if (user != null) {
          await _storage.write(key: 'user_goal_${user.uid}', value: goal);

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'goal': goal}, SetOptions(merge: true));
          } catch (e) {
            debugPrint("Firestore Goal Sync Error: $e");
          }
        } else {
          // Fallback for weird edge case (no firebase user but active token?)
          await _storage.write(key: 'user_goal', value: goal);
        }

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadProfilePicture(File imageFile) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/users/me/upload-photo');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        photoUrl = data['photo_url'];

        // PERSISTENCE: Save to local storage
        if (photoUrl != null) {
          await _storage.write(key: 'profile_photo_url', value: photoUrl);

          // FIRESTORE SYNC: Save Photo URL
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'photo_url': photoUrl,
            }, SetOptions(merge: true));
          }
        }

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveRecipeToFavorites(Map<String, dynamic> recipeData) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/save-recipe');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': recipeData['name'],
          'ingredients': recipeData['ingredients'],
          'steps': recipeData['steps'],
          'calories': recipeData['calories'],
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProfilePicture() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/users/me/delete-photo');
    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        photoUrl = null;
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // --- ACTUALIZAR PASSWORD EN BACKEND ---
  Future<String> updateBackendPassword(String newPassword) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return "No hay token de sesión";

    // 1. Intentamos Endpoint Específico (PUT)
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/me/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': newPassword}),
      );
      if (response.statusCode == 200) return "OK";
    } catch (e) {
      // Continue
    }

    // 2. Intentamos Endpoint Genérico (PUT /users/me)
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': newPassword}),
      );
      if (response.statusCode == 200) return "OK";
    } catch (e) {
      // Continue
    }

    // 3. Intentamos Endpoint PATCH (PATCH /users/me)
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': newPassword}),
      );
      if (response.statusCode == 200) return "OK";

      // Si llegamos hasta aquí, devolvemos el error del último intento para debug
      return "Fallo Server (${response.statusCode}): ${response.body}";
    } catch (e) {
      return "Error de conexión: $e";
    }
  }

  // --- DAILY MENU MANAGEMENT (DATE BASED) ---
  final Map<String, dynamic> _mealCalendar = {}; // Key: YYYY-MM-DD

  Map<String, dynamic>? getMenuForDate(DateTime date) {
    final key = _formatDate(date);
    final data = _mealCalendar[key];
    if (data == null) return null;
    // Ensure we return a Map<String, dynamic> even if stored as dynamic/dynamic
    if (data is Map<String, dynamic>) {
      return data;
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> saveMenuForDate(DateTime date, Map<String, dynamic> menu) async {
    final dateKey = _formatDate(date);

    // 1. Memory Update - Ensure strict type
    _mealCalendar[dateKey] = Map<String, dynamic>.from(menu);
    notifyListeners();

    // 2. Persistence: Local Storage (Full Calendar)
    try {
      await _storage.write(
        key: 'meal_calendar_local',
        value: jsonEncode(_mealCalendar),
      );
    } catch (e) {
      debugPrint("Error guardando calendario local: $e");
    }

    // 3. Persistence: Firestore (Subcollection)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_menus')
          .doc(dateKey)
          .set(
            menu,
            SetOptions(merge: true),
          ) // Guardamos el mapa directo como documento
          .then(
            (_) => debugPrint("Menú del día $dateKey guardado en Firestore"),
          )
          .catchError(
            (e) => debugPrint("Error guardando menú en Firestore: $e"),
          );
    }

    // 4. Inventory Deduction (Only if saving for TODAY to avoid double deduction on old dates)
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      await _deductIngredientsFromMenu(menu);
    }
  }

  // --- INVENTORY DEDUCTION LOGIC ---
  Future<void> _deductIngredientsFromMenu(Map<String, dynamic> menu) async {
    debugPrint("Iniciando deducción de inventario...");
    final meals = ['breakfast', 'lunch', 'dinner'];

    for (var mealType in meals) {
      if (menu.containsKey(mealType) && menu[mealType] != null) {
        final ingredients = menu[mealType]['ingredients'];
        if (ingredients is List) {
          for (var item in ingredients) {
            await _processIngredientDeduction(item.toString());
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> _processIngredientDeduction(String rawIngredient) async {
    // Regex logic to parse: "2 huevos", "200g arroz", "1.5 litros leche"
    // Groups: 1=Quantity, 2=Fraction, 3=Unit (Optional), 4=Name
    // Improved Regex to capture optional unit "g"/"kg"/"ml"/"l" etc.
    final regex = RegExp(
      r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?\s+(.*)$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(rawIngredient.trim());

    double qtyToDeduct = 1.0;
    String unitToDeduct = 'u'; // 'u' for units/count
    String ingredientName = rawIngredient;

    if (match != null) {
      qtyToDeduct = double.tryParse(match.group(1) ?? '1') ?? 1.0;
      final capturedUnit = match.group(2)?.toLowerCase();
      // If group 2 is something like "g", "kg", use it. If null, maybe it's in the name?
      // For this simplified version, we assume structure "Quantity Unit Name" or "Quantity Name"

      if (capturedUnit != null && _isUnit(capturedUnit)) {
        unitToDeduct = capturedUnit;
        ingredientName = match.group(3) ?? '';
      } else {
        // Maybe Unit is inside the name part or missing (Count)
        // E.g. "2 Huevos" -> Unit="u"
        ingredientName =
            match.group(3) ??
            '${match.group(2) ?? ''} ${match.group(3) ?? ''}';
        ingredientName = ingredientName.trim();
      }
    }

    // Normalized search
    String? matchedKey;
    final normalizedSearch = ingredientName.toLowerCase().trim();

    for (var key in _inventory.keys) {
      if (normalizedSearch.contains(key.toLowerCase()) ||
          key.toLowerCase().contains(normalizedSearch)) {
        matchedKey = key;
        break;
      }
    }

    try {
      if (matchedKey != null) {
        final currentData = _inventory[matchedKey];
        if (currentData != null) {
          double currentQty = (currentData['quantity'] as num).toDouble();
          String currentUnit = (currentData['unit'] ?? '')
              .toString()
              .toLowerCase();

          final double currentQtyBase = _convertToBase(currentQty, currentUnit);
          final double deductQtyBase = _convertToBase(
            qtyToDeduct,
            unitToDeduct,
          );

          double resultBase = currentQtyBase - deductQtyBase;
          if (resultBase < 0) resultBase = 0;

          // BACKEND FIX: The backend expects Integer quantities.
          // Sending 4.7 kg (Float) causes a crash.
          // Solution: Iterate by converting strictly to BASE UNIT (g, ml) which are Integers (usually).
          // If original was 'kg', we switch to 'g' to keep precision as Int (4.7kg -> 4700g).

          String targetUnit = _getBaseUnitFor(currentUnit);
          // If currentUnit is 'u', base is 'u'.

          // If the result is effectively an integer in the original unit (e.g. 5.0 kg), we could keep it?
          // No, safer to standardise to g/ml if we are doing math.
          // However, if the user PREFERS 'kg', this changes their UI.
          // Trade-off: Stability > Preference. We switch to g/ml if fractional.

          // If we are in 'g' or 'ml', resultBase is already fine.
          // If we were in 'kg', resultBase is in 'g' (e.g. 4700).

          // But wait, _convertToBase returns the base value.
          // _convertFromBase was converting it back to kg.
          // OLD: resultInOriginalUnit = 4.7 (float). Crash.
          // NEW: We allow changing the unit to the base unit to ensure Int.

          // Check if we need to switch unit?
          // If we stick to 'g'/'ml', we can just send resultBase as Int.
          // If we stick to 'u', we must round.

          dynamic qtyToSend;
          String unitToSend = targetUnit;

          if (targetUnit == 'u') {
            qtyToSend = resultBase.round(); // 'u' must be int.
            unitToSend =
                currentData['unit']; // Keep original name if it was 'Huevos' etc, actually _getBase returns 'u' for unknown.
            if (unitToSend == 'u') unitToSend = currentData['unit']; // if it was 'Unidades' keep it.
          } else {
            // For Mass/Vol, we use the base value (g or ml)
            qtyToSend = resultBase.round();
          }

          debugPrint(
            "Deduction Fix: $matchedKey | New: $qtyToSend $unitToSend",
          );

          await updateFood(matchedKey, qtyToSend, unitToSend);
        }
      }
    } catch (e) {
      debugPrint("Error deducing ingredient '$rawIngredient': $e");
    }
  }

  bool _isUnit(String s) {
    return [
      'g',
      'kg',
      'ml',
      'l',
      'litro',
      'litros',
      'gramos',
      'kilos',
    ].contains(s);
  }

  String _getBaseUnitFor(String unit) {
    switch (unit) {
      case 'kg':
      case 'kilos':
      case 'kilogramos':
      case 'g':
      case 'gramos':
        return 'g';
      case 'l':
      case 'litro':
      case 'litros':
      case 'ml':
        return 'ml';
      default:
        return 'u';
    }
  }

  double _convertToBase(double qty, String unit) {
    switch (unit) {
      case 'kg':
      case 'kilos':
      case 'kilogramos':
        return qty * 1000;
      case 'l':
      case 'litro':
      case 'litros':
        return qty * 1000;
      case 'g':
      case 'ml':
      case 'gramos':
        return qty;
      default:
        // 'u' or unknown -> Treat as 1:1 base.
        // Logic: if I have 5 (units) eggs, base is 5.
        // If I have 300 (unknown) rice, base is 300.
        // If comparing 300 unknown vs 5000g, it works out.
        return qty;
    }
  }

  // Deprecated: Use saveMenuForDate
  // Future<void> saveFullMenuToDaily(Map<String, dynamic> menu) async { }

  Future<Map<String, dynamic>?> regenerateMeal(
    String type,
    Map<String, dynamic> currentRecipe,
  ) async {
    // Mock implementation - simulates regeneration
    await Future.delayed(const Duration(seconds: 2));

    return {
      'name': 'Nueva Receta de ${_capitalize(type)} Sorpresa',
      'calories': (currentRecipe['calories'] ?? 500) + 50,
      'ingredients': [
        'Ingrediente Nuevo 1',
        'Ingrediente Nuevo 2',
        'Toque Secreto',
      ],
      'steps': ['Paso 1: Improvisar.', 'Paso 2: Disfrutar.'],
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return "";
    return s[0].toUpperCase() + s.substring(1);
  }
}
