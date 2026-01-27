import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb

class SignalRService with ChangeNotifier {
  late HubConnection _hubConnection;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String get _serverUrl {
    if (kIsWeb) return 'http://localhost:5220/pcmHub';
    if (Platform.isAndroid) return 'http://10.0.2.2:5220/pcmHub';
    return 'http://localhost:5220/pcmHub';
  }

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> initSignalR() async {
    final token = await _storage.read(key: 'jwt_token');

    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: () async => token ?? '',
    );

    // Only set httpClient for non-web platforms
    if (!kIsWeb) {
      // httpOptions.httpClient = _createHttpClient(); // Property 'httpClient' might be final or named differently depending on version
      // In latest signalr_netcore, it's passed in constructor or settable.
      // Let's use the named parameter approach which is cleaner if supported, 
      // OR reconstruct options.
      // Since we can't easily modify the object properties if they are final, let's create options conditionally.
    }
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          _serverUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
            httpClient: kIsWeb ? null : _createHttpClient(), // Web doesn't need custom HttpClient
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection.onclose(({error}) {
      _isConnected = false;
      notifyListeners();
      // print('SignalR Connection Closed: $error');
    });

    _hubConnection.onreconnected(({connectionId}) {
      _isConnected = true;
      notifyListeners();
      // print('SignalR Reconnected');
    });

    try {
      await _hubConnection.start();
      _isConnected = true;
      notifyListeners();
      // print('SignalR Connected');
    } catch (e) {
      // print('SignalR Connection Error: $e');
    }
  }

  void on(String methodName, void Function(List<Object?>?) handler) {
    _hubConnection.on(methodName, handler);
  }

  // Helper to ignore SSL
  static WebSupportingHttpClient _createHttpClient() {
    return WebSupportingHttpClient(
      null,
      httpClientCreateCallback: (dynamic httpClient) {
        if (httpClient is HttpClient) {
          httpClient.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        }
      },
    );
  }
}
