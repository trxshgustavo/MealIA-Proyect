import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppState extends ChangeNotifier {
  // OJO: Asegúrate de que esta IP sea la correcta de tu PC
  final String _baseUrl = "http://10.136.180.35:8000"; 
  
  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: "970236848335-m9t5mjq1i9dbsacop9i49ve6k0eoc529.apps.googleusercontent.com",
  );

  String? firstName;
  String? lastName;
  DateTime? birthdate;
  double? height;
  double? weight;
  String goal = 'Mantenimiento';
  String? photoUrl;

  // --- CORRECCIÓN PRINCIPAL DE TIPO ---
  // Antes era Map<String, int>, ahora es complejo para guardar unidades
  Map<String, Map<String, dynamic>> _inventory = {};
  Map<String, Map<String, dynamic>> get inventoryMap => _inventory;
  
  Map<String, dynamic>? generatedMenu;
  int totalCalories = 0;

  Future<bool> checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      return false;
    }
    return await _loadUserData(token);
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _storage.delete(key: 'auth_token');
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
      // 1. Cargar Usuario
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
      birthdate = userData['birthdate'] != null ? DateTime.parse(userData['birthdate']) : null;
      goal = userData['goal'];
      photoUrl = userData['photo_url']; 

      // 2. Cargar Inventario
      final invResponse = await http.get(
        Uri.parse('$_baseUrl/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (invResponse.statusCode != 200) return false;

      final List<dynamic> invData = jsonDecode(utf8.decode(invResponse.bodyBytes));
      _inventory.clear();
      
      // --- CORRECCIÓN DE PARSEO ---
      for (var item in invData) {
        _inventory[item['name']] = {
          'quantity': (item['quantity'] ?? 0).toDouble(), // Forzamos double
          'unit': item['unit'] ?? 'Unidades',             // Leemos la unidad o por defecto 'Unidades'
        };
      }
      notifyListeners();
      return true;
    } catch (e) {
      print("Error en _loadUserData: $e");
      return false;
    }
  }

  Future<String> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await _storage.write(key: 'auth_token', value: token);
        final success = await _loadUserData(token);
        return success ? "OK" : "Error al cargar tus datos";
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Error desconocido';
      }
    } catch (e) {
      return 'Error de red. ¿Está el servidor corriendo?';
    }
  }

  // --- MÉTODO NUEVO: ACTUALIZAR ALIMENTO (Requerido por InventoryScreen) ---
  Future<void> updateFood(String foodKey, double quantity, String unit) async {
    // 1. Actualización Local (Optimista)
    _inventory[foodKey] = {
      'quantity': quantity,
      'unit': unit,
    };
    notifyListeners();

    // 2. Actualización en Servidor
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/inventory/$foodKey'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'quantity': quantity,
          'unit': unit
        }),
      );

      if (response.statusCode != 200) {
        print("Error al guardar cambios en servidor: ${response.statusCode}");
      }
    } catch (e) {
      print("Error de red al actualizar comida: $e");
    }
  }

  Future<void> addFood(String food) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    String normalizedKey = food.trim().toLowerCase();
    if (normalizedKey.isEmpty) return;
    try {
      // Al crear, enviamos valores por defecto
      final response = await http.post(
        Uri.parse('$_baseUrl/inventory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': normalizedKey, 
          'quantity': 1.0, 
          'unit': 'Unidades'
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _inventory[normalizedKey] = {
          'quantity': (data['quantity'] ?? 1).toDouble(),
          'unit': data['unit'] ?? 'Unidades' 
        };
        notifyListeners();
      }
    } catch (e) {
      print("Error al añadir comida (red): $e");
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
      print("Error al remover comida (red): $e");
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
          'note': data['note'] ?? 'Menú generado por IA.'
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

  // --- OTROS MÉTODOS EXISTENTES (Google, Fotos, Recetas) ---

  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Inicio de sesión cancelado";
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? googleToken = googleAuth.idToken;
      if (googleToken == null) return "Error al obtener el token de Google";

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
        if (!success) return "Error al cargar tus datos";
        return isNewUser ? "OK_NEW" : "OK_EXISTING";
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Error de servidor';
      }
    } catch (e) {
      print("Error en signInWithGoogle: $e");
      return "Error: $e";
    }
  }

  Future<String> register({
    required String email,
    required String password,
    required String firstName,
  }) async {
    final url = Uri.parse('$_baseUrl/register');
    try {
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
        return await login(email, password);
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Error desconocido';
      }
    } catch (e) {
      return 'Error de red al registrar.';
    }
  }

  void setPersonalData({String? firstName, String? lastName}) {
    this.firstName = firstName ?? this.firstName;
    this.lastName = lastName ?? this.lastName;
    notifyListeners();
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
        this.birthdate = data['birthdate'] != null ? DateTime.parse(data['birthdate']) : null;
        this.goal = data['goal'];
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
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
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