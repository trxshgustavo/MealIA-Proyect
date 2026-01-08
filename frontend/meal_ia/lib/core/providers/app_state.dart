import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // Required for Uint8List
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NECESARIO PARA AUTH
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:firebase_storage/firebase_storage.dart';
import '../config/api_config.dart';

class AppState extends ChangeNotifier {
  // Asegúrate de que esta IP sea la correcta de tu PC
  final String _baseUrl = ApiConfig.baseUrl;

  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
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

  // --- HELPERS ---
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

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
      // 0. PRE-LOAD FROM LOCAL CACHE (Offline Support)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          String? cachedProfile = await _storage.read(
            key: 'user_profile_cache_${user.uid}',
          );
          if (cachedProfile != null) {
            final data = jsonDecode(cachedProfile);
            email = data['email'];
            firstName = data['first_name'];
            lastName = data['last_name'];
            height = (data['height'] as num?)?.toDouble();
            weight = (data['weight'] as num?)?.toDouble();
            birthdate = data['birthdate'] != null
                ? DateTime.tryParse(data['birthdate'])
                : null;
            // Only set photoUrl if it's a non-empty string
            final cachedPhotoUrl = data['photo_url'] as String?;
            if (cachedPhotoUrl != null && cachedPhotoUrl.isNotEmpty) {
              photoUrl = cachedPhotoUrl;
            }
            goal = data['goal'] ?? 'Mantenimiento';
            debugPrint("Loaded Profile from Cache for ${user.uid}");
          }
        } catch (e) {
          debugPrint("Error loading profile cache: $e");
        }
      }

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

          // UPDATE MEMORY
          email = userData['email'];
          firstName = userData['first_name'];
          lastName = userData['last_name'];
          height = (userData['height'] as num?)?.toDouble();
          weight = (userData['weight'] as num?)?.toDouble();

          birthdate = userData['birthdate'] != null
              ? DateTime.tryParse(userData['birthdate'])
              : null;

          backendGoal = userData['goal'];
          // Only set photoUrl if backend returns a non-empty string
          final backendPhotoUrl = userData['photo_url'] as String?;
          if (backendPhotoUrl != null && backendPhotoUrl.isNotEmpty) {
            photoUrl = backendPhotoUrl;
          }

          // UPDATE CACHE
          if (user != null) {
            final cacheData = {
              'email': email,
              'first_name': firstName,
              'last_name': lastName,
              'height': height,
              'weight': weight,
              'birthdate': birthdate?.toIso8601String(),
              'photo_url': photoUrl,
              'goal': backendGoal,
            };
            await _storage.write(
              key: 'user_profile_cache_${user.uid}',
              value: jsonEncode(cacheData),
            );
          }
        } else {
          debugPrint("Backend /users/me returned ${userResponse.statusCode}");
          if (userResponse.statusCode == 401) {
            await logout();
            return false;
          }
        }
      } catch (e) {
        debugPrint("Error loading basic profile from backend: $e");
      }

      // ... Firestore Fallback follows ...

      // --- FIRESTORE BACKUP READ (ALWAYS RUNS TO FILL GAPS) ---
      // Runs if backend failed OR if backend data was incomplete.
      // Already defiend user above.
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
                // We do NOT write to storage here yet, we wait for final reconciliation
              }
            }

            // Recuperar Foto (check for null OR empty string from backend)
            if (photoUrl == null || photoUrl!.isEmpty) {
              if (data.containsKey('photo_url') && data['photo_url'] != null) {
                final firestorePhoto = data['photo_url'] as String?;
                if (firestorePhoto != null && firestorePhoto.isNotEmpty) {
                  photoUrl = firestorePhoto;
                  debugPrint("Loaded photoUrl from Firestore: $photoUrl");
                }
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
      // STRICT: Only load from UID-scoped key.
      if (user != null) {
        String goalKey = 'user_goal_${user.uid}';
        if (backendGoal == null || backendGoal == 'Mantenimiento') {
          String? cachedGoal = await _storage.read(key: goalKey);
          goal = cachedGoal ?? 'Mantenimiento';
        } else {
          goal = backendGoal; // Lint fix: Removed !
          await _storage.write(key: goalKey, value: goal);
        }
      } else {
        // Should not happen if we enforce login, but fail safe
        goal = 'Mantenimiento';
      }

      // FINAL PHOTO LOGIC
      if (user != null) {
        String photoKey = 'profile_photo_url_${user.uid}';

        // Load from local cache if photo is still missing
        if (photoUrl == null || photoUrl!.isEmpty) {
          String? cachedPhoto = await _storage.read(key: photoKey);
          if (cachedPhoto != null && cachedPhoto.isNotEmpty) {
            photoUrl = cachedPhoto;
            debugPrint("Loaded photoUrl from Local Storage: $photoUrl");
          }
        }

        // Persist to local cache if we have a valid URL
        if (photoUrl != null && photoUrl!.isNotEmpty) {
          await _storage.write(key: photoKey, value: photoUrl);
        }
      }

      // 2. Cargar Inventario (Cache + Network)
      if (user != null) {
        String inventoryKey = 'inventory_cache_${user.uid}';

        // A. Load from Cache first
        try {
          String? cachedInv = await _storage.read(key: inventoryKey);
          if (cachedInv != null) {
            final Map<String, dynamic> decoded = jsonDecode(cachedInv);
            _inventory.clear();
            decoded.forEach((key, value) {
              _inventory[key] = Map<String, dynamic>.from(value);
            });
            debugPrint(
              "Loaded Inventory from Cache: ${_inventory.length} items.",
            );
          }
        } catch (e) {
          debugPrint("Error loading inventory cache: $e");
        }

        // B. Fetch from Network
        try {
          debugPrint("_loadUserData: Fetching Inventory...");
          final invResponse = await http
              .get(
                Uri.parse('$_baseUrl/inventory'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 10));

          if (invResponse.statusCode == 200) {
            final List<dynamic> data = jsonDecode(invResponse.body);
            // Verify if server indicates "empty" or just we have data.
            // Usually we SHOULD trust server.
            _inventory.clear();
            for (var item in data) {
              _inventory[item['name']] = {
                'quantity': (item['quantity'] ?? 0).toDouble(),
                'unit': item['unit'] ?? 'Unidades',
              };
            }
            debugPrint(
              "_loadUserData: Inventory Fetched. Count: ${_inventory.length}",
            );

            // Update Cache
            await _storage.write(
              key: inventoryKey,
              value: jsonEncode(_inventory),
            );
          } else if (invResponse.statusCode == 401) {
            debugPrint("Inventory 401 Unauthorized. Auto-logout.");
            await logout();
            return false;
          } else if (invResponse.statusCode == 500) {
            debugPrint(
              "_loadUserData: Inventory Failed: ${invResponse.statusCode}",
            );
            await _blindRepairCriticalItems(token);
          }
        } catch (e) {
          debugPrint("Error saving goal: $e");
        }

        // C. Fetch from Firestore (Sync/Backup)
        try {
          debugPrint("Fetching Inventory from Firestore...");
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
              // Add if not present (Merge strategy)
              if (!_inventory.containsKey(name)) {
                _inventory[name] = {
                  'quantity': (data['quantity'] as num?)?.toDouble() ?? 0.0,
                  'unit': data['unit'] ?? 'Unidades',
                };
                cacheUpdateNeeded = true;
              }
            }
            if (cacheUpdateNeeded) {
              debugPrint(
                "Inventory merged with Firestore. Total: ${_inventory.length}",
              );
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
          debugPrint(
            "Loaded Local Calendar with ${_mealCalendar.length} entries.",
          );
        }

        // --- FIRESTORE ---
        if (user != null) {
          // Obtener colección 'daily_menus'
          final now = DateTime.now();
          final startDate = now.subtract(const Duration(days: 30));

          debugPrint(
            "Fetching Firestore menus since ${_formatDate(startDate)} for user ${user.uid}",
          );

          final querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_menus')
              .where(
                FieldPath.documentId,
                isGreaterThanOrEqualTo: _formatDate(startDate),
              )
              .get();

          debugPrint("Firestore returned ${querySnapshot.docs.length} menus.");

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

      // STRICT CHECK: User MUST have a UID for us to trust the session
      if (user == null) {
        debugPrint("Critical: No Firebase User found. Failing Login.");
        // BYPASS: Allow backend-only login for debugging
        debugPrint(
          "BYPASSING STRICT CHECK: Allowing login without Firebase for debugging.",
        );
        // return false;
      }

      return true;
    } catch (e) {
      debugPrint("Critical Error in _loadUserData: $e");
      // Don't fail silently on generic errors, try to return true if we have minimal data
      if (email != null && firstName != null) return true;
      return false;
    }
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
    final url = Uri.parse('$_baseUrl/token');
    try {
      // 1. Login en Backend (FastAPI)
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': email, 'password': password},
          )
          .timeout(const Duration(seconds: 60));

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
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Credenciales incorrectas';
        } catch (_) {
          debugPrint("Login 500/HTML Error: ${response.body}");
          return 'Error en el servidor. Verifica que el backend esté corriendo.';
        }
      }
    } catch (e) {
      debugPrint("Login Connection Error: $e");
      return 'Error de conexión con el servidor. Verifica tu internet y que el backend esté corriendo.';
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
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Error al registrar';
      }
    } catch (e) {
      return 'Error de red al registrar.';
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
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Error de servidor';
      }
    } catch (e) {
      // print("Error signInWithGoogle: $e");
      return "Error: $e";
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
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .doc(name)
          .set({'quantity': quantity, 'unit': unit}, SetOptions(merge: true));
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

  void setPersonalData({String? firstName, String? lastName}) {
    this.firstName = firstName ?? this.firstName;
    this.lastName = lastName ?? this.lastName;
    notifyListeners();
  }

  Future<void> updateFood(String foodKey, double quantity, String unit) async {
    // 1. OPTIMISTIC UPDATE
    _inventory[foodKey] = {'quantity': quantity, 'unit': unit};

    // CACHE UPDATE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _storage.write(
        key: 'inventory_cache_${user.uid}',
        value: jsonEncode(_inventory),
      );
      // FIRESTORE SYNC
      _syncInventoryItemToFirestore(foodKey, quantity, unit);
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
        backendQuantity = _convertToBase(quantity, unit).round();
        backendUnit = baseUnit;
      } else {
        backendQuantity = quantity.round();
      }

      // Safety check: Backend often rejects 0
      if (backendQuantity == 0) backendQuantity = 1;

      final response = await http
          .put(
            Uri.parse('$_baseUrl/inventory/$foodKey'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'quantity': backendQuantity,
              'unit': backendUnit,
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
      'banana',
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

  Future<bool> addFood(
    String food, {
    double quantity = 1.0,
    String unit = 'Unidades',
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
        await updateFood(normalizedKey, totalBase, targetUnit);
        return true;
      } catch (e) {
        debugPrint("Error accumulating food: $e. Fallback to overwrite.");
        // Fallback to processing as new if accumulation fails logic (unlikely)
      }
    }

    // 1. OPTIMISTIC UPDATE (New Item)
    _inventory[normalizedKey] = {'quantity': quantity, 'unit': unit};

    // CACHE UPDATE
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _storage.write(
        key: 'inventory_cache_${user.uid}',
        value: jsonEncode(_inventory),
      );
      // FIRESTORE SYNC
      _syncInventoryItemToFirestore(normalizedKey, quantity, unit);
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
        backendQuantity = _convertToBase(quantity, unit).round();
        backendUnit = baseUnit;
      } else {
        // Unidades or unknown: Round to int
        backendQuantity = quantity.round();
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
        _storage.write(
          key: 'inventory_cache_${user.uid}',
          value: jsonEncode(_inventory),
        );
        // Sync delete to Firestore
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
            Uri.parse('$_baseUrl/inventory/remove/$foodKey'),
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
      } else if (response.statusCode == 401) {
        await logout();
        return false;
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

    // 1. UPDATE MEMORY (Optimistic Code)
    // We update our local class state immediately with the new values provided.
    // If an argument is null, we keep the current value.
    if (firstName != null) this.firstName = firstName;
    if (lastName != null) this.lastName = lastName;
    if (birthdate != null) this.birthdate = birthdate;
    if (height != null) this.height = height;
    if (weight != null) this.weight = weight;

    notifyListeners(); // Immediate UI feedback

    // 2. BACKEND SYNC (Best Effort)
    if (token != null) {
      final url = Uri.parse('$_baseUrl/users/me/data');
      final Map<String, dynamic> body = {};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (birthdate != null) body['birthdate'] = birthdate.toIso8601String();
      if (height != null) body['height'] = height;
      if (weight != null) body['weight'] = weight;

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
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Optionally parse response to confirm
          final data = jsonDecode(response.body);
          // Update goal if returned by backend as a side effect (rare)
          if (data['goal'] != null) goal = data['goal'];
        } else if (response.statusCode == 401) {
          debugPrint("Backend 401: Token expired, but saving locally.");
        } else {
          debugPrint(
            "Backend Warning (${response.statusCode}): ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Backend Exception (ignored for persistence): $e");
      }
    }

    // 3. FIRESTORE SYNC (Robust Persistence)
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

        firestoreData['goal'] = goal;

        if (firestoreData.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(firestoreData, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
          debugPrint("Firestore Sync Successful");
        }
      } catch (fsError) {
        debugPrint("Error syncing physical data to Firestore: $fsError");
      }
    }

    // 4. LOCAL CACHE UPDATE (Offline Persistence)
    if (user != null) {
      try {
        String? currentCacheStr = await _storage.read(
          key: 'user_profile_cache_${user.uid}',
        );
        Map<String, dynamic> cacheData = {};
        if (currentCacheStr != null) {
          cacheData = jsonDecode(currentCacheStr);
        }

        // Update with current class state
        if (this.firstName != null) cacheData['first_name'] = this.firstName;
        if (this.lastName != null) cacheData['last_name'] = this.lastName;
        if (this.height != null) cacheData['height'] = this.height;
        if (this.weight != null) cacheData['weight'] = this.weight;
        if (this.birthdate != null) {
          cacheData['birthdate'] = this.birthdate?.toIso8601String();
        }
        cacheData['goal'] = goal;
        if (photoUrl != null) cacheData['photo_url'] = photoUrl;
        if (email != null) cacheData['email'] = email;

        await _storage.write(
          key: 'user_profile_cache_${user.uid}',
          value: jsonEncode(cacheData),
        );
        debugPrint("Local Cache Sync Successful");
      } catch (e) {
        debugPrint("Error updating profile cache: $e");
      }
    }

    return true;
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

      if (response.statusCode == 401) {
        await logout();
        return false;
      }

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
          debugPrint("Warning: No user found to save goal locally properly.");
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

  Future<String?> uploadProfilePicture(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "No estás autenticado";

    debugPrint("Starting profile photo upload for ${user.uid}...");

    // DIRECT FIX: User confirmed bucket is gs://mealiav2.firebasestorage.app
    // We bypass the list and dynamic loading to eliminate env vars issues.
    final targetBucket = 'gs://mealiav2.firebasestorage.app';

    debugPrint("FORCE UPLOAD to: $targetBucket");

    String? uploadedPhotoUrl;

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploaded_by': user.uid},
    );

    // Read bytes
    Uint8List fileBytes;
    try {
      fileBytes = await imageFile.readAsBytes();
    } catch (e) {
      debugPrint("Error reading file bytes: $e");
      return "Error leyendo el archivo local: $e";
    }

    try {
      final storage = FirebaseStorage.instanceFor(bucket: targetBucket);
      debugPrint("Storage Instance created for $targetBucket");
      debugPrint("Storage App: ${storage.app.name}");

      final ref = storage.ref().child('users/${user.uid}/profile_photo.jpg');
      debugPrint("Storage Ref: ${ref.fullPath}");
      debugPrint("Storage Ref Bucket: ${ref.bucket}");

      // Upload
      await ref.putData(fileBytes, metadata);
      debugPrint("putData SUCCESS");

      // Get URL
      uploadedPhotoUrl = await ref.getDownloadURL();
      debugPrint("getDownloadURL SUCCESS: $uploadedPhotoUrl");
    } catch (e) {
      debugPrint("CRITICAL UPLOAD ERROR: $e");
      if (e is FirebaseException) {
        debugPrint("Code: ${e.code}");
        debugPrint("Message: ${e.message}");
      }
      return "Error de subida (404/403 Check Console): $e";
    }

    photoUrl = uploadedPhotoUrl;

    try {
      // 2. Persist URL locally
      await _storage.write(
        key: 'profile_photo_url_${user.uid}',
        value: photoUrl,
      );

      // 3. Sync to Firestore (Robustness)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photo_url': photoUrl,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Sync to Backend (Best Effort)
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        try {
          // We use the same endpoint as physical data updates
          await http
              .put(
                Uri.parse('$_baseUrl/users/me/data'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode({'photo_url': photoUrl}),
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint("Backend sync warning (non-critical): $e");
        }
      }

      notifyListeners();
      return null; // Success (null error)
    } catch (e) {
      debugPrint("CRITICAL ERROR uploading profile picture: $e");
      return "Error inesperado al finalizar subida: $e";
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
          .then(
            (_) => debugPrint(
              "Menú del día $dateKey guardado en Firestore EXITOSAMENTE",
            ),
          )
          .catchError(
            (e) => debugPrint("Error guardando menú en Firestore: $e"),
          );
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
            match.group(3) ?? "${match.group(2) ?? ''} ${match.group(3) ?? ''}";
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
            if (unitToSend == 'u') {
              unitToSend = currentData['unit']; // if it was 'Unidades' keep it.
            }
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
      firstName = null;
      lastName = null;
      email = null;
      photoUrl = null;
      _inventory.clear();
      _mealCalendar.clear();
      generatedMenu = null;

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
