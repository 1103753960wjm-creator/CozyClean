/// CozyClean — 连拍照片分组服务
///
/// 纯逻辑服务层，不依赖 Flutter 框架、数据库、Repository 或 Controller。
/// 仅依赖 photo_manager 的 AssetEntity 类型定义和领域模型 PhotoGroup。
///
/// 设计原因：
///   iOS 的 burstIdentifier 在 Android 上不可用（Android 的 MediaStore
///   不暴露连拍标识符），因此需要基于时间戳的 fallback 分组算法。
///   本服务提供统一的跨平台连拍检测能力，确保双平台行为一致。
///
/// 架构约束：
///   - 本服务位于 domain/services 层，是纯业务逻辑
///   - 禁止 import 任何 controller、repository、database 或 UI 组件
///   - 仅允许依赖 domain/models 和外部类型定义
///
/// 算法：
///   单遍扫描（single pass），根据相邻照片的 createDateTime 差值
///   判定是否属于同一连拍组。
///
/// 复杂度：
///   时间 O(n)  — 单次遍历，无嵌套循环，无排序
///   内存 O(n)  — 输出分组列表与输入规模线性相关
///
/// Android/iOS 平台差异：
///   - iOS：photo_manager 可通过 AssetEntity 获取 burstIdentifier，
///     但该字段在 Android 上始终为 null。
///   - Android：MediaStore 不提供连拍标识符，只能依赖时间戳推断。
///   - 本服务选择时间戳差值作为统一方案，双平台行为完全一致，
///     避免平台分支导致的逻辑分裂和测试盲区。
library;

import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/features/blitz/domain/models/photo_group.dart';

/// 连拍照片分组服务
///
/// 纯函数实现，无状态、无副作用、无 IO。
/// 不持有任何实例变量（阈值通过构造注入后不可变），
/// 多次调用 [groupBurstPhotos] 对相同输入始终返回相同结果。
///
/// 使用方式：
/// ```dart
/// final service = BurstGroupingService();
/// final groups = service.groupBurstPhotos(sortedPhotos);
/// // groups: [PhotoGroup(3张连拍), PhotoGroup(1张独立), ...]
/// ```
///
/// 平台差异说明：
///   iOS 的 burstIdentifier 理论上更精确，但存在以下问题：
///   1. 仅 iOS 可用，Android 始终返回 null
///   2. 第三方相机 App 拍摄的连拍不一定写入 burstIdentifier
///   3. 跨平台一致性无法保证
///   因此本服务统一使用时间戳差值，牺牲少量精度换取跨平台稳定性。
class BurstGroupingService {
  /// 连拍判定阈值（毫秒）
  ///
  /// 若相邻两张照片的 createDateTime 差值 ≤ 此阈值，
  /// 则判定为属于同一连拍组。
  /// 默认 1500ms，覆盖绝大多数手机相机的连拍间隔。
  ///
  /// 阈值选择依据：
  ///   - iPhone 连拍间隔：约 100-200ms
  ///   - Android 连拍间隔：约 200-500ms（因厂商而异）
  ///   - 1500ms 留足余量，同时避免将正常连续拍摄误判为连拍
  final int burstThresholdMs;

  const BurstGroupingService({this.burstThresholdMs = 1500});

  /// 将照片列表按连拍关系分组
  ///
  /// **前置条件（调用方必须保证）：**
  ///   [photos] 必须已按 createDateTime 排序（升序）。
  ///   排序应在 Controller 或 Repository 层完成，
  ///   本纯函数不执行排序以保证 O(n) 复杂度。
  ///
  /// **算法步骤：**
  ///   1. 取第一张照片作为当前分组的起始元素
  ///   2. 逐张遍历后续照片，计算与前一张的 createDateTime 差值
  ///   3. 差值 ≤ [burstThresholdMs] → 归入当前连拍组
  ///   4. 差值 > [burstThresholdMs] → 封存当前组为 [PhotoGroup]，开启新组
  ///   5. 遍历结束后封存最后一组
  ///
  /// **复杂度分析：**
  ///   - 时间复杂度：O(n)，严格单遍扫描，无嵌套循环
  ///   - 内存复杂度：O(n)，输出 PhotoGroup 列表总元素数 = 输入照片数
  ///   - 无递归，无额外数据结构开销
  ///
  /// **副作用：** 无。不修改输入列表，不访问 IO/DB/网络。
  ///
  /// **返回值：**
  ///   按输入顺序排列的分组列表，每组包含 1 张或多张照片。
  ///   空输入返回空列表。
  List<PhotoGroup> groupBurstPhotos(List<AssetEntity> photos) {
    if (photos.isEmpty) return const [];
    if (photos.length == 1) {
      return [
        PhotoGroup(photos: [photos.first])
      ];
    }

    final List<PhotoGroup> groups = [];
    List<AssetEntity> currentGroup = [photos.first];

    for (int i = 1; i < photos.length; i++) {
      final prevTime = photos[i - 1].createDateTime;
      final currTime = photos[i].createDateTime;
      final diffMs = currTime.difference(prevTime).inMilliseconds.abs();

      if (diffMs <= burstThresholdMs) {
        // 时间差在阈值内 → 归入当前连拍组
        currentGroup.add(photos[i]);
      } else {
        // 时间差超出阈值 → 封存当前组，开启新组
        groups.add(PhotoGroup(photos: currentGroup));
        currentGroup = [photos[i]];
      }
    }

    // 封存最后一组
    groups.add(PhotoGroup(photos: currentGroup));

    return groups;
  }
}
