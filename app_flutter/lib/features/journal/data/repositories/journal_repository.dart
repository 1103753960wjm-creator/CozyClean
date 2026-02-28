/// CozyClean — 手账数据访问层
///
/// 提供手账海报的 CRUD 操作，封装 Drift 数据库细节。
/// Controller 层通过此 Repository 存取手账数据。
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:cozy_clean/data/local/app_database.dart';

/// 手账 Repository — 海报 CRUD
class JournalRepository {
  final AppDatabase _db;

  const JournalRepository(this._db);

  /// 保存新手账海报记录
  ///
  /// [title] 海报标题
  /// [photoAssetIds] 收藏照片的 Asset ID 列表
  /// [posterFilePath] 海报图片本地路径
  Future<int> saveJournal({
    required String title,
    required List<String> photoAssetIds,
    required String posterFilePath,
  }) async {
    return _db.into(_db.journals).insert(
          JournalsCompanion.insert(
            title: title,
            photoIds: jsonEncode(photoAssetIds),
            posterPath: posterFilePath,
          ),
        );
  }

  /// 获取所有手账海报（按创建时间倒序）
  Future<List<Journal>> getAllJournals() async {
    return (_db.select(_db.journals)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// 根据 ID 获取单条手账记录
  Future<Journal?> getJournalById(int id) async {
    return (_db.select(_db.journals)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 删除手账记录
  Future<int> deleteJournal(int id) async {
    return (_db.delete(_db.journals)..where((t) => t.id.equals(id))).go();
  }

  /// 解析 photoIds JSON 为 List<String>
  static List<String> parsePhotoIds(String photoIdsJson) {
    try {
      final List<dynamic> decoded = jsonDecode(photoIdsJson);
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }
}
