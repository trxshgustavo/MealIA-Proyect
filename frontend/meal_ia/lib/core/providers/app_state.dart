import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // Required for Uint8List
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart'; // NECESARIO PARA AUTH
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:firebase_storage/firebase_storage.dart';
import '../config/api_config.dart';

class AppState extends ChangeNotifier {
  // Asegúrate de que esta IP sea la correcta de tu PC
  final String _baseUrl = ApiConfig.baseUrl;

  final _storage = const FlutterSecureStorage();
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? (dotenv.env['WEB_CLIENT_ID']?.isNotEmpty == true
            ? dotenv.env['WEB_CLIENT_ID']
            : null)
        : null,
    serverClientId: kIsWeb 
        ? null 
        : ((dotenv.env['GOOGLE_SERVER_CLIENT_ID'] != null &&
            dotenv.env['GOOGLE_SERVER_CLIENT_ID']!.isNotEmpty)
            ? dotenv.env['GOOGLE_SERVER_CLIENT_ID']
            : null),
  );

  // Datos de Usuario
  String? email; // Added email field
  String? firstName;
  String? lastName;
  DateTime? birthdate;
  double? height;
  double? weight;
  String? gender;
  String goal = 'Mantenimiento';
  String? photoUrl;
  bool isPremium = false; // Premium Status
  bool isAdmin = false; // Admin Status
  int mealsPerDay = 3;
  Map<String, String> mealTimes = {
    "Desayuno": "08:00",
    "Almuerzo": "14:00",
    "Cena": "20:00"
  };

  // Inventario y Menú
  final Map<String, Map<String, dynamic>> _inventory = {};
  Map<String, Map<String, dynamic>> get inventoryMap => _inventory;

  Map<String, dynamic>? generatedMenu;
  int totalCalories = 0;

  // Recetas Guardadas (Favoritos)
  List<Map<String, dynamic>> _savedRecipes = [];
  List<Map<String, dynamic>> get savedRecipes => _savedRecipes;

  // --- HELPERS ---
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // --- VERIFICACIÓN DE SESIÓN ---
  Future<bool> checkLoginStatus() async {
    try {
      // WAIT FOR FIREBASE TO INITIALIZE (Crucial for Web persistence)
      await FirebaseAuth.instance.authStateChanges().first;

      final token = await _storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        return false;
      }

      // Attempt to load user data.
      // If validation fails inside due to explicit 401, it will return false.
      return await _loadUserData(token);
    } catch (e) {
      debugPrint("Error en checkLoginStatus: $e");
      // Si hay un token guardado, no cerramos sesión por un error temporal de red
      final token = await _storage.read(key: 'auth_token');
      return token != null && token.isNotEmpty;
    }
  }

  void clearMemoryState() {
    firstName = null;
    lastName = null;
    birthdate = null;
    email = null;
    height = null;
    weight = null;
    gender = null;
    goal = 'Mantenimiento';
    photoUrl = null;
    isPremium = false;
    isAdmin = false;
    mealsPerDay = 3;
    mealTimes = {
      "Desayuno": "08:00",
      "Almuerzo": "14:00",
      "Cena": "20:00"
    };

    _inventory.clear();
    _mealCalendar.clear();
    generatedMenu = null;
    _savedRecipes.clear();
    totalCalories = 0;
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // SECURITY FIX: Wipe all local data to prevent leaks between accounts
    try {
      await _storage.deleteAll();
    } catch (_) {}

    // Clear Memory State
    clearMemoryState();

    notifyListeners();
  }

  Future<bool> _loadUserData(String token) async {
    try {
      // Clean memory state first to avoid leaking data from a previous session
      clearMemoryState();
      // 0. PRE-LOAD FROM LOCAL CACHE (Offline Support & Fast Boot)
      String? cachedProfile = await _storage.read(key: 'user_profile_cache_current');
      final user = FirebaseAuth.instance.currentUser;
      if (cachedProfile == null && user != null) {
        cachedProfile = await _storage.read(
          key: 'user_profile_cache_${user.uid}',
        );
      }
      if (cachedProfile != null) {
        try {
          final data = jsonDecode(cachedProfile);
          email = data['email'];
          firstName = data['first_name'];
          lastName = data['last_name'];
          height = (data['height'] as num?)?.toDouble();
          weight = (data['weight'] as num?)?.toDouble();
          birthdate = data['birthdate'] != null
              ? DateTime.tryParse(data['birthdate'])
              : null;
          final cachedPhotoUrl = data['photo_url'] as String?;
          if (cachedPhotoUrl != null && cachedPhotoUrl.isNotEmpty) {
            photoUrl = cachedPhotoUrl;
          }
          gender = data['gender'];
          goal = data['goal'] ?? 'Mantenimiento';
          isPremium = data['is_premium'] ?? false;
          isAdmin = data['is_admin'] ?? false;
          if (data['meals_per_day'] != null) mealsPerDay = data['meals_per_day'];
          if (data['meal_times'] != null) mealTimes = Map<String, String>.from(data['meal_times']);
          debugPrint("Loaded Profile from Local Cache: $firstName ($email)");
        } catch (e) {
          debugPrint("Error decoding profile cache: $e");
        }
      }

      Future<void> loadProfile() async {
        String? backendGoal;
        try {
          final userResponse = await http
              .get(
                Uri.parse('$_baseUrl/users/me'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 45));

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
            gender = userData['gender'];
            final backendPhotoUrl = userData['photo_url'] as String?;
            photoUrl = (backendPhotoUrl != null && backendPhotoUrl.isNotEmpty)
                ? backendPhotoUrl
                : null;
            isPremium = userData['is_premium'] ?? false;
            isAdmin = userData['is_admin'] ?? false;
            if (userData['meals_per_day'] != null) mealsPerDay = userData['meals_per_day'];
            if (userData['meal_times'] != null) mealTimes = Map<String, String>.from(userData['meal_times']);

            final cacheData = {
              'email': email,
              'first_name': firstName,
              'last_name': lastName,
              'height': height,
              'weight': weight,
              'birthdate': birthdate?.toIso8601String(),
              'photo_url': photoUrl,
              'goal': backendGoal,
              'gender': gender,
              'is_premium': isPremium,
              'is_admin': isAdmin,
              'meals_per_day': mealsPerDay,
              'meal_times': mealTimes,
            };
            await _storage.write(
              key: 'user_profile_cache_current',
              value: jsonEncode(cacheData),
            );
            if (user != null) {
              await _storage.write(
                key: 'user_profile_cache_${user.uid}',
                value: jsonEncode(cacheData),
              );
            }
          } else {
            debugPrint("Backend /users/me returned ${userResponse.statusCode}");
            if (userResponse.statusCode == 401) {
              await logout();
              return;
            }
          }
        } catch (e) {
          debugPrint("Error loading basic profile from backend: $e");
        }

        if (user != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (doc.exists) {
              final data = doc.data()!;
              if (email == null && user.email != null) email = user.email;
              if (firstName == null && data.containsKey('first_name')) firstName = data['first_name'];
              if (lastName == null && data.containsKey('last_name')) lastName = data['last_name'];
              if (backendGoal == null || backendGoal == 'Mantenimiento') {
                if (data.containsKey('goal')) backendGoal = data['goal'];
              }
              if (photoUrl == null || photoUrl!.isEmpty) {
                if (data.containsKey('photo_url') && data['photo_url'] != null) {
                  final firestorePhoto = data['photo_url'] as String?;
                  if (firestorePhoto != null && firestorePhoto.isNotEmpty) {
                    photoUrl = firestorePhoto;
                    debugPrint("Loaded photoUrl from Firestore: $photoUrl");
                  }
                }
              }
              if (height == null && data.containsKey('height')) height = (data['height'] as num?)?.toDouble();
              if (weight == null && data.containsKey('weight')) weight = (data['weight'] as num?)?.toDouble();
              if (birthdate == null && data.containsKey('birthdate')) birthdate = DateTime.tryParse(data['birthdate']);
              if (gender == null && data.containsKey('gender')) gender = data['gender'];
              if (data.containsKey('meals_per_day')) mealsPerDay = data['meals_per_day'];
              if (data.containsKey('meal_times')) mealTimes = Map<String, String>.from(data['meal_times']);
            }
          } catch (e) {
            debugPrint("Error leyendo backup de Firestore: $e");
          }
        }

        if (user != null) {
          String goalKey = 'user_goal_${user.uid}';
          if (backendGoal == null || backendGoal == 'Mantenimiento') {
            String? cachedGoal = await _storage.read(key: goalKey);
            goal = cachedGoal ?? 'Mantenimiento';
          } else {
            goal = backendGoal;
            await _storage.write(key: goalKey, value: goal);
          }
          
          String photoKey = 'profile_photo_url_${user.uid}';
          if (photoUrl == null || photoUrl!.isEmpty) {
            String? cachedPhoto = await _storage.read(key: photoKey);
            if (cachedPhoto != null && cachedPhoto.isNotEmpty) {
              photoUrl = cachedPhoto;
            }
          }
          if (photoUrl != null && photoUrl!.isNotEmpty) {
            await _storage.write(key: photoKey, value: photoUrl);
          }
        } else {
          goal = 'Mantenimiento';
        }
      }

      Future<void> loadInventory() async {
        _inventory.clear();
        if (user == null) return;
        String inventoryKey = 'inventory_cache_${user.uid}';
        try {
          String? cachedInv = await _storage.read(key: inventoryKey);
          if (cachedInv != null) {
            final Map<String, dynamic> decoded = jsonDecode(cachedInv);
            _inventory.clear();
            decoded.forEach((key, value) {
              _inventory[key] = Map<String, dynamic>.from(value);
            });
          }
        } catch (e) {
          debugPrint("Error loading inventory cache: $e");
        }

        try {
          final invResponse = await http
              .get(
                Uri.parse('$_baseUrl/inventory'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 60));

          if (invResponse.statusCode == 200) {
            final List<dynamic> data = jsonDecode(invResponse.body);
            _inventory.clear();
            for (var item in data) {
              _inventory[item['name']] = {
                'quantity': (item['quantity'] ?? 0).toDouble(),
                'unit': item['unit'] ?? 'Unidades',
              };
            }
            await _storage.write(
              key: inventoryKey,
              value: jsonEncode(_inventory),
            );
          } else if (invResponse.statusCode == 401) {
            await logout();
            return;
          }
        } catch (e) {
          debugPrint("Error loading inventory from network: $e");
        }

        try {
          final invSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('inventory')
              .get();
          if (invSnap.docs.isNotEmpty) {
            bool cacheUpdateNeeded = false;
            for (var doc in invSnap.docs) {
              final data = doc.data();
              final name = doc.id;
              if (!_inventory.containsKey(name)) {
                _inventory[name] = {
                  'quantity': (data['quantity'] as num?)?.toDouble() ?? 0.0,
                  'unit': data['unit'] ?? 'Unidades',
                };
                cacheUpdateNeeded = true;
              }
            }
            if (cacheUpdateNeeded) {
              await _storage.write(
                key: inventoryKey,
                value: jsonEncode(_inventory),
              );
            }
          }
        } catch (e) {
          debugPrint("Error loading inventory from Firestore: $e");
        }
      }

      Future<void> loadHistory() async {
        try {
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

          if (user != null) {
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
              final dateKey = doc.id;
              final data = doc.data();
              _mealCalendar[dateKey] = data;
            }
            await _storage.write(
              key: calendarKey,
              value: jsonEncode(_mealCalendar),
            );
          }
          
          // FIX: Recuperar el menú de hoy si existe en el historial
          final todayKey = _formatDate(DateTime.now());
          if (_mealCalendar.containsKey(todayKey)) {
             generatedMenu = _mealCalendar[todayKey];
             totalCalories = generatedMenu?['total_calories'] ?? 0;
          } else {
             generatedMenu = null;
             totalCalories = 0;
          }
        } catch (e) {
          debugPrint("Error cargando historial de menús: $e");
        }
      }

      Future<void> loadSavedRecipes() async {
        if (user == null) return;
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('saved_recipes')
              .get();
          _savedRecipes = snapshot.docs.map((doc) => doc.data()).toList();
        } catch (e) {
          debugPrint("Error loading saved recipes from Firestore: $e");
        }
      }

      await Future.wait([
        loadProfile(),
        loadInventory(),
        loadHistory(),
        loadSavedRecipes(),
      ]);

      notifyListeners();

      // Resilient Fallbacks if offline on first cold boot
      if (firstName == null || firstName!.trim().isEmpty) {
        firstName = "Usuario";
      }
      if (email == null || email!.trim().isEmpty) {
        email = user?.email ?? "usuario@mealia.com";
      }

      // Sincronizar inventario local hacia el backend (Para mitigar reinicios de DB en Render)
      _syncInventoryToBackend(token);

      return true;
    } catch (e) {
      debugPrint("Warning in _loadUserData: $e");
      // As long as we have a valid token, we keep the user logged in
      firstName ??= "Usuario";
      email ??= "usuario@mealia.com";
      return true;
    }
  }

  // Helper para restaurar el inventario del backend desde el caché local/Firestore
  Future<void> _syncInventoryToBackend(String token) async {
    if (_inventory.isEmpty) return;
    debugPrint("🔄 Sincronizando ${_inventory.length} items al backend...");
    for (var entry in _inventory.entries.toList()) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/inventory'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'name': entry.key,
            'quantity': entry.value['quantity'],
            'unit': entry.value['unit'],
            'category': entry.value['category'] ?? 'Otros',
          }),
        ).timeout(const Duration(seconds: 60));
      } catch (e) {
        debugPrint("Error sincronizando ${entry.key}: $e");
      }
    }
    debugPrint("✅ Sincronización de inventario completada.");
  }

  Future<void> refreshAppData() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      await _loadUserData(token);
    }
  }

  // Helper para fechas
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // --- LOGIN CON AUTO-REPARACIÓN DE FIREBASE ---
  Future<String> login(String email, String password) async {
    clearMemoryState();
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
          // AUTO-REPAIR: Si no existe en Firebase pero sí en Backend, o la contraseña difiere.
          if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
            try {
              // Intento drástico de sincronizar: crear si no existe
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
            } catch (createError) {
              debugPrint("Error auto-repair Firebase: $createError");
            }
          }
        } catch (e) {
          debugPrint("Error genérico Firebase Login: $e");
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
          return data['detail'] ??
              'Error del servidor (${response.statusCode})';
        } catch (_) {
          return 'Error del servidor (${response.statusCode})';
        }
      }
    } on http.ClientException catch (e) {
      debugPrint("❌ ClientException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      return 'No se pudo conectar al servidor.\n\nVerifica que:\n• El backend esté corriendo\n• La IP sea correcta: $_baseUrl\n• Tu dispositivo y PC estén en la misma red WiFi';
    } on SocketException catch (e) {
      debugPrint("❌ SocketException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('connection timed out') ||
          errorMsg.contains('timeout')) {
        return 'El servidor no responde.\n\nVerifica que:\n• El backend esté corriendo en $_baseUrl\n• El firewall permita conexiones en el puerto 8000\n• Tu dispositivo y PC estén en la misma red';
      }
      return 'Sin conexión a internet.\nAsegúrate de estar conectado a WiFi o datos móviles.';
    } on TimeoutException catch (e) {
      debugPrint("❌ TimeoutException en login: $e");
      debugPrint("📍 URL intentada: $_baseUrl/token");
      return 'La conexión tardó demasiado.\n\nEl servidor en $_baseUrl no responde.\nVerifica que el backend esté corriendo.';
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
    clearMemoryState();
    final url = Uri.parse('$_baseUrl/register');

    // Validaciones básicas antes de intentar conexión
    if (email.isEmpty || !email.contains('@')) {
      return 'Por favor ingresa un correo electrónico válido';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (firstName.isEmpty) {
      return 'Por favor ingresa tu nombre';
    }

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
          return data['detail'] ??
              'Error del servidor (${response.statusCode})';
        } catch (_) {
          return 'Error del servidor (${response.statusCode})';
        }
      }
    } on http.ClientException catch (e) {
      debugPrint("Error de conexión en registro: $e");
      return 'No se pudo conectar al servidor.\n\nVerifica que:\n• El backend esté corriendo\n• La IP sea correcta: $_baseUrl\n• Tu dispositivo y PC estén en la misma red WiFi';
    } on SocketException catch (e) {
      debugPrint("Error de red en registro: $e");
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('connection timed out') ||
          errorMsg.contains('timeout')) {
        return 'El servidor no responde.\n\nVerifica que:\n• El backend esté corriendo en $_baseUrl\n• El firewall permita conexiones en el puerto 8000\n• Tu dispositivo y PC estén en la misma red';
      }
      return 'Sin conexión a internet. Verifica tu red.';
    } on TimeoutException catch (e) {
      debugPrint("Timeout en registro: $e");
      return 'La conexión tardó demasiado.\n\nEl servidor en $_baseUrl no responde.\nVerifica que el backend esté corriendo.';
    } catch (e) {
      debugPrint("Error inesperado en registro: $e");
      return 'Error inesperado: ${e.toString()}';
    }
  }

  // --- GOOGLE LOGIN ---
  Future<String> signInWithGoogle() async {
    clearMemoryState();
    try {
      String? googleToken;
      String? userEmail;
      String? userDisplayName;
      String? userPhotoUrl;

      if (kIsWeb) {
        debugPrint('🔄 Iniciando Google Sign-In (vía Firebase Popup para Web)...');
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithPopup(googleProvider)
            .timeout(const Duration(seconds: 45));
            
        final OAuthCredential? credential = userCredential.credential as OAuthCredential?;
        if (credential == null || credential.idToken == null) {
          debugPrint('❌ No se obtuvo idToken del credential de Google');
          return "Error al obtener token de Google";
        }
        
        googleToken = credential.idToken;
        userEmail = userCredential.user?.email;
        userDisplayName = userCredential.user?.displayName;
        userPhotoUrl = userCredential.user?.photoURL;
        
        debugPrint('✓ Google Sign-In (Web) exitoso: $userEmail');
      } else {
        // PASO 0: Limpiar sesión anterior de Google para evitar que signIn() se cuelgue
        try {
          await _googleSignIn.signOut();
          debugPrint('✓ Sesión anterior de Google limpiada');
        } catch (e) {
          debugPrint('⚠️ Error limpiando sesión Google (no crítico): $e');
        }

        // PASO 1: Iniciar flujo de Google Sign-In con timeout explícito
        debugPrint('🔄 Iniciando Google Sign-In...');
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .signIn()
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('❌ Google Sign-In tardó más de 30s - cancelando');
                return null;
              },
            );

        if (googleUser == null) {
          debugPrint('ℹ️ Google Sign-In: usuario canceló o timeout');
          return "Inicio de sesión cancelado";
        }
        debugPrint('✓ Google Sign-In exitoso: ${googleUser.email}');

        // PASO 2: Obtener tokens de autenticación
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication.timeout(
          const Duration(seconds: 15),
        );
        googleToken = googleAuth.idToken;

        if (googleToken == null) {
          debugPrint('❌ No se obtuvo idToken de Google');
          return "Error al obtener token de Google";
        }
        debugPrint('✓ Token de Google obtenido');

        userEmail = googleUser.email;
        userDisplayName = googleUser.displayName;
        userPhotoUrl = googleUser.photoUrl;

        // PASO 3: Sincronizar Firebase con Google Credential
        final fbCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        try {
          await FirebaseAuth.instance
              .signInWithCredential(fbCredential)
              .timeout(const Duration(seconds: 15));
          debugPrint('✓ Firebase Auth sincronizado con Google');
        } on FirebaseAuthException catch (e) {
          debugPrint('❌ Firebase Auth error: ${e.code}');
          return _handleFirebaseError(e);
        } on TimeoutException {
          debugPrint('⚠️ Firebase Auth timeout (continuando con backend...)');
        }
      }

      // PASO 4: Enviar token al backend
      debugPrint('🔄 Enviando token al backend...');
      final url = Uri.parse('$_baseUrl/auth/google');
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'token': googleToken}),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final appToken = data['access_token'];
          final bool isNewUser = data['is_new_user'] ?? false;

          await _storage.write(key: 'auth_token', value: appToken);
          bool success = await _loadUserData(appToken);

          if (!success) {
            email ??= userEmail;
            if (firstName == null) {
              final nameParts = (userDisplayName ?? '').split(' ');
              if (nameParts.isNotEmpty) firstName = nameParts.first;
              if (nameParts.length > 1) {
                lastName = nameParts.sublist(1).join(' ');
              }
            }
            if (email != null && firstName != null) {
              success = true;
              notifyListeners();
            }
          }

          if (!success) return "Error al cargar datos";
          debugPrint('✓ Login con Google completado (${isNewUser ? "nuevo" : "existente"})');
          return isNewUser ? "OK_NEW" : "OK_EXISTING";
        } else {
          try {
            final data = jsonDecode(response.body);
            return data['detail'] ?? 'Error de servidor (${response.statusCode})';
          } catch (_) {
            return 'Error de servidor (${response.statusCode})';
          }
        }
      } catch (e) {
        debugPrint("Error de conexión al backend en Google Sign-In: $e");
        if (FirebaseAuth.instance.currentUser != null) {
          email = userEmail;
          final nameParts = (userDisplayName ?? '').split(' ');
          if (nameParts.isNotEmpty) firstName = nameParts.first;
          if (nameParts.length > 1) {
            lastName = nameParts.sublist(1).join(' ');
          }
          if (userPhotoUrl != null && userPhotoUrl.isNotEmpty) {
            photoUrl = userPhotoUrl;
          }
          notifyListeners();
          return "OK_NEW";
        }
        return 'No se pudo conectar al servidor.\nVerifica tu conexión a internet.';
      }
    } on http.ClientException catch (e) {
      debugPrint("Error de conexión en Google Sign-In: $e");
      return 'No se pudo conectar al servidor.\n\nVerifica que:\n• El backend esté corriendo\n• La IP sea correcta: $_baseUrl\n• Tu dispositivo y PC estén en la misma red WiFi';
    } on SocketException catch (e) {
      debugPrint("Error de red en Google Sign-In: $e");
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('connection timed out') ||
          errorMsg.contains('timeout')) {
        return 'El servidor no responde.\n\nVerifica que:\n• El backend esté corriendo en $_baseUrl\n• El firewall permita conexiones en el puerto 8000\n• Tu dispositivo y PC estén en la misma red';
      }
      return 'Sin conexión a internet. Verifica tu red.';
    } on TimeoutException catch (e) {
      debugPrint("Timeout en Google Sign-In: $e");
      return 'La conexión tardó demasiado.\n\nEl servidor en $_baseUrl no responde.\nVerifica que el backend esté corriendo.';
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

  // FIRESTORE INVENTORY HELPERS
  Future<void> _syncInventoryItemToFirestore(
    String name,
    double quantity,
    String unit,
    String category,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .doc(name)
          .set({'quantity': quantity, 'unit': unit, 'category': category}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing item '$name' to Firestore: $e");
    }
  }

  Future<void> _deleteInventoryItemFromFirestore(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .doc(name)
          .delete();
    } catch (e) {
      debugPrint("Error deleting item '$name' from Firestore: $e");
    }
  }

  // --- PREMIUM FEATURES ---

  Future<bool> upgradeSubscription() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/subscription/upgrade'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        isPremium = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error upgrading subscription: $e");
    }
    return false;
  }

  Future<List<dynamic>> fetchMealPlans(DateTime start, DateTime end) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return [];

    try {
      final startStr = _formatDate(start);
      final endStr = _formatDate(end);

      final response = await http.get(
        Uri.parse('$_baseUrl/meal-plans?start_date=$startStr&end_date=$endStr'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(utf8.decode(response.bodyBytes));

        // Update local cache/calendar map
        for (var plan in plans) {
          final dateObj = DateTime.parse(plan['date']);
          final dateKey = _formatDate(dateObj);

          final menuData = {
            'breakfast': plan['breakfast'],
            'lunch': plan['lunch'],
            'dinner': plan['dinner'],
            'total_calories': plan['total_calories'],
            'breakfast_eaten': plan['breakfast_eaten'] ?? false,
            'lunch_eaten': plan['lunch_eaten'] ?? false,
            'dinner_eaten': plan['dinner_eaten'] ?? false,
            'extra_meals': plan['extra_meals'] ?? [],
          };
          _mealCalendar[dateKey] = menuData;
        }
        notifyListeners();
        return plans;
      }
    } catch (e) {
      debugPrint("Error fetching meal plans: $e");
    }
    return [];
  }

  Future<bool> saveMealPlan(
    DateTime date,
    Map<String, dynamic> menuData,
  ) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    final dateKey = _formatDate(date);
    _mealCalendar[dateKey] = menuData;
    notifyListeners();

    try {
      final body = {
        'date': dateKey,
        'breakfast': menuData['breakfast'],
        'lunch': menuData['lunch'],
        'dinner': menuData['dinner'],
        'total_calories': menuData['total_calories'] ?? 2000,
        'breakfast_eaten': menuData['breakfast_eaten'] ?? false,
        'lunch_eaten': menuData['lunch_eaten'] ?? false,
        'dinner_eaten': menuData['dinner_eaten'] ?? false,
        'extra_meals': menuData['extra_meals'] ?? [],
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/meal-plans'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Guardar también en Firestore como backup para sincronización
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('daily_menus')
                .doc(dateKey)
                .set(menuData, SetOptions(merge: true));
          } catch (e) {
            debugPrint("Error saving meal plan to Firestore: $e");
          }
        }
        return true;
      } else {
        debugPrint("Error conserving meal plan: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error saving meal plan: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>?> generateMenuConIA({DateTime? date, List<String>? rejectedRecipes}) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      final bodyStr = jsonEncode({'rejected_recipes': rejectedRecipes ?? []});
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-menu'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: bodyStr,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final menuData = {
          'breakfast': data['breakfast'],
          'lunch': data['lunch'],
          'dinner': data['dinner'],
          'total_calories': data['total_calories'],
          'note': data['note'],
          'extra_meals': data['extra_meals'] ?? [],
        };

        final targetDate = date ?? DateTime.now();

        if (_isSameDay(targetDate, DateTime.now())) {
          generatedMenu = menuData;
          int sumCals = (data['breakfast']?['calories'] ?? 0) as int;
          sumCals += (data['lunch']?['calories'] ?? 0) as int;
          sumCals += (data['dinner']?['calories'] ?? 0) as int;
          if (data['extra_meals'] is List) {
            for (var m in data['extra_meals']) {
              if (m is Map && m['calories'] != null) {
                sumCals += (m['calories'] as num).toInt();
              }
            }
          }
          totalCalories = (data['total_calories'] as int?) ?? sumCals;
        }

        await saveMealPlan(targetDate, menuData);

        notifyListeners();
        return menuData;
      } else if (response.statusCode == 400) {
        // Probablemente "Inventario vacío"
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = data['detail'] ?? 'Error de validación';
        throw Exception(detail);
      } else {
        debugPrint("Error generating menu: ${response.body}");
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error calling generate-menu: $e");
      rethrow; // Lanzar para que la UI pueda atraparlo y mostrar SnackBar
    }
  }

  Future<void> generateWeeklyMenuConIA() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    if (!isPremium) {
      throw Exception("Esta función es solo para usuarios Premium");
    }

    try {
      final clientDate = _formatDate(DateTime.now());
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-weekly-menu?client_date=$clientDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        // We can pass an empty body or {}
      ).timeout(const Duration(seconds: 120)); // Allow 2 minutes for 7-day generation

      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(utf8.decode(response.bodyBytes));
        
        final user = FirebaseAuth.instance.currentUser;
        
        for (var plan in plans) {
          final dateStr = plan['date'];
          DateTime dateObj = DateTime.parse(dateStr);
          final dateKey = _formatDate(dateObj);
          
          final menuData = {
            'breakfast': plan['breakfast'],
            'lunch': plan['lunch'],
            'dinner': plan['dinner'],
            'total_calories': plan['total_calories'],
            'breakfast_eaten': plan['breakfast_eaten'] ?? false,
            'lunch_eaten': plan['lunch_eaten'] ?? false,
            'dinner_eaten': plan['dinner_eaten'] ?? false,
            'extra_meals': plan['extra_meals'] ?? [],
          };
          
          _mealCalendar[dateKey] = menuData;
          
          if (_isSameDay(dateObj, DateTime.now())) {
            generatedMenu = menuData;
            totalCalories = menuData['total_calories'] as int? ?? 0;
          }
          
          if (user != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('daily_menus')
                  .doc(dateKey)
                  .set(menuData, SetOptions(merge: true));
            } catch (e) {
              debugPrint("Error saving to firestore: $e");
            }
          }
        }
        
        notifyListeners();
      } else if (response.statusCode == 400) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = data['detail'] ?? 'Error de validación';
        throw Exception(detail);
      } else if (response.statusCode == 403) {
        throw Exception("Requiere suscripción Premium");
      } else {
        String errorMessage = "Error del servidor: ${response.statusCode}";
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['detail'] != null) {
            errorMessage = data['detail'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint("Error calling generate-weekly-menu: $e");
      rethrow;
    }
  }

  Future<List<String>?> markMealEaten(DateTime date, String mealType, bool eaten) async {
    final dateKey = _formatDate(date);
    
    // Update locally first for fast UI (synchronous, no await)
    if (_mealCalendar.containsKey(dateKey)) {
      if (mealType.startsWith('extra')) {
        int idx = 0;
        if (mealType.contains('_')) {
          idx = int.tryParse(mealType.split('_')[1]) ?? 0;
        }
        var extraList = _mealCalendar[dateKey]!['extra_meals'];
        if (extraList is List && idx < extraList.length) {
          if (extraList[idx] is Map) {
            extraList[idx]['eaten'] = eaten;
          }
        }
        _mealCalendar[dateKey]!['${mealType}_eaten'] = eaten;
      } else {
        _mealCalendar[dateKey]!['${mealType}_eaten'] = eaten;
      }
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_menus')
              .doc(dateKey)
              .set(_mealCalendar[dateKey]!, SetOptions(merge: true));
        } catch (e) {
          debugPrint("Error saving meal eaten state to firestore: $e");
        }
      }
    }

    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/meal-plans/$dateKey/mark-eaten'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'meal_type': mealType,
          'eaten': eaten,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        if (eaten) {
          // Refrescar inventario si se ha consumido la comida
          await fetchInventory();
        }
        if (responseData.containsKey('depleted_items')) {
           final List<dynamic> depleted = responseData['depleted_items'];
           return depleted.map((e) => e.toString()).toList();
        }
        return [];
      } else if (response.statusCode == 404 && _mealCalendar.containsKey(dateKey)) {
        // Backend DB might have been wiped or is out of sync.
        // Let's re-upload the local meal plan and retry the patch.
        debugPrint("Meal plan not found on backend. Syncing local to backend...");
        bool saved = await saveMealPlan(date, Map<String, dynamic>.from(_mealCalendar[dateKey]!));
        if (saved) {
          final retryResponse = await http.patch(
            Uri.parse('$_baseUrl/meal-plans/$dateKey/mark-eaten'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'meal_type': mealType,
              'eaten': eaten,
            }),
          );
          if (retryResponse.statusCode == 200) {
            final responseData = jsonDecode(utf8.decode(retryResponse.bodyBytes));
            if (eaten) await fetchInventory();
            if (responseData.containsKey('depleted_items')) {
               final List<dynamic> depleted = responseData['depleted_items'];
               return depleted.map((e) => e.toString()).toList();
            }
            return [];
          }
        }
      }
    } catch (e) {
      debugPrint("Error marking meal eaten: $e");
    }
    return null;
  }

  /// Verifica si un día específico fue completado al 100% según mealsPerDay (3, 4 o 5)
  bool isDateKeyCompleted(String dateKey) {
    final menu = _mealCalendar[dateKey];
    if (menu == null) return false;

    // Verificar las 3 comidas principales
    final b = menu['breakfast_eaten'] == true;
    final l = menu['lunch_eaten'] == true;
    final d = menu['dinner_eaten'] == true;
    if (!b || !l || !d) return false;

    final reqMeals = mealsPerDay;
    if (reqMeals <= 3) return true;

    final extraList = menu['extra_meals'];
    if (extraList is List && extraList.isNotEmpty) {
      if (reqMeals == 4) {
        // Requiere al menos 1 colación marcada como comida
        bool hasExtraEaten = (extraList[0] is Map && (extraList[0]['eaten'] == true)) ||
            menu['extra_0_eaten'] == true ||
            menu['extra_eaten'] == true;
        return hasExtraEaten;
      } else if (reqMeals >= 5) {
        // Requiere al menos 2 colaciones marcadas como comidas
        int extraEatenCount = 0;
        for (int i = 0; i < extraList.length; i++) {
          final item = extraList[i];
          if ((item is Map && item['eaten'] == true) || menu['extra_${i}_eaten'] == true) {
            extraEatenCount++;
          }
        }
        final requiredCount = extraList.length >= 2 ? 2 : extraList.length;
        return extraEatenCount >= requiredCount;
      }
    }
    return true;
  }

  /// Calcula la racha actual de días consecutivos cumplidos (estilo Duolingo)
  int get currentStreak {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _formatDate(today);

    int streak = 0;
    bool todayDone = isDateKeyCompleted(todayKey);

    if (todayDone) {
      streak = 1;
      DateTime checkDate = today.subtract(const Duration(days: 1));
      while (true) {
        String key = _formatDate(checkDate);
        if (isDateKeyCompleted(key)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    } else {
      DateTime yesterday = today.subtract(const Duration(days: 1));
      String yesterdayKey = _formatDate(yesterday);
      if (isDateKeyCompleted(yesterdayKey)) {
        streak = 1;
        DateTime checkDate = yesterday.subtract(const Duration(days: 1));
        while (true) {
          String key = _formatDate(checkDate);
          if (isDateKeyCompleted(key)) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      } else {
        streak = 0;
      }
    }

    return streak;
  }

  /// Cantidad de comidas completadas hoy (de las requeridas)
  int get todayCompletedMealsCount {
    final todayKey = _formatDate(DateTime.now());
    final menu = _mealCalendar[todayKey];
    if (menu == null) return 0;

    int count = 0;
    if (menu['breakfast_eaten'] == true) count++;
    if (menu['lunch_eaten'] == true) count++;
    if (menu['dinner_eaten'] == true) count++;

    final extraList = menu['extra_meals'];
    if (extraList is List) {
      for (int i = 0; i < extraList.length; i++) {
        final item = extraList[i];
        if ((item is Map && item['eaten'] == true) || menu['extra_${i}_eaten'] == true) {
          count++;
        }
      }
    }
    return count;
  }

  /// Cantidad total de comidas configuradas para hoy
  int get todayTotalMealsCount {
    return mealsPerDay;
  }

  Future<void> fetchInventory() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    
    try {
      final invResponse = await http
          .get(
            Uri.parse('$_baseUrl/inventory'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (invResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(invResponse.body);
        _inventory.clear();
        for (var item in data) {
          _inventory[item['name']] = {
            'quantity': (item['quantity'] ?? 0).toDouble(),
            'unit': item['unit'] ?? 'Unidades',
          };
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching inventory from network: $e");
    }
  }

  Future<bool> addExtraMeal(DateTime date, Map<String, dynamic> extraMeal) async {
    final dateKey = _formatDate(date);
    
    // Asegurar que la comida extra escaneada tenga estado de consumida
    extraMeal['eaten'] = true;

    // 1. OPTIMISTIC UPDATE LOCAL: Se refleja de inmediato en pantalla y en los macros
    Map<String, dynamic> currentMenu = _mealCalendar[dateKey] != null
        ? Map<String, dynamic>.from(_mealCalendar[dateKey]!)
        : {
            'breakfast': null,
            'lunch': null,
            'dinner': null,
            'extra_meals': <dynamic>[],
            'total_calories': 0,
          };

    List<dynamic> currentExtras = (currentMenu['extra_meals'] is List)
        ? List<dynamic>.from(currentMenu['extra_meals'] as List)
        : <dynamic>[];

    currentExtras.add(extraMeal);
    currentMenu['extra_meals'] = currentExtras;

    _mealCalendar[dateKey] = currentMenu;
    if (_isSameDay(date, DateTime.now())) {
      generatedMenu = currentMenu;
    }
    notifyListeners();

    // Guardar en almacenamiento local para persistencia offline
    try {
      String calendarKey = 'meal_calendar_local';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) calendarKey = 'meal_calendar_local_${user.uid}';
      await _storage.write(
        key: calendarKey,
        value: jsonEncode(_mealCalendar),
      );
    } catch (_) {}

    // 2. SINCRONIZACIÓN CON BACKEND
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return true;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/meal-plans/$dateKey/extra-meal'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(extraMeal),
      );

      if (response.statusCode == 200) {
        await fetchMealPlans(date, date);
        return true;
      } else {
        debugPrint("Backend returned ${response.statusCode} on extra-meal: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error adding extra meal to backend: $e");
    }
    return true; // Retorna true porque ya quedó registrado localmente
  }

  Future<Map<String, dynamic>?> analyzeFood({String? text, String? imagePath}) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze-food'));
      request.headers.addAll({'Authorization': 'Bearer $token'});

      if (text != null && text.isNotEmpty) {
        request.fields['text_description'] = text;
      }

      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseData);
      } else {
        debugPrint("Error analyzeFood: ${response.statusCode} - $responseData");
      }
    } catch (e) {
      debugPrint("Error analyzing food: $e");
    }
    return null;
  }

  Future<List<dynamic>?> scanFridge(Uint8List bytes, String filename) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/inventory/scan-fridge'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseData);
        return decoded['items'] as List<dynamic>?;
      } else {
        debugPrint("Error scanFridge: ${response.statusCode} - $responseData");
      }
    } catch (e) {
      debugPrint("Error in scanFridge: $e");
    }
    return null;
  }

  Future<List<dynamic>?> scanReceipt(Uint8List bytes, String filename) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/inventory/scan-receipt'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseData);
        return decoded['items'] as List<dynamic>?;
      } else {
        debugPrint("Error scanReceipt: ${response.statusCode} - $responseData");
      }
    } catch (e) {
      debugPrint("Error in scanReceipt: $e");
    }
    return null;
  }


  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<dynamic>?> getShoppingSuggestions() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/inventory/suggest'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['suggestions'];
      } else if (response.statusCode == 403) {
        // Not Premium
        return []; // Handle externally or throw
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    }
    return null;
  }

  void setPersonalData({String? firstName, String? lastName}) {
    this.firstName = firstName ?? this.firstName;
    this.lastName = lastName ?? this.lastName;
    notifyListeners();
  }

  Future<void> updateFood(String foodKey, double quantity, String unit, {String category = 'Otros'}) async {
    // 1. OPTIMISTIC UPDATE
    _inventory[foodKey] = {'quantity': quantity, 'unit': unit, 'category': category};

    // CACHE UPDATE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // ignore: unawaited_futures
      _storage.write(
        key: 'inventory_cache_${user.uid}',
        value: jsonEncode(_inventory),
      );
      // FIRESTORE SYNC
      // ignore: unawaited_futures
      _syncInventoryItemToFirestore(foodKey, quantity, unit, category);
    }

    notifyListeners();

    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      // PREVENT BACKEND 500: normalize
      dynamic backendQuantity = quantity;
      String backendUnit = unit;

      String baseUnit = _getBaseUnitFor(unit);
      if (baseUnit == 'g' || baseUnit == 'ml') {
        backendQuantity = _convertToBase(quantity, unit);
        backendUnit = baseUnit;
      } else {
        backendQuantity = quantity;
      }

      // Safety check: Backend often rejects 0
      if (backendQuantity == 0) backendQuantity = 1;

      final response = await http
          .put(
            Uri.parse('$_baseUrl/inventory/${Uri.encodeComponent(foodKey)}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'quantity': backendQuantity,
              'unit': backendUnit,
              'category': category,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await logout();
      }
    } catch (e) {
      // print("Error actualizando comida: $e");
    }
  }

  Future<bool> addFood(
    String food, {
    double quantity = 1.0,
    String unit = 'Unidades',
    String category = 'Otros',
    double? exactCalories,
    double? exactProteins,
    double? exactFats,
    double? exactCarbs,
  }) async {
    String normalizedKey = food.trim().toLowerCase();
    if (normalizedKey.isEmpty) return false;

    // CHECK FOR EXISTING ITEM TO ACCUMULATE
    if (_inventory.containsKey(normalizedKey)) {
      try {
        final currentData = _inventory[normalizedKey];
        double currentQty = (currentData?['quantity'] as num? ?? 0).toDouble();
        String currentUnit = currentData?['unit'] ?? 'Unidades';

        // Convert both to base to safely sum
        double currentBase = _convertToBase(currentQty, currentUnit);
        double newBase = _convertToBase(quantity, unit);
        double totalBase = currentBase + newBase;

        String targetUnit = _getBaseUnitFor(currentUnit);
        // If unknown or compatible, stick to base.
        // If the user was using "Kg" and we add "g", target is "g".
        // This effectively upgrades storage to the refined unit.

        debugPrint(
          "addFood ACCUMULATING: $normalizedKey. Old: $currentQty $currentUnit. New: $quantity $unit. TotalBase: $totalBase $targetUnit",
        );

        // Use updateFood (which handles optimistic + normalization)
        await updateFood(normalizedKey, totalBase, targetUnit, category: category);
        return true;
      } catch (e) {
        debugPrint("Error accumulating food: $e. Fallback to overwrite.");
        // Fallback to processing as new if accumulation fails logic (unlikely)
      }
    }

    // 1. OPTIMISTIC UPDATE (New Item)
    _inventory[normalizedKey] = {'quantity': quantity, 'unit': unit, 'category': category};

    // CACHE UPDATE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // ignore: unawaited_futures
      _storage.write(
        key: 'inventory_cache_${user.uid}',
        value: jsonEncode(_inventory),
      );
      // FIRESTORE SYNC
      // ignore: unawaited_futures
      _syncInventoryItemToFirestore(normalizedKey, quantity, unit, category);
    }

    notifyListeners();

    debugPrint("addFood OPTIMISTIC: Added $normalizedKey locally.");

    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      debugPrint("addFood: NO TOKEN - Item kept local only.");
      return true; // Return true because it IS added locally
    }

    try {
      // PREVENT BACKEND 500: normalize to integer base units
      dynamic backendQuantity = quantity;
      String backendUnit = unit;

      String baseUnit = _getBaseUnitFor(unit);
      if (baseUnit == 'g' || baseUnit == 'ml') {
        backendQuantity = _convertToBase(quantity, unit);
        backendUnit = baseUnit;
      } else {
        // Unidades or unknown: Remove round to int
        backendQuantity = quantity;
      }

      // Safety check: Backend often rejects 0
      if (backendQuantity == 0) backendQuantity = 1;

      debugPrint("addFood sending: $backendQuantity $backendUnit");

      final response = await http
          .post(
            Uri.parse('$_baseUrl/inventory'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': normalizedKey,
              'quantity': backendQuantity,
              'unit': backendUnit,
              'category': category,
              'calories': exactCalories,
              'proteins': exactProteins,
              'fats': exactFats,
              'carbs': exactCarbs,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint("addFood API Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['quantity'] != null) {
          // Sync with server response
          _inventory[normalizedKey] = {
            'quantity': (data['quantity'] as num).toDouble(),
            'unit': data['unit'] ?? backendUnit,
          };
          notifyListeners();
        }
        return true;
      } else {
        debugPrint(
          "addFood FAILED persistence: ${response.statusCode} - ${response.body}",
        );
        return false; // Backend rejected it explicitly
      }
    } catch (e) {
      debugPrint("addFood ERROR: $e");
      return false; // Exception
    }
  }

  Future<void> removeFood(String foodKey) async {
    // 1. OPTIMISTIC UPDATE: Remove locally first
    if (_inventory.containsKey(foodKey)) {
      _inventory.remove(foodKey);
      notifyListeners(); // Update UI immediately
    }

    // 2. CACHE & FIRESTORE UPDATE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Save new inventory state to local cache
        // ignore: unawaited_futures
        _storage.write(
          key: 'inventory_cache_${user.uid}',
          value: jsonEncode(_inventory),
        );
        // Sync delete to Firestore
        // ignore: unawaited_futures
        _deleteInventoryItemFromFirestore(foodKey);
      } catch (e) {
        debugPrint("Error syncing deletion to cache/firestore: $e");
      }
    }

    // 3. BACKEND SYNC
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/inventory/remove/${Uri.encodeComponent(foodKey)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("Backend deletion successful for $foodKey");
      } else if (response.statusCode == 401) {
        // If auth fails, we might need to logout, but for now just log
        debugPrint("Backend 401 during delete. Token might be expired.");
        // valid logic would be to await logout(), but that disrupts the user flow for a simple delete.
        // We stick to optimistic.
      } else {
        debugPrint("Backend delete failed: ${response.statusCode}");
        // Optional: Rollback? ideally yes, but for MVP keep it simple.
        // If we rollback, the item pops back in, which is jarring.
      }
    } catch (e) {
      debugPrint("Error connecting to backend for delete: $e");
    }
  }

  Future<bool> saveUserPhysicalData({ 
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    double? height,
    double? weight,
    String? goal,
    String? gender,
    int? newMealsPerDay, 
    Map<String, String>? newMealTimes 
  }) async {
    final token = await _storage.read(key: 'auth_token');

    // 1. UPDATE MEMORY (Optimistic Code)
    // We update our local class state immediately with the new values provided.
    // If an argument is null, we keep the current value.
    if (firstName != null) this.firstName = firstName;
    if (lastName != null) this.lastName = lastName;
    if (birthdate != null) this.birthdate = birthdate;
    if (height != null) this.height = height;
    if (weight != null) this.weight = weight;
    if (goal != null) this.goal = goal;
    if (gender != null) this.gender = gender;

    notifyListeners(); // Immediate UI feedback

    bool backendSuccess = false;

    // 2. BACKEND SYNC (Best Effort with generous timeout)
    if (token != null) {
      final url = Uri.parse('$_baseUrl/users/me/data');
      final Map<String, dynamic> body = {};
      if (newMealsPerDay != null) {
        body['meals_per_day'] = newMealsPerDay;
        mealsPerDay = newMealsPerDay;
      }
      if (newMealTimes != null) {
        body['meal_times'] = newMealTimes;
        mealTimes = newMealTimes;
      }
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (birthdate != null) body['birthdate'] = birthdate.toIso8601String();
      if (height != null) body['height'] = height;
      if (weight != null) body['weight'] = weight;
      if (goal != null) body['goal'] = goal;
      if (gender != null) body['gender'] = gender;

      try {
        final response = await http
            .put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['goal'] != null) this.goal = data['goal'];
          backendSuccess = true;
        } else if (response.statusCode == 401) {
          debugPrint("Backend 401: Token expired. Sync failed.");
        } else {
          debugPrint(
            "Backend Warning (${response.statusCode}): ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Backend Exception (sync failed): $e");
      }
    }

    // 3. FIRESTORE SYNC (Robust Persistence)
    bool firestoreSuccess = false;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final Map<String, dynamic> firestoreData = {};
        if (this.height != null) firestoreData['height'] = this.height;
        if (this.weight != null) firestoreData['weight'] = this.weight;
        if (this.birthdate != null) {
          firestoreData['birthdate'] = this.birthdate?.toIso8601String();
        }
        if (this.firstName != null) {
          firestoreData['first_name'] = this.firstName;
        }
        if (this.lastName != null) firestoreData['last_name'] = this.lastName;
        if (this.gender != null) firestoreData['gender'] = this.gender;
        if (this.goal.isNotEmpty) firestoreData['goal'] = this.goal;
        firestoreData['meals_per_day'] = mealsPerDay;
        firestoreData['meal_times'] = mealTimes;

        if (firestoreData.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(firestoreData, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
          debugPrint("Firestore Sync Successful");
          firestoreSuccess = true;
        }
      } catch (fsError) {
        debugPrint("Error syncing physical data to Firestore: $fsError");
      }

      if (goal != null) {
        await _storage.write(key: 'user_goal_${user.uid}', value: goal);
      }
    }

    // 4. LOCAL CACHE UPDATE (Offline Persistence)
    bool localCacheSuccess = false;
    if (user != null) {
      try {
        String? currentCacheStr = await _storage.read(
          key: 'user_profile_cache_${user.uid}',
        );
        Map<String, dynamic> cacheData = {};
        if (currentCacheStr != null) {
          cacheData = jsonDecode(currentCacheStr);
        }

        if (this.firstName != null) cacheData['first_name'] = this.firstName;
        if (this.lastName != null) cacheData['last_name'] = this.lastName;
        if (this.height != null) cacheData['height'] = this.height;
        if (this.weight != null) cacheData['weight'] = this.weight;
        if (this.birthdate != null) {
          cacheData['birthdate'] = this.birthdate?.toIso8601String();
        }
        if (this.gender != null) cacheData['gender'] = this.gender;
        cacheData['goal'] = this.goal;
        if (photoUrl != null) cacheData['photo_url'] = photoUrl;
        if (email != null) cacheData['email'] = email;
        cacheData['meals_per_day'] = mealsPerDay;
        cacheData['meal_times'] = mealTimes;

        await _storage.write(
          key: 'user_profile_cache_${user.uid}',
          value: jsonEncode(cacheData),
        );
        debugPrint("Local Cache Sync Successful");
        localCacheSuccess = true;
      } catch (e) {
        debugPrint("Error updating profile cache: $e");
      }
    }

    return backendSuccess || firestoreSuccess || localCacheSuccess;
  }

  Future<bool> saveUserGoal(String goal) async {
    this.goal = goal;
    notifyListeners();

    final token = await _storage.read(key: 'auth_token');
    bool backendSuccess = false;

    if (token != null) {
      final url = Uri.parse('$_baseUrl/users/me/data');
      try {
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'goal': goal}),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          backendSuccess = true;
        } else if (response.statusCode == 401) {
          await logout();
          return false;
        }
      } catch (e) {
        debugPrint("Error updating goal in backend: $e");
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    bool firestoreSuccess = false;
    if (user != null) {
      await _storage.write(key: 'user_goal_${user.uid}', value: goal);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'goal': goal}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        firestoreSuccess = true;
      } catch (e) {
        debugPrint("Firestore Goal Sync Error: $e");
      }
    }

    return backendSuccess || firestoreSuccess || token != null;
  }

  Future<String?> uploadProfilePicture(Uint8List fileBytes) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return "No estás autenticado";

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "No estás autenticado";

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/users/me/upload-photo'));
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: 'profile_photo.jpg'));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseData);
        photoUrl = decoded['photo_url'];

        // Persist locally
        await _storage.write(
          key: 'profile_photo_url_${user.uid}',
          value: photoUrl,
        );

        // Update cache
        String? cached = await _storage.read(key: 'user_profile_cache_current');
        if (cached != null) {
          final data = jsonDecode(cached);
          data['photo_url'] = photoUrl;
          await _storage.write(
            key: 'user_profile_cache_current',
            value: jsonEncode(data),
          );
        }
        notifyListeners();
        return null; // Success
      } else {
        return "Error del servidor: ${response.statusCode} - $responseData";
      }
    } catch (e) {
      debugPrint("Error uploadProfilePicture: $e");
      return "Error de conexión: $e";
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      debugPrint("Starting profile photo DELETE for ${user.uid}...");

      // FIX: Try to delete from default first, then fallbacks if needed, but for delete we keep it simple for now
      // Logic: If we saved it, we probably saved it to one of them.
      // Ideally we would store the bucket used, but for now let's try Default.
      final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile_photo.jpg',
      );

      try {
        await ref.delete();
        debugPrint("Deleted from Firebase Storage (Default).");
      } catch (e) {
        debugPrint("Warning: Storage delete failed (maybe already gone): $e");
      }

      // 2. Clear from Memory
      photoUrl = null;

      // 3. Clear from Local Storage
      await _storage.delete(key: 'profile_photo_url_${user.uid}');

      // 4. Clear from Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photo_url': FieldValue.delete()},
      );

      // 5. Notify Backend (Best Effort) to clear its reference
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        final url = Uri.parse('$_baseUrl/users/me/delete-photo');
        try {
          // ignore: unawaited_futures
          http
              .delete(url, headers: {'Authorization': 'Bearer $token'})
              .timeout(const Duration(seconds: 5));
          // Fire and forget-ish
        } catch (e) {
          debugPrint("Backend delete sync failed: $e");
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error deleting profile picture: $e");
      return false;
    }
  }

  // --- ACTUALIZAR PASSWORD EN BACKEND ---
  Future<String> updateBackendPassword(String newPassword) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return "No hay token de sesión";

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/me/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': newPassword}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return "OK";
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
    debugPrint("Saving menu for $dateKey. Items: ${menu.keys}");

    // 1. Memory Update - Ensure strict type
    _mealCalendar[dateKey] = Map<String, dynamic>.from(menu);
    notifyListeners();

    // 2. Persistence: Local Storage (Full Calendar)
    try {
      debugPrint("Saving calendar to Local Storage...");
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
      debugPrint(
        "Saving menu to Firestore: users/${user.uid}/daily_menus/$dateKey",
      );

      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_menus')
          .doc(dateKey)
          .set(
            menu,
            SetOptions(merge: true),
          ) // Guardamos el mapa directo como documento
          // ignore: unawaited_futures
          .then(
            (_) => debugPrint(
              "Menú del día $dateKey guardado en Firestore EXITOSAMENTE",
            ),
          )
          .catchError(
            (e) => debugPrint("Error guardando menú en Firestore: $e"),
          );
      // Fire and forget - intencionalmente no esperado
    } else {
      debugPrint(
        "WARNING: No Firebase User found. Menu NOT saved to Firestore.",
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
            match.group(3) ?? '${match.group(2) ?? ''} ${match.group(3) ?? ''}';
        ingredientName = ingredientName.trim();
      }
    }

    // Normalized search
    String? matchedKey;
    final normalizedSearch = ingredientName.toLowerCase().trim();

    for (var key in _inventory.keys.toList()) {
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
            qtyToSend = resultBase; // allow decimal units like 1.5 
            unitToSend =
                currentData['unit']; // Keep original name if it was 'Huevos' etc, actually _getBase returns 'u' for unknown.
            if (unitToSend == 'u') {
              unitToSend = currentData['unit']; // if it was 'Unidades' keep it.
            }
          } else {
            // For Mass/Vol, we use the base value (g or ml)
            qtyToSend = resultBase;
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
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-menu'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // Extract only the requested meal type from the full menu
        final mealData = data[type];
        if (mealData != null) {
          return Map<String, dynamic>.from(mealData);
        }
      } else {
        debugPrint("Error regenerating meal: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error calling regenerate meal: $e");
    }
    return null;
  }



  // --- DELETE ACCOUNT ---
  Future<bool> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    debugPrint("INICIANDO ELIMINACIÓN DE CUENTA para ${user.uid}...");

    try {
      // 1. DELETE FROM FIRESTORE (Recursive-ish cleanup)
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // A. Delete Subcollection: Inventory
      final invSnap = await userDoc.collection('inventory').get();
      for (var doc in invSnap.docs) {
        await doc.reference.delete();
      }
      debugPrint("Inventario eliminado de Firestore.");

      // B. Delete Subcollection: Daily Menus
      final menuSnap = await userDoc.collection('daily_menus').get();
      for (var doc in menuSnap.docs) {
        await doc.reference.delete();
      }
      debugPrint("Menús eliminados de Firestore.");

      // C. Delete Main Document
      await userDoc.delete();
      debugPrint("Documento de usuario eliminado de Firestore.");

      // 2. DELETE FROM STORAGE (Profile Photo)
      // Attempt to delete from all potential buckets (best effort)
      final buckets = [
        null, // Default
        'gs://mealiav2.appspot.com',
        'gs://mealiav2.firebasestorage.app',
      ];
      for (var bucket in buckets) {
        try {
          final storage = bucket == null
              ? FirebaseStorage.instance
              : FirebaseStorage.instanceFor(bucket: bucket);
          final ref = storage.ref().child(
            'users/${user.uid}/profile_photo.jpg',
          );
          await ref.delete();
          debugPrint("Foto borrada de Bucket: ${bucket ?? 'Default'}");
        } catch (e) {
          // Ignore, file might not exist
        }
      }

      // 3. DELETE FROM BACKEND (Best effort sync)
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        try {
          // Assuming endpoint DELETE /users/me exists or fails gracefully
          await http
              .delete(
                Uri.parse('$_baseUrl/users/me'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint("Backend delete warning: $e");
        }
      }

      // 4. CLEAN LOCAL STORAGE
      await _storage.deleteAll();

      // 5. DELETE AUTH ACCOUNT (This logs out automatically)
      // Re-authenticate might be needed if sensitive, but we try direct delete
      await user.delete();
      debugPrint("Cuenta de Firebase Auth eliminada.");

      // Cleanup Memory
      clearMemoryState();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("CRITICAL ERROR deleting account: $e");
      // If error is 'requires-recent-login', handle in UI?
      // For now we return false.
      return false;
    }
  }
}
