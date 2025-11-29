import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppState extends ChangeNotifier {
  final String _baseUrl = "http://192.168.1.36:8000";
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
  String? photoUrl; // Variable para la foto

  Map<String, int> _inventory = {};
  Map<String, int> get inventoryMap => _inventory;
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
    photoUrl = null; // Limpiamos la foto al salir
    _inventory.clear();
    generatedMenu = null;
    totalCalories = 0;
    notifyListeners();
  }

  Future<bool> _loadUserData(String token) async {
    try {
      final userResponse = await http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (userResponse.statusCode != 200) return false;

      print("DEBUG RESPUESTA SERVIDOR: ${userResponse.body}");

      final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));
      
      firstName = userData['first_name'];
      lastName = userData['last_name'];
      height = userData['height'];
      weight = userData['weight'];
      birthdate = userData['birthdate'] != null ? DateTime.parse(userData['birthdate']) : null;
      goal = userData['goal'];
      
      // --- ¡ESTA ES LA LÍNEA QUE FALTABA! ---
      photoUrl = userData['photo_url']; 
      print("DEBUG FOTO URL GUARDADA: $photoUrl");
      // ---------------------------------------

      final invResponse = await http.get(
        Uri.parse('$_baseUrl/inventory'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (invResponse.statusCode != 200) return false;

      final List<dynamic> invData = jsonDecode(utf8.decode(invResponse.bodyBytes));
      _inventory.clear();
      for (var item in invData) {
        _inventory[item['name']] = item['quantity'];
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

  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return "Inicio de sesión cancelado";
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? googleToken = googleAuth.idToken;
      if (googleToken == null) {
        return "Error al obtener el token de Google";
      }
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
        if (!success) {
          return "Error al cargar tus datos";
        }
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

  void setPersonalData({
    String? firstName,
    String? lastName,
  }) {
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
        body: jsonEncode({'name': normalizedKey}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _inventory[normalizedKey] = data['quantity'];
        notifyListeners();
      }
    } catch (e) {
      print("Error al añadir comida (red): $e");
    }
  }
  Future<void> incrementFoodQuantity(String foodKey) async {
    await addFood(foodKey);
  }
  Future<void> decrementFoodQuantity(String foodKey) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/inventory/decrement/$foodKey'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (_inventory.containsKey(foodKey)) {
          if (_inventory[foodKey]! > 1) {
            _inventory[foodKey] = _inventory[foodKey]! - 1;
          } else {
            _inventory.remove(foodKey);
          }
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error al decrementar comida (red): $e");
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

  Future<bool> uploadProfilePicture(File imageFile) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    final url = Uri.parse('$_baseUrl/users/me/upload-photo'); 

    try {
      var request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        
        photoUrl = data['photo_url'];
        notifyListeners();
        return true;
      } else {
        print('Error al subir la foto: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print("Error en uploadProfilePicture: $e");
      return false;
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

  // --- ¡PEGA ESTA FUNCIÓN EN TU APPSTATE! ---

  Future<bool> saveRecipeToFavorites(Map<String, dynamic> recipeData) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    // Asegúrate de que este endpoint coincida con tu main.py
    final url = Uri.parse('$_baseUrl/save-recipe');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          // Mapeamos los datos para que coincidan con el esquema de Python
          'name': recipeData['name'],
          'ingredients': recipeData['ingredients'],
          'steps': recipeData['steps'],
          'calories': recipeData['calories'],
        }),
      );

      if (response.statusCode == 200) {
        print("Receta guardada con éxito");
        return true;
      } else {
        print("Error del servidor al guardar receta: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de red en saveRecipeToFavorites: $e");
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
      print("Error borrando foto: $e");
      return false;
    }
  }
}