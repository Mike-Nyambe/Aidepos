import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/login_response.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

class AuthService {
  // Login with credentials (now with dynamic merchant ID)
  Future<LoginResponse> login(
    String merchantId,
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    print('🔐 Starting login process...');
    print('📧 Username: $username');
    print('🏪 Merchant ID: $merchantId');

    try {
      // Construct the URL with dynamic merchant ID
      final url = Uri.parse(
        Constants.buildLoginUrl(merchantId, username, password),
      );

      print('🌐 API URL: $url');

      // Make the GET request
      final response = await http
          .get(url)
          .timeout(
            Constants.connectionTimeout,
            onTimeout: () {
              throw Exception(Constants.timeoutError);
            },
          );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final loginResponse = LoginResponse.fromJson(jsonData);

        if (loginResponse.isSuccess) {
          print('✅ Login successful!');
          print(
            '🏪 Stores found: ${loginResponse.data?.storeList.length ?? 0}',
          );
          print(
            '🔑 Token received: ${loginResponse.data?.token.isNotEmpty ?? false}',
          );

          // Save login data for persistence (with dynamic merchant ID)
          await StorageService.saveLoginData(
            loginResponse,
            username: username,
            merchantId: merchantId, // Save the dynamic merchant ID
            password: rememberMe ? password : null,
            rememberCredentials: rememberMe,
          );

          return loginResponse;
        } else {
          print('❌ Login failed: ${loginResponse.errorMessage}');

          // Handle specific error codes
          String errorMessage = _getErrorMessage(
            loginResponse.code,
            loginResponse.errorMessage,
          );
          throw Exception(errorMessage);
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');

        // Handle specific HTTP status codes
        String errorMessage;
        switch (response.statusCode) {
          case 401:
            errorMessage = Constants.invalidCredentialsError;
            break;
          case 404:
            errorMessage = Constants.merchantNotFoundError;
            break;
          case 500:
            errorMessage = Constants.serverError;
            break;
          default:
            errorMessage =
                'HTTP Error ${response.statusCode}: ${Constants.serverError}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Exception occurred: $e');

      if (e.toString().contains('timeout')) {
        throw Exception(Constants.timeoutError);
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw Exception(Constants.networkError);
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Invalid response format from server');
      } else {
        // Re-throw the original exception if it's already a user-friendly message
        rethrow;
      }
    }
  }

  // Get user-friendly error message based on error code
  String _getErrorMessage(int code, String originalMessage) {
    switch (code) {
      case 102:
        return 'Incorrect password. Please try again.';
      case 101:
        return 'Username not found. Please check your username.';
      case 103:
        return Constants.accountDisabledError;
      case 104:
        return Constants.merchantNotFoundError;
      case 105:
        return 'Invalid merchant ID format.';
      case 106:
        return 'Account locked. Please contact support.';
      case 107:
        return 'Session expired. Please login again.';
      default:
        return originalMessage.isNotEmpty
            ? originalMessage
            : Constants.unexpectedError;
    }
  }

  // Auto-login using stored credentials
  Future<LoginResponse?> autoLogin() async {
    try {
      print('🔄 Attempting auto-login...');

      // Check if user is logged in and session is valid
      final isLoggedIn = await StorageService.isLoggedIn();
      if (!isLoggedIn) {
        print('❌ No valid session found');
        return null;
      }

      // Try to get stored login response first
      final storedResponse = await StorageService.getLoginResponse();
      if (storedResponse != null &&
          storedResponse.data?.token.isNotEmpty == true) {
        print('✅ Using stored login response');

        // Update the session timestamp and return the stored response
        await StorageService.updateSessionTimestamp();
        return storedResponse;
      }

      // If stored response is invalid, try login with saved credentials
      final hasCredentials = await StorageService.hasRememberedCredentials();
      if (hasCredentials) {
        final username = await StorageService.getSavedUsername();
        final merchantId = await StorageService.getSavedMerchantId();
        final password = await StorageService.getSavedPassword();

        if (username != null && merchantId != null && password != null) {
          print('🔑 Logging in with saved credentials');
          return await login(merchantId, username, password, rememberMe: true);
        }
      }

      print('❌ No valid credentials for auto-login');
      return null;
    } catch (e) {
      print('❌ Auto-login failed: $e');
      return null;
    }
  }

  // Validate token with server
  Future<bool> validateToken(String token) async {
    try {
      print('🔍 Validating token...');

      // Since the API doesn't have a token validation endpoint,
      // we'll validate by checking if we can make a simple API call
      // You can replace this with your actual validation endpoint if available

      // For now, we'll skip server validation and rely on local session management
      // If your API has a validation endpoint, uncomment and modify the code below:

      /*
      final url = Uri.parse(Constants.buildApiUrl(Constants.validateEndpoint));
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Constants.connectionTimeout);

      print('🔍 Token validation status: ${response.statusCode}');
      return response.statusCode == 200;
      */

      // For now, return true if token exists and is not empty
      final isValid = token.isNotEmpty;
      print('🔍 Token validation result: $isValid');
      return isValid;
    } catch (e) {
      print('🔍 Token validation failed: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      print('🚪 Logging out...');

      // Optionally notify server about logout
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        await _notifyServerLogout(token);
      }

      // Clear local storage
      await StorageService.logout();
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Still clear local storage even if server notification fails
      await StorageService.logout();
    }
  }

  // Notify server about logout (optional)
  Future<void> _notifyServerLogout(String token) async {
    try {
      final url = Uri.parse(Constants.buildApiUrl(Constants.logoutEndpoint));
      await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Server logout notification failed: $e');
    }
  }

  // Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }

  // Get current login data
  Future<LoginResponse?> getCurrentLoginData() async {
    return await StorageService.getLoginResponse();
  }

  // Get current user stores
  Future<List<Store>> getUserStores() async {
    return await StorageService.getUserStores();
  }

  // Get current user info
  Future<UserInfo?> getUserInfo() async {
    return await StorageService.getUserInfo();
  }

  // Save selected store
  Future<void> saveSelectedStore(Store store) async {
    await StorageService.saveSelectedStore(store);
  }

  // Get selected store
  Future<Store?> getSelectedStore() async {
    return await StorageService.getSelectedStore();
  }

  // Method to test API connectivity
  Future<bool> testConnection() async {
    try {
      print('🔍 Testing API connection...');
      final response = await http
          .get(Uri.parse(Constants.buildApiUrl(Constants.healthEndpoint)))
          .timeout(const Duration(seconds: 10));

      print('🔍 Health check status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('🔍 Connection test failed: $e');
      return false;
    }
  }

  // Quick login method for testing (development only)
  Future<LoginResponse?> quickLogin({
    String? merchantId,
    String? username,
    String? password,
  }) async {
    try {
      // Use provided credentials or get from storage
      final testMerchantId =
          merchantId ?? await StorageService.getSavedMerchantId() ?? 'R00271';
      final testUsername =
          username ??
          await StorageService.getSavedUsername() ??
          'test@example.com';
      final testPassword = password ?? 'test123';

      print('🧪 Quick login attempt with:');
      print('🏪 Merchant ID: $testMerchantId');
      print('📧 Username: $testUsername');

      return await login(testMerchantId, testUsername, testPassword);
    } catch (e) {
      print('🧪 Quick login failed: $e');
      return null;
    }
  }
}
