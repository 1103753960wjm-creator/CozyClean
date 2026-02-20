import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 基础网络客户端封装
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // 默认使用安卓模拟器访问本地后端的地址
  // 如果在真机上测试，请替换为真实局域网 IP (例如 'http://192.168.1.100:8000/api/v1')
  static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';

  ApiClient({
    required FlutterSecureStorage storage,
    Dio? dioOverride,
  })  : _storage = storage,
        _dio = dioOverride ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            )) {
    // 注入鉴权拦截器
    _dio.interceptors.add(_authInterceptor());
    // 可选：添加日志拦截器便于开发调试
    _dio.interceptors
        .add(LogInterceptor(responseBody: true, requestBody: true));
  }

  /// 鉴权拦截器：在发起请求前读取 jwt_token，并自动注入到 Header 中
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          // 读取本地存储 token 失败时的安全降级处理
        }
        return handler.next(options);
      },
    );
  }

  Dio get dio => _dio;
}

/// 自定义 API 异常封装类
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (StatusCode: $statusCode)';
}
