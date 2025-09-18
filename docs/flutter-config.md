# Flutter Configuration for DriMain Integration

This document describes how to configure the Flutter frontend to connect with the DriMain Spring Boot backend.

## API Base URL Configuration

The Flutter app uses the `API_BASE` environment variable to determine where to connect to the backend API.

### Development Scenarios

#### 1. Web Development (Browser)
When developing Flutter web and running the Spring Boot backend locally:

```bash
cd frontend
flutter run -d web --dart-define=API_BASE=http://localhost:8080
```

#### 2. Android Emulator
When running Flutter on Android emulator and Spring Boot backend on host machine:

```bash
cd frontend
flutter run -d android --dart-define=API_BASE=http://10.0.2.2:8080
```

**Note:** `10.0.2.2` is the special IP address that maps to the host machine's `127.0.0.1` from within the Android emulator.

#### 3. iOS Simulator
When running Flutter on iOS simulator:

```bash
cd frontend
flutter run -d ios --dart-define=API_BASE=http://localhost:8080
```

#### 4. Physical Device
When testing on a physical device, use your computer's IP address:

```bash
cd frontend
flutter run -d device --dart-define=API_BASE=http://192.168.1.100:8080
```

Replace `192.168.1.100` with your actual IP address.

## Code Integration

### Reading API_BASE in Flutter

In your Flutter code, access the API base URL like this:

```dart
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');

class ApiService {
  static const String baseUrl = apiBase;
  
  // Your API calls here
}
```

### HTTP Client Setup

Example HTTP client setup with proper headers:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  static const String baseUrl = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080');
  
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login');
    }
  }
  
  Future<Map<String, dynamic>> getWithAuth(String endpoint, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }
}
```

## Token Storage

### Using SharedPreferences

Store JWT tokens securely using SharedPreferences:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'jwt_token';
  
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
```

## CORS Considerations

The backend is already configured to accept requests from common Flutter development ports:
- `http://localhost:3000` (Flutter web dev server)
- `http://10.0.2.2:8080` (Android emulator)
- Various other localhost ports

If you encounter CORS issues, check that your origin is included in the `CorsConfig.java` file.

## Production Configuration

For production builds, set the API_BASE to your production server:

```bash
flutter build web --dart-define=API_BASE=https://your-production-server.com
flutter build apk --dart-define=API_BASE=https://your-production-server.com
```

## Troubleshooting

### Common Issues

1. **Connection Refused**: Make sure the Spring Boot backend is running on the expected port
2. **CORS Errors**: Verify the origin is allowed in backend CORS configuration  
3. **401 Unauthorized**: Check that JWT token is being sent correctly in Authorization header
4. **Network Errors on Emulator**: Ensure you're using `10.0.2.2` instead of `localhost` for Android emulator

### Testing Backend Connectivity

Test if the backend is accessible from your development environment:

```bash
# From command line
curl http://localhost:8080/actuator/health

# From Android emulator (using adb shell)
adb shell
curl http://10.0.2.2:8080/actuator/health
```

## Default Test Accounts

Use these accounts for testing:

- **Admin**: username=`admin`, password=`admin123`
- **User**: username=`user`, password=`user123`