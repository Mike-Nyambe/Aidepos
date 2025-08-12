class Constants {
  // API Configuration
  static const String baseUrl = 'http://merckan.com';

  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration readTimeout = Duration(seconds: 30);

  // Error messages
  static const String timeoutError =
      'Connection timeout. Please check your internet connection and try again.';
  static const String networkError =
      'Network error. Please check your internet connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String invalidCredentialsError =
      'Invalid credentials. Please check your login details.';
  static const String merchantNotFoundError =
      'Merchant not found. Please check your Merchant ID.';
  static const String accountDisabledError =
      'Account is disabled. Please contact support.';
  static const String unexpectedError =
      'An unexpected error occurred. Please try again.';

  // App Configuration
  static const String appName = 'AIDEPOS';
  static const String appVersion = '1.0.0';

  // Session management
  static const Duration sessionTimeout = Duration(hours: 8);
  static const String sessionKey = 'aidepos_session';

  // Storage keys
  static const String loginResponseKey = 'login_response';
  static const String usernameKey = 'username';
  static const String passwordKey = 'password';
  static const String merchantIdKey = 'merchant_id';
  static const String rememberMeKey = 'remember_me';
  static const String sessionTimestampKey = 'session_timestamp';
  static const String selectedStoreKey = 'selected_store';

  // API Endpoints
  static const String loginEndpoint = '/Openapi/Login/login';
  static const String logoutEndpoint = '/Openapi/Auth/logout';
  static const String validateEndpoint = '/Openapi/Auth/validate';
  static const String healthEndpoint = '/health';

  // UI Constants
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const int primaryColorValue = 0xFFFF6B35;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int maxUsernameLength = 100;
  static const int maxMerchantIdLength = 20;

  // Build API URL with merchant ID
  static String buildLoginUrl(
    String merchantId,
    String username,
    String password,
  ) {
    return '$baseUrl$loginEndpoint?merchant_id=$merchantId&username=$username&password=$password';
  }

  // Build full API URL
  static String buildApiUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
