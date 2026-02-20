/// 认证与授权领域层接口
abstract class IAuthRepository {
  /// 登录请求
  ///
  /// [phone]: 手机号 (或微信 ID 等)
  /// [code]: 验证码或密码
  /// 返回: 成功则返回 JWT Token 字符串
  Future<String> login(String phone, String code);
}
