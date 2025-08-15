import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';
import '../utils/constants.dart';

class StorageService {
  static SharedPreferences? _prefs;

  // Initialize shared preferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Ensure preferences are initialized
  static Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // Save login data after successful authentication
  static Future<void> saveLoginData(
    LoginResponse loginResponse, {
    required String username,
    required String merchantId,
    String? password,
    bool rememberCredentials = false,
  }) async {
    final prefs = await _preferences;

    try {
      // Save login response
      final loginJson = json.encode(loginResponse.toJson());
      await prefs.setString(Constants.loginResponseKey, loginJson);

      // Save session timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(Constants.sessionTimestampKey, timestamp);

      // Save username and merchant ID
      await prefs.setString(Constants.usernameKey, username);
      await prefs.setString(Constants.merchantIdKey, merchantId);

      // Save credentials if remember me is enabled
      await prefs.setBool(Constants.rememberMeKey, rememberCredentials);
      if (rememberCredentials && password != null) {
        await prefs.setString(Constants.passwordKey, password);
      } else {
        await prefs.remove(Constants.passwordKey);
      }

      print('✅ Login data saved successfully');
    } catch (e) {
      print('❌ Error saving login data: $e');
      throw Exception('Failed to save login data');
    }
  }

  // Get stored login response
  static Future<LoginResponse?> getLoginResponse() async {
    final prefs = await _preferences;

    try {
      final loginJson = prefs.getString(Constants.loginResponseKey);
      if (loginJson != null) {
        final Map<String, dynamic> loginMap = json.decode(loginJson);
        return LoginResponse.fromJson(loginMap);
      }
      return null;
    } catch (e) {
      print('❌ Error retrieving login response: $e');
      return null;
    }
  }

  // Check if user is currently logged in and session is valid
  static Future<bool> isLoggedIn() async {
    final prefs = await _preferences;

    try {
      final loginResponse = await getLoginResponse();
      if (loginResponse == null || !loginResponse.isSuccess) {
        return false;
      }

      // Check session timeout
      final timestamp = prefs.getInt(Constants.sessionTimestampKey);
      if (timestamp == null) {
        return false;
      }

      final sessionTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(sessionTime);

      if (difference > Constants.sessionTimeout) {
        print('⏰ Session expired');
        await logout(); // Clear expired session
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Get authentication token
  static Future<String?> getToken() async {
    try {
      final loginResponse = await getLoginResponse();
      return loginResponse?.data?.token;
    } catch (e) {
      print('❌ Error retrieving token: $e');
      return null;
    }
  }

  // Get saved username
  static Future<String?> getSavedUsername() async {
    final prefs = await _preferences;
    return prefs.getString(Constants.usernameKey);
  }

  // Get saved merchant ID
  static Future<String?> getSavedMerchantId() async {
    final prefs = await _preferences;
    return prefs.getString(Constants.merchantIdKey);
  }

  // Get saved password (only if remember me is enabled)
  static Future<String?> getSavedPassword() async {
    final prefs = await _preferences;
    final rememberMe = prefs.getBool(Constants.rememberMeKey) ?? false;
    if (rememberMe) {
      return prefs.getString(Constants.passwordKey);
    }
    return null;
  }

  // Check if credentials are remembered
  static Future<bool> hasRememberedCredentials() async {
    final prefs = await _preferences;
    final rememberMe = prefs.getBool(Constants.rememberMeKey) ?? false;
    final username = prefs.getString(Constants.usernameKey);
    final merchantId = prefs.getString(Constants.merchantIdKey);
    final password = prefs.getString(Constants.passwordKey);

    return rememberMe &&
        username != null &&
        merchantId != null &&
        password != null;
  }

  // Update session timestamp (for session extension)
  static Future<void> updateSessionTimestamp() async {
    final prefs = await _preferences;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(Constants.sessionTimestampKey, timestamp);
  }

  // Save selected store
  static Future<void> saveSelectedStore(Store store) async {
    final prefs = await _preferences;
    try {
      final storeJson = json.encode(store.toJson());
      await prefs.setString(Constants.selectedStoreKey, storeJson);
      print('✅ Selected store saved: ${store.storeName}');
    } catch (e) {
      print('❌ Error saving selected store: $e');
    }
  }

  // Get selected store
  static Future<Store?> getSelectedStore() async {
    final prefs = await _preferences;
    try {
      final storeJson = prefs.getString(Constants.selectedStoreKey);
      if (storeJson != null) {
        final Map<String, dynamic> storeMap = json.decode(storeJson);
        return Store.fromJson(storeMap);
      }
      return null;
    } catch (e) {
      print('❌ Error retrieving selected store: $e');
      return null;
    }
  }

  // Get user stores list
  static Future<List<Store>> getUserStores() async {
    try {
      final loginResponse = await getLoginResponse();
      return loginResponse?.data?.storeList ?? [];
    } catch (e) {
      print('❌ Error retrieving user stores: $e');
      return [];
    }
  }

  // Get current user info
  static Future<UserInfo?> getUserInfo() async {
    try {
      final loginResponse = await getLoginResponse();
      return loginResponse?.data?.userInfo;
    } catch (e) {
      print('❌ Error retrieving user info: $e');
      return null;
    }
  }

  // Clear all stored data (logout)
  static Future<void> logout() async {
    final prefs = await _preferences;

    try {
      // Clear session data
      await prefs.remove(Constants.loginResponseKey);
      await prefs.remove(Constants.sessionTimestampKey);
      await prefs.remove(Constants.selectedStoreKey);

      // Clear credentials if not remembered
      final rememberMe = prefs.getBool(Constants.rememberMeKey) ?? false;
      if (!rememberMe) {
        await prefs.remove(Constants.usernameKey);
        await prefs.remove(Constants.merchantIdKey);
        await prefs.remove(Constants.passwordKey);
        await prefs.remove(Constants.rememberMeKey);
      }

      print('✅ Logout completed');
    } catch (e) {
      print('❌ Error during logout: $e');
      throw Exception('Failed to logout');
    }
  }

  // Clear all data including remembered credentials
  static Future<void> clearAllData() async {
    final prefs = await _preferences;

    try {
      await prefs.clear();
      print('✅ All data cleared');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      throw Exception('Failed to clear data');
    }
  }

  // Check if this is first app launch
  static Future<bool> isFirstLaunch() async {
    final prefs = await _preferences;
    const key = 'first_launch';
    final isFirst = prefs.getBool(key) ?? true;

    if (isFirst) {
      await prefs.setBool(key, false);
    }

    return isFirst;
  }
}
