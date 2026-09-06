// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    amount,
    type,
    status,
    timestamp,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  final int id;
  final String transactionId;
  final double amount;
  final String type;
  final String status;
  final DateTime timestamp;
  final String? description;
  const LocalTransaction({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.type,
    required this.status,
    required this.timestamp,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<String>(transactionId);
    map['amount'] = Variable<double>(amount);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      amount: Value(amount),
      type: Value(type),
      status: Value(status),
      timestamp: Value(timestamp),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      amount: serializer.fromJson<double>(json['amount']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<String>(transactionId),
      'amount': serializer.toJson<double>(amount),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'description': serializer.toJson<String?>(description),
    };
  }

  LocalTransaction copyWith({
    int? id,
    String? transactionId,
    double? amount,
    String? type,
    String? status,
    DateTime? timestamp,
    Value<String?> description = const Value.absent(),
  }) => LocalTransaction(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    status: status ?? this.status,
    timestamp: timestamp ?? this.timestamp,
    description: description.present ? description.value : this.description,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      amount: data.amount.present ? data.amount.value : this.amount,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('timestamp: $timestamp, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    amount,
    type,
    status,
    timestamp,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.amount == this.amount &&
          other.type == this.type &&
          other.status == this.status &&
          other.timestamp == this.timestamp &&
          other.description == this.description);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<int> id;
  final Value<String> transactionId;
  final Value<double> amount;
  final Value<String> type;
  final Value<String> status;
  final Value<DateTime> timestamp;
  final Value<String?> description;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.amount = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.description = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String transactionId,
    required double amount,
    required String type,
    required String status,
    required DateTime timestamp,
    this.description = const Value.absent(),
  }) : transactionId = Value(transactionId),
       amount = Value(amount),
       type = Value(type),
       status = Value(status),
       timestamp = Value(timestamp);
  static Insertable<LocalTransaction> custom({
    Expression<int>? id,
    Expression<String>? transactionId,
    Expression<double>? amount,
    Expression<String>? type,
    Expression<String>? status,
    Expression<DateTime>? timestamp,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (timestamp != null) 'timestamp': timestamp,
      if (description != null) 'description': description,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? transactionId,
    Value<double>? amount,
    Value<String>? type,
    Value<String>? status,
    Value<DateTime>? timestamp,
    Value<String?>? description,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('timestamp: $timestamp, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $CachedApplicationsTable extends CachedApplications
    with TableInfo<$CachedApplicationsTable, CachedApplication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedApplicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomTitleMeta = const VerificationMeta(
    'roomTitle',
  );
  @override
  late final GeneratedColumn<String> roomTitle = GeneratedColumn<String>(
    'room_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rentMeta = const VerificationMeta('rent');
  @override
  late final GeneratedColumn<double> rent = GeneratedColumn<double>(
    'rent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<String> merchantId = GeneratedColumn<String>(
    'merchant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomIdMeta = const VerificationMeta('roomId');
  @override
  late final GeneratedColumn<String> roomId = GeneratedColumn<String>(
    'room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    roomTitle,
    rent,
    status,
    merchantId,
    roomId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_applications';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedApplication> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('room_title')) {
      context.handle(
        _roomTitleMeta,
        roomTitle.isAcceptableOrUnknown(data['room_title']!, _roomTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_roomTitleMeta);
    }
    if (data.containsKey('rent')) {
      context.handle(
        _rentMeta,
        rent.isAcceptableOrUnknown(data['rent']!, _rentMeta),
      );
    } else if (isInserting) {
      context.missing(_rentMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantIdMeta);
    }
    if (data.containsKey('room_id')) {
      context.handle(
        _roomIdMeta,
        roomId.isAcceptableOrUnknown(data['room_id']!, _roomIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roomIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedApplication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedApplication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      roomTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_title'],
      )!,
      rent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rent'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_id'],
      )!,
      roomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_id'],
      )!,
    );
  }

  @override
  $CachedApplicationsTable createAlias(String alias) {
    return $CachedApplicationsTable(attachedDatabase, alias);
  }
}

class CachedApplication extends DataClass
    implements Insertable<CachedApplication> {
  final String id;
  final String roomTitle;
  final double rent;
  final String status;
  final String merchantId;
  final String roomId;
  const CachedApplication({
    required this.id,
    required this.roomTitle,
    required this.rent,
    required this.status,
    required this.merchantId,
    required this.roomId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['room_title'] = Variable<String>(roomTitle);
    map['rent'] = Variable<double>(rent);
    map['status'] = Variable<String>(status);
    map['merchant_id'] = Variable<String>(merchantId);
    map['room_id'] = Variable<String>(roomId);
    return map;
  }

  CachedApplicationsCompanion toCompanion(bool nullToAbsent) {
    return CachedApplicationsCompanion(
      id: Value(id),
      roomTitle: Value(roomTitle),
      rent: Value(rent),
      status: Value(status),
      merchantId: Value(merchantId),
      roomId: Value(roomId),
    );
  }

  factory CachedApplication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedApplication(
      id: serializer.fromJson<String>(json['id']),
      roomTitle: serializer.fromJson<String>(json['roomTitle']),
      rent: serializer.fromJson<double>(json['rent']),
      status: serializer.fromJson<String>(json['status']),
      merchantId: serializer.fromJson<String>(json['merchantId']),
      roomId: serializer.fromJson<String>(json['roomId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roomTitle': serializer.toJson<String>(roomTitle),
      'rent': serializer.toJson<double>(rent),
      'status': serializer.toJson<String>(status),
      'merchantId': serializer.toJson<String>(merchantId),
      'roomId': serializer.toJson<String>(roomId),
    };
  }

  CachedApplication copyWith({
    String? id,
    String? roomTitle,
    double? rent,
    String? status,
    String? merchantId,
    String? roomId,
  }) => CachedApplication(
    id: id ?? this.id,
    roomTitle: roomTitle ?? this.roomTitle,
    rent: rent ?? this.rent,
    status: status ?? this.status,
    merchantId: merchantId ?? this.merchantId,
    roomId: roomId ?? this.roomId,
  );
  CachedApplication copyWithCompanion(CachedApplicationsCompanion data) {
    return CachedApplication(
      id: data.id.present ? data.id.value : this.id,
      roomTitle: data.roomTitle.present ? data.roomTitle.value : this.roomTitle,
      rent: data.rent.present ? data.rent.value : this.rent,
      status: data.status.present ? data.status.value : this.status,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      roomId: data.roomId.present ? data.roomId.value : this.roomId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedApplication(')
          ..write('id: $id, ')
          ..write('roomTitle: $roomTitle, ')
          ..write('rent: $rent, ')
          ..write('status: $status, ')
          ..write('merchantId: $merchantId, ')
          ..write('roomId: $roomId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, roomTitle, rent, status, merchantId, roomId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedApplication &&
          other.id == this.id &&
          other.roomTitle == this.roomTitle &&
          other.rent == this.rent &&
          other.status == this.status &&
          other.merchantId == this.merchantId &&
          other.roomId == this.roomId);
}

class CachedApplicationsCompanion extends UpdateCompanion<CachedApplication> {
  final Value<String> id;
  final Value<String> roomTitle;
  final Value<double> rent;
  final Value<String> status;
  final Value<String> merchantId;
  final Value<String> roomId;
  final Value<int> rowid;
  const CachedApplicationsCompanion({
    this.id = const Value.absent(),
    this.roomTitle = const Value.absent(),
    this.rent = const Value.absent(),
    this.status = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.roomId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedApplicationsCompanion.insert({
    required String id,
    required String roomTitle,
    required double rent,
    required String status,
    required String merchantId,
    required String roomId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       roomTitle = Value(roomTitle),
       rent = Value(rent),
       status = Value(status),
       merchantId = Value(merchantId),
       roomId = Value(roomId);
  static Insertable<CachedApplication> custom({
    Expression<String>? id,
    Expression<String>? roomTitle,
    Expression<double>? rent,
    Expression<String>? status,
    Expression<String>? merchantId,
    Expression<String>? roomId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roomTitle != null) 'room_title': roomTitle,
      if (rent != null) 'rent': rent,
      if (status != null) 'status': status,
      if (merchantId != null) 'merchant_id': merchantId,
      if (roomId != null) 'room_id': roomId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedApplicationsCompanion copyWith({
    Value<String>? id,
    Value<String>? roomTitle,
    Value<double>? rent,
    Value<String>? status,
    Value<String>? merchantId,
    Value<String>? roomId,
    Value<int>? rowid,
  }) {
    return CachedApplicationsCompanion(
      id: id ?? this.id,
      roomTitle: roomTitle ?? this.roomTitle,
      rent: rent ?? this.rent,
      status: status ?? this.status,
      merchantId: merchantId ?? this.merchantId,
      roomId: roomId ?? this.roomId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roomTitle.present) {
      map['room_title'] = Variable<String>(roomTitle.value);
    }
    if (rent.present) {
      map['rent'] = Variable<double>(rent.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<String>(merchantId.value);
    }
    if (roomId.present) {
      map['room_id'] = Variable<String>(roomId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedApplicationsCompanion(')
          ..write('id: $id, ')
          ..write('roomTitle: $roomTitle, ')
          ..write('rent: $rent, ')
          ..write('status: $status, ')
          ..write('merchantId: $merchantId, ')
          ..write('roomId: $roomId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $CachedApplicationsTable cachedApplications =
      $CachedApplicationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTransactions,
    cachedApplications,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      required String transactionId,
      required double amount,
      required String type,
      required String status,
      required DateTime timestamp,
      Value<String?> description,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<int> id,
      Value<String> transactionId,
      Value<double> amount,
      Value<String> type,
      Value<String> status,
      Value<DateTime> timestamp,
      Value<String?> description,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransaction,
            BaseReferences<
              _$AppDatabase,
              $LocalTransactionsTable,
              LocalTransaction
            >,
          ),
          LocalTransaction,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$AppDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                transactionId: transactionId,
                amount: amount,
                type: type,
                status: status,
                timestamp: timestamp,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String transactionId,
                required double amount,
                required String type,
                required String status,
                required DateTime timestamp,
                Value<String?> description = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                transactionId: transactionId,
                amount: amount,
                type: type,
                status: status,
                timestamp: timestamp,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransactionsTable,
      LocalTransaction,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransaction,
        BaseReferences<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction
        >,
      ),
      LocalTransaction,
      PrefetchHooks Function()
    >;
typedef $$CachedApplicationsTableCreateCompanionBuilder =
    CachedApplicationsCompanion Function({
      required String id,
      required String roomTitle,
      required double rent,
      required String status,
      required String merchantId,
      required String roomId,
      Value<int> rowid,
    });
typedef $$CachedApplicationsTableUpdateCompanionBuilder =
    CachedApplicationsCompanion Function({
      Value<String> id,
      Value<String> roomTitle,
      Value<double> rent,
      Value<String> status,
      Value<String> merchantId,
      Value<String> roomId,
      Value<int> rowid,
    });

class $$CachedApplicationsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedApplicationsTable> {
  $$CachedApplicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomTitle => $composableBuilder(
    column: $table.roomTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rent => $composableBuilder(
    column: $table.rent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedApplicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedApplicationsTable> {
  $$CachedApplicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomTitle => $composableBuilder(
    column: $table.roomTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rent => $composableBuilder(
    column: $table.rent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomId => $composableBuilder(
    column: $table.roomId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedApplicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedApplicationsTable> {
  $$CachedApplicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get roomTitle =>
      $composableBuilder(column: $table.roomTitle, builder: (column) => column);

  GeneratedColumn<double> get rent =>
      $composableBuilder(column: $table.rent, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomId =>
      $composableBuilder(column: $table.roomId, builder: (column) => column);
}

class $$CachedApplicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedApplicationsTable,
          CachedApplication,
          $$CachedApplicationsTableFilterComposer,
          $$CachedApplicationsTableOrderingComposer,
          $$CachedApplicationsTableAnnotationComposer,
          $$CachedApplicationsTableCreateCompanionBuilder,
          $$CachedApplicationsTableUpdateCompanionBuilder,
          (
            CachedApplication,
            BaseReferences<
              _$AppDatabase,
              $CachedApplicationsTable,
              CachedApplication
            >,
          ),
          CachedApplication,
          PrefetchHooks Function()
        > {
  $$CachedApplicationsTableTableManager(
    _$AppDatabase db,
    $CachedApplicationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedApplicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedApplicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedApplicationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> roomTitle = const Value.absent(),
                Value<double> rent = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> merchantId = const Value.absent(),
                Value<String> roomId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedApplicationsCompanion(
                id: id,
                roomTitle: roomTitle,
                rent: rent,
                status: status,
                merchantId: merchantId,
                roomId: roomId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String roomTitle,
                required double rent,
                required String status,
                required String merchantId,
                required String roomId,
                Value<int> rowid = const Value.absent(),
              }) => CachedApplicationsCompanion.insert(
                id: id,
                roomTitle: roomTitle,
                rent: rent,
                status: status,
                merchantId: merchantId,
                roomId: roomId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedApplicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedApplicationsTable,
      CachedApplication,
      $$CachedApplicationsTableFilterComposer,
      $$CachedApplicationsTableOrderingComposer,
      $$CachedApplicationsTableAnnotationComposer,
      $$CachedApplicationsTableCreateCompanionBuilder,
      $$CachedApplicationsTableUpdateCompanionBuilder,
      (
        CachedApplication,
        BaseReferences<
          _$AppDatabase,
          $CachedApplicationsTable,
          CachedApplication
        >,
      ),
      CachedApplication,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$CachedApplicationsTableTableManager get cachedApplications =>
      $$CachedApplicationsTableTableManager(_db, _db.cachedApplications);
}
