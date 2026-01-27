import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    String baseUrl;
    if (kIsWeb) {
      baseUrl = 'http://localhost:5220/api/'; // Web (HTTP)
    } else if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:5220/api/'; // Android Emulator (HTTP)
    } else {
      baseUrl = 'http://127.0.0.1:5220/api/'; // iOS/Desktop (HTTP) - use IP instead of localhost
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Ignore SSL errors for development (Only for Mobile/Desktop, NOT Web)
    if (!kIsWeb) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Handle 401 Unauthorized
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
