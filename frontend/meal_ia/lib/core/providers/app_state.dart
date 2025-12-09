import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NECESARIO PARA AUTH
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    // Verificación Doble: Si no hay token local O no hay usuario en Firebase,
    // forzamos al usuario a loguearse de nuevo para reparar la sesión.
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (token == null || firebaseUser == null) {
      return false;
    }
    return await _loadUserData(token);
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut(); // Logout de Firebase
    await _storage.delete(key: 'auth_token');

    // Limpiar variables en memoria
    firstName = null;
    lastName = null;
    birthdate = null;
    height = null;
    weight = null;
    goal = 'Mantenimiento';
    photoUrl = null;
    _inventory.clear();
    generatedMenu = null;
    totalCalories = 0;
    notifyListeners();
  }

  Future<bool> _loadUserData(String token) async {
    try {
      // 1. Cargar Perfil
      final userResponse = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (userResponse.statusCode != 200) return false;

      final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));

      firstName = userData['first_name'];
      lastName = userData['last_name'];
      height = userData['height'];
      weight = userData['weight'];
      birthdate = userData['birthdate'] != null
          ? DateTime.parse(userData['birthdate'])
          : null;
      goal = userData['goal'];
      photoUrl = userData['photo_url'];

      // 2. Cargar Inventario
      final invResponse = await http.get(
        Uri.parse('$_baseUrl/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (invResponse.statusCode != 200) return false;

      final List<dynamic> invData = jsonDecode(
        utf8.decode(invResponse.bodyBytes),
      );
      _inventory.clear();

      for (var item in invData) {
        _inventory[item['name']] = {
          'quantity': (item['quantity'] ?? 0).toDouble(),
          'unit': item['unit'] ?? 'Unidades',
        };
      }
      notifyListeners();
      return true;
    } catch (e) {
      // print("Error en _loadUserData: $e");
      return false;
    }
  }

  // --- LOGIN CON AUTO-REPARACIÓN DE FIREBASE ---
  Future<String> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/token');
    try {
      // 1. Login en Backend (FastAPI)
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await _storage.write(key: 'auth_token', value: token);

        // 2. LOGIN / CREACIÓN EN FIREBASE (Sincronización)
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          // print("Firebase: Login sincronizado correctamente.");
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            // print("Firebase: Usuario no encontrado. Creándolo para sincronizar...");
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
              // print("Firebase: Usuario creado y sincronizado.");
            } catch (createError) {
              // print("Error creando en Firebase: $createError");
            }
          } else {
            // print("Firebase Error (Login): ${e.code}");
          }
        }

        // 3. Cargar datos finales
        final success = await _loadUserData(token);
        return success ? "OK" : "Error al cargar tus datos";
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Credenciales incorrectas';
      }
    } catch (e) {
      return 'Error de conexión. Intenta más tarde.';
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'first_name': firstName,
          'password': password,
        }),
      );

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

      // Sincronizar Firebase con Google Credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (googleToken == null) return "Error al obtener token de Google";

      final url = Uri.parse('$_baseUrl/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final appToken = data['access_token'];
        final bool isNewUser = data['is_new_user'] ?? false;

        await _storage.write(key: 'auth_token', value: appToken);
        final success = await _loadUserData(appToken);

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
      await http.put(
        Uri.parse('$_baseUrl/inventory/$foodKey'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'quantity': quantity, 'unit': unit}),
      );
    } catch (e) {
      // print("Error actualizando comida: $e");
    }
  }

  Future<void> addFood(String food) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    String normalizedKey = food.trim().toLowerCase();
    if (normalizedKey.isEmpty) return;
    try {
      final response = await http.post(
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
      );
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
      final response = await http.delete(
        Uri.parse('$_baseUrl/inventory/remove/$foodKey'),
        headers: {'Authorization': 'Bearer $token'},
      );
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
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        generatedMenu = {
          'breakfast': data['breakfast'],
          'lunch': data['lunch'],
          'dinner': data['dinner'],
          'note': data['note'] ?? 'Menú generado por IA.',
        };
        totalCalories = data['total_calories'] ?? 0;
        notifyListeners();
        return true;
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
    if (birthdate != null) body['birthdate'] = birthdate.toIso8601String();
    if (height != null) body['height'] = height;
    if (weight != null) body['weight'] = weight;
    try {
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
        this.height = data['height'];
        this.weight = data['weight'];
        this.birthdate = data['birthdate'] != null
            ? DateTime.parse(data['birthdate'])
            : null;
        goal = data['goal'];
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveUserGoal(String goal) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/users/me/data');
    try {
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
}
