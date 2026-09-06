import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// -------------------------------------------------------------
// Define the tables used in the DISHI app for local caching.
// -------------------------------------------------------------

@DataClassName('LocalTransaction')
class LocalTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().unique()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // e.g., 'rent', 'dishi', 'vault_transfer'
  TextColumn get status => text()(); // e.g., 'completed', 'pending'
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get description => text().nullable()();
}

@DataClassName('CachedApplication')
class CachedApplications extends Table {
  TextColumn get id => text()();
  TextColumn get roomTitle => text()();
  RealColumn get rent => real()();
  TextColumn get status => text()();
  TextColumn get merchantId => text()();
  TextColumn get roomId => text()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// -------------------------------------------------------------
// Database setup
// -------------------------------------------------------------

@DriftDatabase(tables: [LocalTransactions, CachedApplications])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Transactions ---
  Future<List<LocalTransaction>> getAllTransactions() => select(localTransactions).get();
  Future<void> insertTransaction(LocalTransaction tx) => into(localTransactions).insert(tx, mode: InsertMode.insertOrReplace);
  Future<void> clearTransactions() => delete(localTransactions).go();

  // --- Housing Applications ---
  Future<List<CachedApplication>> getApplications() => select(cachedApplications).get();
  Future<void> insertApplication(CachedApplication app) => into(cachedApplications).insert(app, mode: InsertMode.insertOrReplace);
  Future<void> clearApplications() => delete(cachedApplications).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'swapeat_local.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
