/// 同步操作领域层接口
abstract class ISyncRepository {
  /// 上传同步会话日志与照片操作记录
  ///
  /// [sessionId]: 会话的唯一 ID
  /// [mode]: 模式 (0=闪电战, 1=截图粉碎机, 2=时光穿梭机)
  /// [actions]: 照片的具体操作行为列表
  /// 返回: 成功同步的数据条数 (synced_count)
  Future<int> uploadSession(
      String sessionId, int mode, List<Map<String, dynamic>> actions);
}
