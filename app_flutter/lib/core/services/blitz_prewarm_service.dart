import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:cozy_clean/core/state/blitz_prewarm_state.dart';
import 'package:cozy_clean/features/blitz/data/providers/blitz_data_providers.dart';

/// isolate 中执行的 O(n) 分组函数，仅使用轻量 DTO 数据。
List<List<String>> _groupAssetLiteInIsolate(Map<String, Object?> input) {
  final thresholdMs = input['thresholdMs']! as int;
  final rawAssets = input['assets']! as List<Object?>;

  if (rawAssets.isEmpty) return const <List<String>>[];

  final assets = rawAssets
      .cast<Map<String, Object?>>()
      .map(AssetLite.fromMap)
      .toList(growable: false);

  final List<List<String>> groups = <List<String>>[];
  List<String> currentGroup = <String>[assets.first.id];

  for (int i = 1; i < assets.length; i++) {
    final diff = (assets[i].timestamp - assets[i - 1].timestamp).abs();
    if (diff <= thresholdMs) {
      currentGroup = <String>[...currentGroup, assets[i].id];
    } else {
      groups.add(currentGroup);
      currentGroup = <String>[assets[i].id];
    }
  }

  groups.add(currentGroup);
  return groups;
}

/// Blitz 预热常驻服务，负责后台扫描与缓存轻量元数据。
final blitzPrewarmServiceProvider =
    NotifierProvider<BlitzPrewarmService, BlitzPrewarmState>(
  BlitzPrewarmService.new,
);

/// Blitz 预热全局服务。
class BlitzPrewarmService extends Notifier<BlitzPrewarmState> {
  static const int _burstThresholdMs = 1500;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  AppLifecycleListener? _lifecycleListener;
  Timer? _debounceTimer;
  bool _isRefreshing = false;
  bool _changeNotifierStarted = false;

  BlitzRepository get _repository => ref.read(blitzRepositoryProvider);

  @override
  BlitzPrewarmState build() {
    _registerLifecycle();
    _registerPhotoChangeCallback();
    ref.onDispose(_disposeInternal);
    return BlitzPrewarmState();
  }

  /// 启动预热（幂等）。
  void warmUp() {
    if (state.status == PrewarmStatus.idle) {
      unawaited(refresh(force: true));
    }
  }

  /// 标记缓存过期。
  void markStale() {
    if (state.isStale) return;
    state = state.copyWith(
      isStale: true,
      status: state.hasData ? PrewarmStatus.refreshing : state.status,
    );
  }

  /// 触发防抖刷新。
  void scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(refresh());
    });
  }

  /// 执行一次预热刷新。
  Future<void> refresh({bool force = false}) async {
    if (_isRefreshing) return;
    if (!force && state.status == PrewarmStatus.ready && !state.isStale) return;

    _isRefreshing = true;
    final hadData = state.hasData;

    state = state.copyWith(
      status: hadData ? PrewarmStatus.refreshing : PrewarmStatus.scanning,
      errorMessage: () => null,
    );

    try {
      final hasPermission = await _repository.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: hadData ? PrewarmStatus.ready : PrewarmStatus.idle,
          isStale: !hadData,
          errorMessage: () => '相册权限未授权',
        );
        return;
      }

      final photos = await _repository.fetchUnprocessedPhotos();
      debugPrint('[BlitzPrewarmService] 预热扫描完成: photos=${photos.length}');
      if (photos.isEmpty) {
        state = state.copyWith(
          status: PrewarmStatus.ready,
          isStale: false,
          assets: const <AssetLite>[],
          groups: const <PhotoGroupLite>[],
          lastUpdatedAt: DateTime.now(),
          errorMessage: () => null,
        );
        return;
      }

      final assets = photos
          .map((photo) => AssetLite(
                id: photo.id,
                timestamp: photo.createDateTime.millisecondsSinceEpoch,
              ))
          .toList(growable: false)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final groupedIds = await compute(
        _groupAssetLiteInIsolate,
        <String, Object?>{
          'thresholdMs': _burstThresholdMs,
          'assets':
              assets.map((asset) => asset.toMap()).toList(growable: false),
        },
      );

      final groups = groupedIds
          .where((group) => group.isNotEmpty)
          .map((group) => PhotoGroupLite(assetIds: group))
          .toList(growable: false);

      state = state.copyWith(
        status: PrewarmStatus.ready,
        isStale: false,
        assets: assets,
        groups: groups,
        lastUpdatedAt: DateTime.now(),
        errorMessage: () => null,
      );
      debugPrint('[BlitzPrewarmService] 缓存更新: assets=${assets.length}, '
          'groups=${groups.length}');
    } catch (e, stackTrace) {
      debugPrint('[BlitzPrewarmService] 刷新失败: $e\n$stackTrace');
      state = state.copyWith(
        status: hadData ? PrewarmStatus.ready : PrewarmStatus.idle,
        isStale: true,
        errorMessage: () => '预热刷新失败: $e',
      );
    } finally {
      _isRefreshing = false;
    }
  }

  void _registerLifecycle() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        markStale();
        scheduleRefresh();
      },
    );
  }

  void _registerPhotoChangeCallback() {
    PhotoManager.addChangeCallback(_onPhotoLibraryChanged);
    PhotoManager.startChangeNotify();
    _changeNotifierStarted = true;
  }

  void _onPhotoLibraryChanged(MethodCall _) {
    markStale();
    scheduleRefresh();
  }

  void _disposeInternal() {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_changeNotifierStarted) {
      PhotoManager.removeChangeCallback(_onPhotoLibraryChanged);
      PhotoManager.stopChangeNotify();
      _changeNotifierStarted = false;
    }

    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}
