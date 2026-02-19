import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 代码生成所需
part 'app_database.g.dart';

@DataClassName('LocalUserStat')
class LocalUserStats extends Table {
  TextColumn get uid => text()();
  TextColumn get phoneOrWechat => text().nullable()();
  BoolColumn get isPro => boolean().withDefault(const Constant(false))();
  IntColumn get totalSavedBytes => integer().withDefault(const Constant(0))();
  RealColumn get dailyEnergyRemaining =>
      real().withDefault(const Constant(50.0))();
  IntColumn get dailyAdsWatchedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastResetTime =>
      dateTime().withDefault(currentDate)();

  @override
  Set<Column> get primaryKey => {uid};
}

@DataClassName('SessionLog')
class SessionLogs extends Table {
  TextColumn get sessionId => text()();
  IntColumn get mode => integer()(); // 0=闪电战, 1=截图粉碎机, 2=时光穿梭机
  IntColumn get deletedCount => integer().withDefault(const Constant(0))();
  IntColumn get savedBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get startTime => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

@DataClassName('PhotoAction')
class PhotoActions extends Table {
  TextColumn get id => text()(); // 原生 Asset ID
  TextColumn get md5 => text().nullable()();
  IntColumn get actionType => integer()(); // 0: 保留 (Keep), 1: 删除 (Delete)
  TextColumn get sessionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalUserStats, SessionLogs, PhotoActions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
