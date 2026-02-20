import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../remote/api_client.dart';

/// 认证仓库的具体实现
class AuthRepositoryImpl implements IAuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required FlutterSecureStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  @override
  Future<String> login(String phone, String code) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'phone': phone,
          'code': code,
        },
      );

      final data = response.data;
      if (data != null && data['access_token'] != null) {
        final token = data['access_token'] as String;
        // 成功获取 token 后，写入安全存储
        await _storage.write(key: 'jwt_token', value: token);
        return token;
      } else {
        throw ApiException('服务器响应异常：缺少 access_token');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final detail = e.response?.data['detail'];
        final errMessage = detail is String ? detail : '登录验证失败';
        throw ApiException(errMessage, e.response?.statusCode);
      } else {
        throw ApiException('网络连接超时或不可达');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('发生了未知的错误: $e');
    }
  }
}
