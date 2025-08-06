// Fixed LoginResponse model with proper error handling
class LoginResponse {
  final int code;
  final String msg;
  final LoginData? data;

  LoginResponse({required this.code, required this.msg, this.data});

  // Add convenience methods for checking success/error
  bool get isSuccess => code == 200 || code == 0; // Success codes
  String get errorMessage => msg.isEmpty ? 'Login failed' : msg;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    LoginData? loginData;

    // Handle different data formats from API
    final dynamic dataField = json['data'];
    if (dataField != null) {
      if (dataField is Map<String, dynamic>) {
        // Success case: data is an object
        loginData = LoginData.fromJson(dataField);
      } else if (dataField is List) {
        // Error case: data is an empty array, set to null
        loginData = null;
      }
    }

    return LoginResponse(
      code: json['code'] ?? 0,
      msg: json['msg'] ?? json['message'] ?? '',
      data: loginData,
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'msg': msg, 'data': data?.toJson()};
  }
}

class LoginData {
  final String token;
  final String? merchantId;
  final String? empno;
  final UserInfo? userInfo;
  final List<Store> storeList;

  LoginData({
    required this.token,
    this.merchantId,
    this.empno,
    this.userInfo,
    required this.storeList,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    // Generate a session token since API doesn't provide one
    final sessionToken = _generateSessionToken(
      json['merchant_id']?.toString() ?? '',
    );

    // Safely parse store list
    List<Store> storeList = [];
    final dynamic storeListData = json['store_list'];
    if (storeListData is List) {
      storeList = storeListData
          .where((item) => item is Map<String, dynamic>)
          .map((store) => Store.fromJson(store as Map<String, dynamic>))
          .where(
            (store) => store.storeId.isNotEmpty,
          ) // Filter out invalid stores
          .toList();
    }

    return LoginData(
      token: json['token']?.toString() ?? sessionToken,
      merchantId:
          json['merchant_id']?.toString() ?? json['merchantId']?.toString(),
      empno: json['empno']?.toString(),
      userInfo:
          json['user_info'] != null && json['user_info'] is Map<String, dynamic>
          ? UserInfo.fromJson(json['user_info'] as Map<String, dynamic>)
          : null,
      storeList: storeList,
    );
  }

  // Generate a session token for local use
  static String _generateSessionToken(String merchantId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_${merchantId}_$timestamp';
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'merchant_id': merchantId,
      'empno': empno,
      'user_info': userInfo?.toJson(),
      'store_list': storeList.map((store) => store.toJson()).toList(),
    };
  }
}

class UserInfo {
  final String? name;
  final String? email;
  final String? merchantId;

  UserInfo({this.name, this.email, this.merchantId});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      merchantId:
          json['merchant_id']?.toString() ?? json['merchantId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'email': email, 'merchant_id': merchantId};
  }
}

class Store {
  final String storeId;
  final String storeName;
  final String? storeAddress;
  final String? storePhone;

  Store({
    required this.storeId,
    required this.storeName,
    this.storeAddress,
    this.storePhone,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId:
          json['store_id']?.toString() ?? json['storeId']?.toString() ?? '',
      storeName:
          json['store_name']?.toString() ?? json['storeName']?.toString() ?? '',
      storeAddress:
          json['store_address']?.toString() ?? json['storeAddress']?.toString(),
      storePhone:
          json['store_phone']?.toString() ?? json['storePhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'store_address': storeAddress,
      'store_phone': storePhone,
    };
  }

  // Override equality operators to prevent dropdown conflicts
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Store && other.storeId == storeId;
  }

  @override
  int get hashCode => storeId.hashCode;

  @override
  String toString() {
    return 'Store{storeId: $storeId, storeName: $storeName}';
  }
}
