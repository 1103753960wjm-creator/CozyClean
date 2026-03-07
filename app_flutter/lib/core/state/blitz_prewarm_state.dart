import 'package:flutter/foundation.dart';

/// 预热状态枚举。
enum PrewarmStatus {
  /// 尚未开始扫描。
  idle,

  /// 首次扫描中。
  scanning,

  /// 已有可用缓存。
  ready,

  /// 已有缓存可用，同时后台刷新中。
  refreshing,
}

/// 轻量照片元数据，仅用于预热与分组计算。
@immutable
class AssetLite {
  const AssetLite({
    required this.id,
    required this.timestamp,
  });

  final String id;
  final int timestamp;

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'timestamp': timestamp,
      };

  factory AssetLite.fromMap(Map<String, Object?> map) {
    return AssetLite(
      id: map['id']! as String,
      timestamp: map['timestamp']! as int,
    );
  }
}

/// 轻量分组结构，仅保存 ID 列表与最佳图索引。
@immutable
class PhotoGroupLite {
  PhotoGroupLite({
    required List<String> assetIds,
    this.bestIndex = 0,
  }) : assetIds = List<String>.unmodifiable(assetIds);

  final List<String> assetIds;
  final int bestIndex;

  bool get isEmpty => assetIds.isEmpty;
}

/// Blitz 预热全局状态。
@immutable
class BlitzPrewarmState {
  BlitzPrewarmState({
    this.status = PrewarmStatus.idle,
    this.isStale = false,
    List<AssetLite> assets = const <AssetLite>[],
    List<PhotoGroupLite> groups = const <PhotoGroupLite>[],
    this.lastUpdatedAt,
    this.errorMessage,
  })  : assets = List<AssetLite>.unmodifiable(assets),
        groups = List<PhotoGroupLite>.unmodifiable(groups);

  final PrewarmStatus status;
  final bool isStale;
  final List<AssetLite> assets;
  final List<PhotoGroupLite> groups;
  final DateTime? lastUpdatedAt;
  final String? errorMessage;

  bool get hasData => assets.isNotEmpty && groups.isNotEmpty;

  List<String> get assetIds =>
      List<String>.unmodifiable(assets.map((asset) => asset.id));

  BlitzPrewarmState copyWith({
    PrewarmStatus? status,
    bool? isStale,
    List<AssetLite>? assets,
    List<PhotoGroupLite>? groups,
    DateTime? lastUpdatedAt,
    String? Function()? errorMessage,
  }) {
    return BlitzPrewarmState(
      status: status ?? this.status,
      isStale: isStale ?? this.isStale,
      assets:
          assets != null ? List<AssetLite>.unmodifiable(assets) : this.assets,
      groups: groups != null
          ? List<PhotoGroupLite>.unmodifiable(groups)
          : this.groups,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}
