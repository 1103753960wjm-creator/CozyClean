// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalUserStatsTable extends LocalUserStats
    with TableInfo<$LocalUserStatsTable, LocalUserStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUserStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
      'uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneOrWechatMeta =
      const VerificationMeta('phoneOrWechat');
  @override
  late final GeneratedColumn<String> phoneOrWechat = GeneratedColumn<String>(
      'phone_or_wechat', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isProMeta = const VerificationMeta('isPro');
  @override
  late final GeneratedColumn<bool> isPro = GeneratedColumn<bool>(
      'is_pro', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pro" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _totalSavedBytesMeta =
      const VerificationMeta('totalSavedBytes');
  @override
  late final GeneratedColumn<int> totalSavedBytes = GeneratedColumn<int>(
      'total_saved_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _dailyEnergyRemainingMeta =
      const VerificationMeta('dailyEnergyRemaining');
  @override
  late final GeneratedColumn<double> dailyEnergyRemaining =
      GeneratedColumn<double>('daily_energy_remaining', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(50.0));
  static const VerificationMeta _dailyAdsWatchedCountMeta =
      const VerificationMeta('dailyAdsWatchedCount');
  @override
  late final GeneratedColumn<int> dailyAdsWatchedCount = GeneratedColumn<int>(
      'daily_ads_watched_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastResetTimeMeta =
      const VerificationMeta('lastResetTime');
  @override
  late final GeneratedColumn<DateTime> lastResetTime =
      GeneratedColumn<DateTime>('last_reset_time', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDate);
  @override
  List<GeneratedColumn> get $columns => [
        uid,
        phoneOrWechat,
        isPro,
        totalSavedBytes,
        dailyEnergyRemaining,
        dailyAdsWatchedCount,
        lastResetTime
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_stats';
  @override
  VerificationContext validateIntegrity(Insertable<LocalUserStat> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
          _uidMeta, uid.isAcceptableOrUnknown(data['uid']!, _uidMeta));
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('phone_or_wechat')) {
      context.handle(
          _phoneOrWechatMeta,
          phoneOrWechat.isAcceptableOrUnknown(
              data['phone_or_wechat']!, _phoneOrWechatMeta));
    }
    if (data.containsKey('is_pro')) {
      context.handle(
          _isProMeta, isPro.isAcceptableOrUnknown(data['is_pro']!, _isProMeta));
    }
    if (data.containsKey('total_saved_bytes')) {
      context.handle(
          _totalSavedBytesMeta,
          totalSavedBytes.isAcceptableOrUnknown(
              data['total_saved_bytes']!, _totalSavedBytesMeta));
    }
    if (data.containsKey('daily_energy_remaining')) {
      context.handle(
          _dailyEnergyRemainingMeta,
          dailyEnergyRemaining.isAcceptableOrUnknown(
              data['daily_energy_remaining']!, _dailyEnergyRemainingMeta));
    }
    if (data.containsKey('daily_ads_watched_count')) {
      context.handle(
          _dailyAdsWatchedCountMeta,
          dailyAdsWatchedCount.isAcceptableOrUnknown(
              data['daily_ads_watched_count']!, _dailyAdsWatchedCountMeta));
    }
    if (data.containsKey('last_reset_time')) {
      context.handle(
          _lastResetTimeMeta,
          lastResetTime.isAcceptableOrUnknown(
              data['last_reset_time']!, _lastResetTimeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  LocalUserStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUserStat(
      uid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uid'])!,
      phoneOrWechat: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone_or_wechat']),
      isPro: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pro'])!,
      totalSavedBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_saved_bytes'])!,
      dailyEnergyRemaining: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}daily_energy_remaining'])!,
      dailyAdsWatchedCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}daily_ads_watched_count'])!,
      lastResetTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_reset_time'])!,
    );
  }

  @override
  $LocalUserStatsTable createAlias(String alias) {
    return $LocalUserStatsTable(attachedDatabase, alias);
  }
}

class LocalUserStat extends DataClass implements Insertable<LocalUserStat> {
  final String uid;
  final String? phoneOrWechat;
  final bool isPro;
  final int totalSavedBytes;
  final double dailyEnergyRemaining;
  final int dailyAdsWatchedCount;
  final DateTime lastResetTime;
  const LocalUserStat(
      {required this.uid,
      this.phoneOrWechat,
      required this.isPro,
      required this.totalSavedBytes,
      required this.dailyEnergyRemaining,
      required this.dailyAdsWatchedCount,
      required this.lastResetTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    if (!nullToAbsent || phoneOrWechat != null) {
      map['phone_or_wechat'] = Variable<String>(phoneOrWechat);
    }
    map['is_pro'] = Variable<bool>(isPro);
    map['total_saved_bytes'] = Variable<int>(totalSavedBytes);
    map['daily_energy_remaining'] = Variable<double>(dailyEnergyRemaining);
    map['daily_ads_watched_count'] = Variable<int>(dailyAdsWatchedCount);
    map['last_reset_time'] = Variable<DateTime>(lastResetTime);
    return map;
  }

  LocalUserStatsCompanion toCompanion(bool nullToAbsent) {
    return LocalUserStatsCompanion(
      uid: Value(uid),
      phoneOrWechat: phoneOrWechat == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneOrWechat),
      isPro: Value(isPro),
      totalSavedBytes: Value(totalSavedBytes),
      dailyEnergyRemaining: Value(dailyEnergyRemaining),
      dailyAdsWatchedCount: Value(dailyAdsWatchedCount),
      lastResetTime: Value(lastResetTime),
    );
  }

  factory LocalUserStat.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUserStat(
      uid: serializer.fromJson<String>(json['uid']),
      phoneOrWechat: serializer.fromJson<String?>(json['phoneOrWechat']),
      isPro: serializer.fromJson<bool>(json['isPro']),
      totalSavedBytes: serializer.fromJson<int>(json['totalSavedBytes']),
      dailyEnergyRemaining:
          serializer.fromJson<double>(json['dailyEnergyRemaining']),
      dailyAdsWatchedCount:
          serializer.fromJson<int>(json['dailyAdsWatchedCount']),
      lastResetTime: serializer.fromJson<DateTime>(json['lastResetTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'phoneOrWechat': serializer.toJson<String?>(phoneOrWechat),
      'isPro': serializer.toJson<bool>(isPro),
      'totalSavedBytes': serializer.toJson<int>(totalSavedBytes),
      'dailyEnergyRemaining': serializer.toJson<double>(dailyEnergyRemaining),
      'dailyAdsWatchedCount': serializer.toJson<int>(dailyAdsWatchedCount),
      'lastResetTime': serializer.toJson<DateTime>(lastResetTime),
    };
  }

  LocalUserStat copyWith(
          {String? uid,
          Value<String?> phoneOrWechat = const Value.absent(),
          bool? isPro,
          int? totalSavedBytes,
          double? dailyEnergyRemaining,
          int? dailyAdsWatchedCount,
          DateTime? lastResetTime}) =>
      LocalUserStat(
        uid: uid ?? this.uid,
        phoneOrWechat:
            phoneOrWechat.present ? phoneOrWechat.value : this.phoneOrWechat,
        isPro: isPro ?? this.isPro,
        totalSavedBytes: totalSavedBytes ?? this.totalSavedBytes,
        dailyEnergyRemaining: dailyEnergyRemaining ?? this.dailyEnergyRemaining,
        dailyAdsWatchedCount: dailyAdsWatchedCount ?? this.dailyAdsWatchedCount,
        lastResetTime: lastResetTime ?? this.lastResetTime,
      );
  LocalUserStat copyWithCompanion(LocalUserStatsCompanion data) {
    return LocalUserStat(
      uid: data.uid.present ? data.uid.value : this.uid,
      phoneOrWechat: data.phoneOrWechat.present
          ? data.phoneOrWechat.value
          : this.phoneOrWechat,
      isPro: data.isPro.present ? data.isPro.value : this.isPro,
      totalSavedBytes: data.totalSavedBytes.present
          ? data.totalSavedBytes.value
          : this.totalSavedBytes,
      dailyEnergyRemaining: data.dailyEnergyRemaining.present
          ? data.dailyEnergyRemaining.value
          : this.dailyEnergyRemaining,
      dailyAdsWatchedCount: data.dailyAdsWatchedCount.present
          ? data.dailyAdsWatchedCount.value
          : this.dailyAdsWatchedCount,
      lastResetTime: data.lastResetTime.present
          ? data.lastResetTime.value
          : this.lastResetTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserStat(')
          ..write('uid: $uid, ')
          ..write('phoneOrWechat: $phoneOrWechat, ')
          ..write('isPro: $isPro, ')
          ..write('totalSavedBytes: $totalSavedBytes, ')
          ..write('dailyEnergyRemaining: $dailyEnergyRemaining, ')
          ..write('dailyAdsWatchedCount: $dailyAdsWatchedCount, ')
          ..write('lastResetTime: $lastResetTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, phoneOrWechat, isPro, totalSavedBytes,
      dailyEnergyRemaining, dailyAdsWatchedCount, lastResetTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUserStat &&
          other.uid == this.uid &&
          other.phoneOrWechat == this.phoneOrWechat &&
          other.isPro == this.isPro &&
          other.totalSavedBytes == this.totalSavedBytes &&
          other.dailyEnergyRemaining == this.dailyEnergyRemaining &&
          other.dailyAdsWatchedCount == this.dailyAdsWatchedCount &&
          other.lastResetTime == this.lastResetTime);
}

class LocalUserStatsCompanion extends UpdateCompanion<LocalUserStat> {
  final Value<String> uid;
  final Value<String?> phoneOrWechat;
  final Value<bool> isPro;
  final Value<int> totalSavedBytes;
  final Value<double> dailyEnergyRemaining;
  final Value<int> dailyAdsWatchedCount;
  final Value<DateTime> lastResetTime;
  final Value<int> rowid;
  const LocalUserStatsCompanion({
    this.uid = const Value.absent(),
    this.phoneOrWechat = const Value.absent(),
    this.isPro = const Value.absent(),
    this.totalSavedBytes = const Value.absent(),
    this.dailyEnergyRemaining = const Value.absent(),
    this.dailyAdsWatchedCount = const Value.absent(),
    this.lastResetTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUserStatsCompanion.insert({
    required String uid,
    this.phoneOrWechat = const Value.absent(),
    this.isPro = const Value.absent(),
    this.totalSavedBytes = const Value.absent(),
    this.dailyEnergyRemaining = const Value.absent(),
    this.dailyAdsWatchedCount = const Value.absent(),
    this.lastResetTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uid = Value(uid);
  static Insertable<LocalUserStat> custom({
    Expression<String>? uid,
    Expression<String>? phoneOrWechat,
    Expression<bool>? isPro,
    Expression<int>? totalSavedBytes,
    Expression<double>? dailyEnergyRemaining,
    Expression<int>? dailyAdsWatchedCount,
    Expression<DateTime>? lastResetTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (phoneOrWechat != null) 'phone_or_wechat': phoneOrWechat,
      if (isPro != null) 'is_pro': isPro,
      if (totalSavedBytes != null) 'total_saved_bytes': totalSavedBytes,
      if (dailyEnergyRemaining != null)
        'daily_energy_remaining': dailyEnergyRemaining,
      if (dailyAdsWatchedCount != null)
        'daily_ads_watched_count': dailyAdsWatchedCount,
      if (lastResetTime != null) 'last_reset_time': lastResetTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUserStatsCompanion copyWith(
      {Value<String>? uid,
      Value<String?>? phoneOrWechat,
      Value<bool>? isPro,
      Value<int>? totalSavedBytes,
      Value<double>? dailyEnergyRemaining,
      Value<int>? dailyAdsWatchedCount,
      Value<DateTime>? lastResetTime,
      Value<int>? rowid}) {
    return LocalUserStatsCompanion(
      uid: uid ?? this.uid,
      phoneOrWechat: phoneOrWechat ?? this.phoneOrWechat,
      isPro: isPro ?? this.isPro,
      totalSavedBytes: totalSavedBytes ?? this.totalSavedBytes,
      dailyEnergyRemaining: dailyEnergyRemaining ?? this.dailyEnergyRemaining,
      dailyAdsWatchedCount: dailyAdsWatchedCount ?? this.dailyAdsWatchedCount,
      lastResetTime: lastResetTime ?? this.lastResetTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (phoneOrWechat.present) {
      map['phone_or_wechat'] = Variable<String>(phoneOrWechat.value);
    }
    if (isPro.present) {
      map['is_pro'] = Variable<bool>(isPro.value);
    }
    if (totalSavedBytes.present) {
      map['total_saved_bytes'] = Variable<int>(totalSavedBytes.value);
    }
    if (dailyEnergyRemaining.present) {
      map['daily_energy_remaining'] =
          Variable<double>(dailyEnergyRemaining.value);
    }
    if (dailyAdsWatchedCount.present) {
      map['daily_ads_watched_count'] =
          Variable<int>(dailyAdsWatchedCount.value);
    }
    if (lastResetTime.present) {
      map['last_reset_time'] = Variable<DateTime>(lastResetTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserStatsCompanion(')
          ..write('uid: $uid, ')
          ..write('phoneOrWechat: $phoneOrWechat, ')
          ..write('isPro: $isPro, ')
          ..write('totalSavedBytes: $totalSavedBytes, ')
          ..write('dailyEnergyRemaining: $dailyEnergyRemaining, ')
          ..write('dailyAdsWatchedCount: $dailyAdsWatchedCount, ')
          ..write('lastResetTime: $lastResetTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionLogsTable extends SessionLogs
    with TableInfo<$SessionLogsTable, SessionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<int> mode = GeneratedColumn<int>(
      'mode', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deletedCountMeta =
      const VerificationMeta('deletedCount');
  @override
  late final GeneratedColumn<int> deletedCount = GeneratedColumn<int>(
      'deleted_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _savedBytesMeta =
      const VerificationMeta('savedBytes');
  @override
  late final GeneratedColumn<int> savedBytes = GeneratedColumn<int>(
      'saved_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [sessionId, mode, deletedCount, savedBytes, startTime, isSynced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SessionLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('deleted_count')) {
      context.handle(
          _deletedCountMeta,
          deletedCount.isAcceptableOrUnknown(
              data['deleted_count']!, _deletedCountMeta));
    }
    if (data.containsKey('saved_bytes')) {
      context.handle(
          _savedBytesMeta,
          savedBytes.isAcceptableOrUnknown(
              data['saved_bytes']!, _savedBytesMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionLog(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mode'])!,
      deletedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_count'])!,
      savedBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}saved_bytes'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $SessionLogsTable createAlias(String alias) {
    return $SessionLogsTable(attachedDatabase, alias);
  }
}

class SessionLog extends DataClass implements Insertable<SessionLog> {
  final String sessionId;
  final int mode;
  final int deletedCount;
  final int savedBytes;
  final DateTime startTime;
  final bool isSynced;
  const SessionLog(
      {required this.sessionId,
      required this.mode,
      required this.deletedCount,
      required this.savedBytes,
      required this.startTime,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['mode'] = Variable<int>(mode);
    map['deleted_count'] = Variable<int>(deletedCount);
    map['saved_bytes'] = Variable<int>(savedBytes);
    map['start_time'] = Variable<DateTime>(startTime);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  SessionLogsCompanion toCompanion(bool nullToAbsent) {
    return SessionLogsCompanion(
      sessionId: Value(sessionId),
      mode: Value(mode),
      deletedCount: Value(deletedCount),
      savedBytes: Value(savedBytes),
      startTime: Value(startTime),
      isSynced: Value(isSynced),
    );
  }

  factory SessionLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionLog(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      mode: serializer.fromJson<int>(json['mode']),
      deletedCount: serializer.fromJson<int>(json['deletedCount']),
      savedBytes: serializer.fromJson<int>(json['savedBytes']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'mode': serializer.toJson<int>(mode),
      'deletedCount': serializer.toJson<int>(deletedCount),
      'savedBytes': serializer.toJson<int>(savedBytes),
      'startTime': serializer.toJson<DateTime>(startTime),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  SessionLog copyWith(
          {String? sessionId,
          int? mode,
          int? deletedCount,
          int? savedBytes,
          DateTime? startTime,
          bool? isSynced}) =>
      SessionLog(
        sessionId: sessionId ?? this.sessionId,
        mode: mode ?? this.mode,
        deletedCount: deletedCount ?? this.deletedCount,
        savedBytes: savedBytes ?? this.savedBytes,
        startTime: startTime ?? this.startTime,
        isSynced: isSynced ?? this.isSynced,
      );
  SessionLog copyWithCompanion(SessionLogsCompanion data) {
    return SessionLog(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      mode: data.mode.present ? data.mode.value : this.mode,
      deletedCount: data.deletedCount.present
          ? data.deletedCount.value
          : this.deletedCount,
      savedBytes:
          data.savedBytes.present ? data.savedBytes.value : this.savedBytes,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionLog(')
          ..write('sessionId: $sessionId, ')
          ..write('mode: $mode, ')
          ..write('deletedCount: $deletedCount, ')
          ..write('savedBytes: $savedBytes, ')
          ..write('startTime: $startTime, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      sessionId, mode, deletedCount, savedBytes, startTime, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionLog &&
          other.sessionId == this.sessionId &&
          other.mode == this.mode &&
          other.deletedCount == this.deletedCount &&
          other.savedBytes == this.savedBytes &&
          other.startTime == this.startTime &&
          other.isSynced == this.isSynced);
}

class SessionLogsCompanion extends UpdateCompanion<SessionLog> {
  final Value<String> sessionId;
  final Value<int> mode;
  final Value<int> deletedCount;
  final Value<int> savedBytes;
  final Value<DateTime> startTime;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const SessionLogsCompanion({
    this.sessionId = const Value.absent(),
    this.mode = const Value.absent(),
    this.deletedCount = const Value.absent(),
    this.savedBytes = const Value.absent(),
    this.startTime = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionLogsCompanion.insert({
    required String sessionId,
    required int mode,
    this.deletedCount = const Value.absent(),
    this.savedBytes = const Value.absent(),
    required DateTime startTime,
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        mode = Value(mode),
        startTime = Value(startTime);
  static Insertable<SessionLog> custom({
    Expression<String>? sessionId,
    Expression<int>? mode,
    Expression<int>? deletedCount,
    Expression<int>? savedBytes,
    Expression<DateTime>? startTime,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (mode != null) 'mode': mode,
      if (deletedCount != null) 'deleted_count': deletedCount,
      if (savedBytes != null) 'saved_bytes': savedBytes,
      if (startTime != null) 'start_time': startTime,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionLogsCompanion copyWith(
      {Value<String>? sessionId,
      Value<int>? mode,
      Value<int>? deletedCount,
      Value<int>? savedBytes,
      Value<DateTime>? startTime,
      Value<bool>? isSynced,
      Value<int>? rowid}) {
    return SessionLogsCompanion(
      sessionId: sessionId ?? this.sessionId,
      mode: mode ?? this.mode,
      deletedCount: deletedCount ?? this.deletedCount,
      savedBytes: savedBytes ?? this.savedBytes,
      startTime: startTime ?? this.startTime,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<int>(mode.value);
    }
    if (deletedCount.present) {
      map['deleted_count'] = Variable<int>(deletedCount.value);
    }
    if (savedBytes.present) {
      map['saved_bytes'] = Variable<int>(savedBytes.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionLogsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('mode: $mode, ')
          ..write('deletedCount: $deletedCount, ')
          ..write('savedBytes: $savedBytes, ')
          ..write('startTime: $startTime, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoActionsTable extends PhotoActions
    with TableInfo<$PhotoActionsTable, PhotoAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _md5Meta = const VerificationMeta('md5');
  @override
  late final GeneratedColumn<String> md5 = GeneratedColumn<String>(
      'md5', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<int> actionType = GeneratedColumn<int>(
      'action_type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, md5, actionType, sessionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_actions';
  @override
  VerificationContext validateIntegrity(Insertable<PhotoAction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('md5')) {
      context.handle(
          _md5Meta, md5.isAcceptableOrUnknown(data['md5']!, _md5Meta));
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoAction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      md5: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}md5']),
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}action_type'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
    );
  }

  @override
  $PhotoActionsTable createAlias(String alias) {
    return $PhotoActionsTable(attachedDatabase, alias);
  }
}

class PhotoAction extends DataClass implements Insertable<PhotoAction> {
  final String id;
  final String? md5;
  final int actionType;
  final String? sessionId;
  const PhotoAction(
      {required this.id, this.md5, required this.actionType, this.sessionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || md5 != null) {
      map['md5'] = Variable<String>(md5);
    }
    map['action_type'] = Variable<int>(actionType);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    return map;
  }

  PhotoActionsCompanion toCompanion(bool nullToAbsent) {
    return PhotoActionsCompanion(
      id: Value(id),
      md5: md5 == null && nullToAbsent ? const Value.absent() : Value(md5),
      actionType: Value(actionType),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
    );
  }

  factory PhotoAction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoAction(
      id: serializer.fromJson<String>(json['id']),
      md5: serializer.fromJson<String?>(json['md5']),
      actionType: serializer.fromJson<int>(json['actionType']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'md5': serializer.toJson<String?>(md5),
      'actionType': serializer.toJson<int>(actionType),
      'sessionId': serializer.toJson<String?>(sessionId),
    };
  }

  PhotoAction copyWith(
          {String? id,
          Value<String?> md5 = const Value.absent(),
          int? actionType,
          Value<String?> sessionId = const Value.absent()}) =>
      PhotoAction(
        id: id ?? this.id,
        md5: md5.present ? md5.value : this.md5,
        actionType: actionType ?? this.actionType,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
      );
  PhotoAction copyWithCompanion(PhotoActionsCompanion data) {
    return PhotoAction(
      id: data.id.present ? data.id.value : this.id,
      md5: data.md5.present ? data.md5.value : this.md5,
      actionType:
          data.actionType.present ? data.actionType.value : this.actionType,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoAction(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('actionType: $actionType, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, md5, actionType, sessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoAction &&
          other.id == this.id &&
          other.md5 == this.md5 &&
          other.actionType == this.actionType &&
          other.sessionId == this.sessionId);
}

class PhotoActionsCompanion extends UpdateCompanion<PhotoAction> {
  final Value<String> id;
  final Value<String?> md5;
  final Value<int> actionType;
  final Value<String?> sessionId;
  final Value<int> rowid;
  const PhotoActionsCompanion({
    this.id = const Value.absent(),
    this.md5 = const Value.absent(),
    this.actionType = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoActionsCompanion.insert({
    required String id,
    this.md5 = const Value.absent(),
    required int actionType,
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        actionType = Value(actionType);
  static Insertable<PhotoAction> custom({
    Expression<String>? id,
    Expression<String>? md5,
    Expression<int>? actionType,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (md5 != null) 'md5': md5,
      if (actionType != null) 'action_type': actionType,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoActionsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? md5,
      Value<int>? actionType,
      Value<String?>? sessionId,
      Value<int>? rowid}) {
    return PhotoActionsCompanion(
      id: id ?? this.id,
      md5: md5 ?? this.md5,
      actionType: actionType ?? this.actionType,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (md5.present) {
      map['md5'] = Variable<String>(md5.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<int>(actionType.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoActionsCompanion(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('actionType: $actionType, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalUserStatsTable localUserStats = $LocalUserStatsTable(this);
  late final $SessionLogsTable sessionLogs = $SessionLogsTable(this);
  late final $PhotoActionsTable photoActions = $PhotoActionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localUserStats, sessionLogs, photoActions];
}

typedef $$LocalUserStatsTableCreateCompanionBuilder = LocalUserStatsCompanion
    Function({
  required String uid,
  Value<String?> phoneOrWechat,
  Value<bool> isPro,
  Value<int> totalSavedBytes,
  Value<double> dailyEnergyRemaining,
  Value<int> dailyAdsWatchedCount,
  Value<DateTime> lastResetTime,
  Value<int> rowid,
});
typedef $$LocalUserStatsTableUpdateCompanionBuilder = LocalUserStatsCompanion
    Function({
  Value<String> uid,
  Value<String?> phoneOrWechat,
  Value<bool> isPro,
  Value<int> totalSavedBytes,
  Value<double> dailyEnergyRemaining,
  Value<int> dailyAdsWatchedCount,
  Value<DateTime> lastResetTime,
  Value<int> rowid,
});

class $$LocalUserStatsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUserStatsTable> {
  $$LocalUserStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phoneOrWechat => $composableBuilder(
      column: $table.phoneOrWechat, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPro => $composableBuilder(
      column: $table.isPro, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSavedBytes => $composableBuilder(
      column: $table.totalSavedBytes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get dailyEnergyRemaining => $composableBuilder(
      column: $table.dailyEnergyRemaining,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyAdsWatchedCount => $composableBuilder(
      column: $table.dailyAdsWatchedCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastResetTime => $composableBuilder(
      column: $table.lastResetTime, builder: (column) => ColumnFilters(column));
}

class $$LocalUserStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUserStatsTable> {
  $$LocalUserStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
      column: $table.uid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phoneOrWechat => $composableBuilder(
      column: $table.phoneOrWechat,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPro => $composableBuilder(
      column: $table.isPro, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSavedBytes => $composableBuilder(
      column: $table.totalSavedBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get dailyEnergyRemaining => $composableBuilder(
      column: $table.dailyEnergyRemaining,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyAdsWatchedCount => $composableBuilder(
      column: $table.dailyAdsWatchedCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastResetTime => $composableBuilder(
      column: $table.lastResetTime,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalUserStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUserStatsTable> {
  $$LocalUserStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get phoneOrWechat => $composableBuilder(
      column: $table.phoneOrWechat, builder: (column) => column);

  GeneratedColumn<bool> get isPro =>
      $composableBuilder(column: $table.isPro, builder: (column) => column);

  GeneratedColumn<int> get totalSavedBytes => $composableBuilder(
      column: $table.totalSavedBytes, builder: (column) => column);

  GeneratedColumn<double> get dailyEnergyRemaining => $composableBuilder(
      column: $table.dailyEnergyRemaining, builder: (column) => column);

  GeneratedColumn<int> get dailyAdsWatchedCount => $composableBuilder(
      column: $table.dailyAdsWatchedCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastResetTime => $composableBuilder(
      column: $table.lastResetTime, builder: (column) => column);
}

class $$LocalUserStatsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalUserStatsTable,
    LocalUserStat,
    $$LocalUserStatsTableFilterComposer,
    $$LocalUserStatsTableOrderingComposer,
    $$LocalUserStatsTableAnnotationComposer,
    $$LocalUserStatsTableCreateCompanionBuilder,
    $$LocalUserStatsTableUpdateCompanionBuilder,
    (
      LocalUserStat,
      BaseReferences<_$AppDatabase, $LocalUserStatsTable, LocalUserStat>
    ),
    LocalUserStat,
    PrefetchHooks Function()> {
  $$LocalUserStatsTableTableManager(
      _$AppDatabase db, $LocalUserStatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUserStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUserStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUserStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uid = const Value.absent(),
            Value<String?> phoneOrWechat = const Value.absent(),
            Value<bool> isPro = const Value.absent(),
            Value<int> totalSavedBytes = const Value.absent(),
            Value<double> dailyEnergyRemaining = const Value.absent(),
            Value<int> dailyAdsWatchedCount = const Value.absent(),
            Value<DateTime> lastResetTime = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUserStatsCompanion(
            uid: uid,
            phoneOrWechat: phoneOrWechat,
            isPro: isPro,
            totalSavedBytes: totalSavedBytes,
            dailyEnergyRemaining: dailyEnergyRemaining,
            dailyAdsWatchedCount: dailyAdsWatchedCount,
            lastResetTime: lastResetTime,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uid,
            Value<String?> phoneOrWechat = const Value.absent(),
            Value<bool> isPro = const Value.absent(),
            Value<int> totalSavedBytes = const Value.absent(),
            Value<double> dailyEnergyRemaining = const Value.absent(),
            Value<int> dailyAdsWatchedCount = const Value.absent(),
            Value<DateTime> lastResetTime = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUserStatsCompanion.insert(
            uid: uid,
            phoneOrWechat: phoneOrWechat,
            isPro: isPro,
            totalSavedBytes: totalSavedBytes,
            dailyEnergyRemaining: dailyEnergyRemaining,
            dailyAdsWatchedCount: dailyAdsWatchedCount,
            lastResetTime: lastResetTime,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalUserStatsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalUserStatsTable,
    LocalUserStat,
    $$LocalUserStatsTableFilterComposer,
    $$LocalUserStatsTableOrderingComposer,
    $$LocalUserStatsTableAnnotationComposer,
    $$LocalUserStatsTableCreateCompanionBuilder,
    $$LocalUserStatsTableUpdateCompanionBuilder,
    (
      LocalUserStat,
      BaseReferences<_$AppDatabase, $LocalUserStatsTable, LocalUserStat>
    ),
    LocalUserStat,
    PrefetchHooks Function()>;
typedef $$SessionLogsTableCreateCompanionBuilder = SessionLogsCompanion
    Function({
  required String sessionId,
  required int mode,
  Value<int> deletedCount,
  Value<int> savedBytes,
  required DateTime startTime,
  Value<bool> isSynced,
  Value<int> rowid,
});
typedef $$SessionLogsTableUpdateCompanionBuilder = SessionLogsCompanion
    Function({
  Value<String> sessionId,
  Value<int> mode,
  Value<int> deletedCount,
  Value<int> savedBytes,
  Value<DateTime> startTime,
  Value<bool> isSynced,
  Value<int> rowid,
});

class $$SessionLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedCount => $composableBuilder(
      column: $table.deletedCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get savedBytes => $composableBuilder(
      column: $table.savedBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));
}

class $$SessionLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedCount => $composableBuilder(
      column: $table.deletedCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get savedBytes => $composableBuilder(
      column: $table.savedBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));
}

class $$SessionLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get deletedCount => $composableBuilder(
      column: $table.deletedCount, builder: (column) => column);

  GeneratedColumn<int> get savedBytes => $composableBuilder(
      column: $table.savedBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$SessionLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionLogsTable,
    SessionLog,
    $$SessionLogsTableFilterComposer,
    $$SessionLogsTableOrderingComposer,
    $$SessionLogsTableAnnotationComposer,
    $$SessionLogsTableCreateCompanionBuilder,
    $$SessionLogsTableUpdateCompanionBuilder,
    (SessionLog, BaseReferences<_$AppDatabase, $SessionLogsTable, SessionLog>),
    SessionLog,
    PrefetchHooks Function()> {
  $$SessionLogsTableTableManager(_$AppDatabase db, $SessionLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<int> mode = const Value.absent(),
            Value<int> deletedCount = const Value.absent(),
            Value<int> savedBytes = const Value.absent(),
            Value<DateTime> startTime = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionLogsCompanion(
            sessionId: sessionId,
            mode: mode,
            deletedCount: deletedCount,
            savedBytes: savedBytes,
            startTime: startTime,
            isSynced: isSynced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required int mode,
            Value<int> deletedCount = const Value.absent(),
            Value<int> savedBytes = const Value.absent(),
            required DateTime startTime,
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionLogsCompanion.insert(
            sessionId: sessionId,
            mode: mode,
            deletedCount: deletedCount,
            savedBytes: savedBytes,
            startTime: startTime,
            isSynced: isSynced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionLogsTable,
    SessionLog,
    $$SessionLogsTableFilterComposer,
    $$SessionLogsTableOrderingComposer,
    $$SessionLogsTableAnnotationComposer,
    $$SessionLogsTableCreateCompanionBuilder,
    $$SessionLogsTableUpdateCompanionBuilder,
    (SessionLog, BaseReferences<_$AppDatabase, $SessionLogsTable, SessionLog>),
    SessionLog,
    PrefetchHooks Function()>;
typedef $$PhotoActionsTableCreateCompanionBuilder = PhotoActionsCompanion
    Function({
  required String id,
  Value<String?> md5,
  required int actionType,
  Value<String?> sessionId,
  Value<int> rowid,
});
typedef $$PhotoActionsTableUpdateCompanionBuilder = PhotoActionsCompanion
    Function({
  Value<String> id,
  Value<String?> md5,
  Value<int> actionType,
  Value<String?> sessionId,
  Value<int> rowid,
});

class $$PhotoActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoActionsTable> {
  $$PhotoActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));
}

class $$PhotoActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoActionsTable> {
  $$PhotoActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));
}

class $$PhotoActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoActionsTable> {
  $$PhotoActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get md5 =>
      $composableBuilder(column: $table.md5, builder: (column) => column);

  GeneratedColumn<int> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$PhotoActionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhotoActionsTable,
    PhotoAction,
    $$PhotoActionsTableFilterComposer,
    $$PhotoActionsTableOrderingComposer,
    $$PhotoActionsTableAnnotationComposer,
    $$PhotoActionsTableCreateCompanionBuilder,
    $$PhotoActionsTableUpdateCompanionBuilder,
    (
      PhotoAction,
      BaseReferences<_$AppDatabase, $PhotoActionsTable, PhotoAction>
    ),
    PhotoAction,
    PrefetchHooks Function()> {
  $$PhotoActionsTableTableManager(_$AppDatabase db, $PhotoActionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> md5 = const Value.absent(),
            Value<int> actionType = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoActionsCompanion(
            id: id,
            md5: md5,
            actionType: actionType,
            sessionId: sessionId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> md5 = const Value.absent(),
            required int actionType,
            Value<String?> sessionId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PhotoActionsCompanion.insert(
            id: id,
            md5: md5,
            actionType: actionType,
            sessionId: sessionId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PhotoActionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhotoActionsTable,
    PhotoAction,
    $$PhotoActionsTableFilterComposer,
    $$PhotoActionsTableOrderingComposer,
    $$PhotoActionsTableAnnotationComposer,
    $$PhotoActionsTableCreateCompanionBuilder,
    $$PhotoActionsTableUpdateCompanionBuilder,
    (
      PhotoAction,
      BaseReferences<_$AppDatabase, $PhotoActionsTable, PhotoAction>
    ),
    PhotoAction,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalUserStatsTableTableManager get localUserStats =>
      $$LocalUserStatsTableTableManager(_db, _db.localUserStats);
  $$SessionLogsTableTableManager get sessionLogs =>
      $$SessionLogsTableTableManager(_db, _db.sessionLogs);
  $$PhotoActionsTableTableManager get photoActions =>
      $$PhotoActionsTableTableManager(_db, _db.photoActions);
}
