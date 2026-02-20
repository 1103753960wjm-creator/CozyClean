import 'package:dio/dio.dart';
import '../../domain/repositories/i_sync_repository.dart';
import '../remote/api_client.dart';

/// 同步仓库的具体实现
class SyncRepositoryImpl implements ISyncRepository {
  final ApiClient _apiClient;

  SyncRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<int> uploadSession(
      String sessionId, int mode, List<Map<String, dynamic>> actions) async {
    try {
      // 组装 JSON 格式的 POST 请求
      final response = await _apiClient.dio.post(
        '/sync/upload',
        data: {
          'session_id': sessionId,
          'mode': mode,
          'actions': actions,
        },
      );

      final data = response.data;
      if (data != null && data['synced_count'] != null) {
        return data['synced_count'] as int;
      } else {
        throw ApiException('服务器响应异常：缺少 synced_count');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final detail = e.response?.data['detail'];
        final errMessage = detail is String ? detail : '同步会话失败';
        throw ApiException(errMessage, e.response?.statusCode);
      } else {
        throw ApiException('网络连接超时或不可达');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('同步数据时发生了异常: $e');
    }
  }
}
