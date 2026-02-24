/// CozyClean — 全局格式化工具类
///
/// 集中管理所有数据格式化逻辑，避免各页面散落重复代码。
library;

/// 格式化工具集
class FormatUtils {
  FormatUtils._(); // 私有构造，禁止实例化

  /// 将字节数转换为人性化的存储空间展示文本
  ///
  /// 转换规则：
  ///   - < 1 KB  → "0 B"
  ///   - < 1 MB  → "xxx KB"
  ///   - < 1 GB  → "xxx.x MB"
  ///   - ≥ 1 GB  → "x.xx GB"
  ///
  /// 示例：
  ///   formatBytes(0)           → "0 B"
  ///   formatBytes(1536)        → "1 KB"
  ///   formatBytes(3145728)     → "3.0 MB"
  ///   formatBytes(1288490189)  → "1.20 GB"
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const int kb = 1024;
    const int mb = 1024 * 1024;
    const int gb = 1024 * 1024 * 1024;

    if (bytes < kb) {
      return '$bytes B';
    } else if (bytes < mb) {
      return '${(bytes / kb).round()} KB';
    } else if (bytes < gb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
  }
}
