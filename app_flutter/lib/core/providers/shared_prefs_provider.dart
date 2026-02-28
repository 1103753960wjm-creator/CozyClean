import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局共享的 SharedPreferences 提供者。
/// 注意：实际的实例必须在 runApp() 之前的 ProviderScope 中通过 overrideWithValue 注入。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in ProviderScope');
});
