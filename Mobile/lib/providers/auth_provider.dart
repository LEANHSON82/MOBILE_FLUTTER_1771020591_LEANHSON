import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String username, String password) async {
    try {
      print('Attempting login with username: $username');
      print('API Base URL: ${_apiService.dio.options.baseUrl}');
      
      final response = await _apiService.dio.post(
        'auth/login',
        data: {'username': username, 'password': password},
      );

      print('Login response status: ${response.statusCode}');
      print('Login response data: ${response.data}');

      final token = response.data['token'];
      await _storage.write(key: 'jwt_token', value: token);
      
      // Handle null user (admin case)
      final userData = response.data['user'];
      final roles = response.data['roles'] as List<dynamic>?;
      
      if (userData != null) {
        if (roles != null) userData['roles'] = roles;
        _user = User.fromJson(userData);
      } else {
        // Create a basic user for admin/users without Member record
        _user = User(
          id: 0,
          fullName: username,
          walletBalance: 0,
          userId: '',
          avatarUrl: null,
          roles: roles?.map((e) => e.toString()).toList() ?? [],
        );
      }
      
      // Store roles for later use
      if (roles != null && roles.isNotEmpty) {
        await _storage.write(key: 'user_roles', value: roles.join(','));
      }
      
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      print('Login error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final response = await _apiService.dio.get('auth/me');
        final userData = response.data['user'];
        final roles = response.data['roles'];
        
        if (userData != null) {
          if (roles != null) userData['roles'] = roles;
          _user = User.fromJson(userData);
        } else if (roles != null && (roles as List).contains('Admin')) {
           // Case for Admin with no Member record
           _user = User(id:0, fullName: 'Admin', walletBalance: 0, userId: '', roles: (roles as List).map((e)=>e.toString()).toList());
        }
        
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }
}
