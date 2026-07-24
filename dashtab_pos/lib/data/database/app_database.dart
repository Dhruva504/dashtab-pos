// Placeholder for Drift database
// We will generate the actual database once dependencies are installed.

import 'package:drift/drift.dart';
// import 'dart:io';
// import 'package:drift/native.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;

// part 'app_database.g.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  
  @override
  Set<Column> get primaryKey => {id};
}

// @DriftDatabase(tables: [Products])
class AppDatabase /* extends _$AppDatabase */ {
  // AppDatabase() : super(_openConnection());
  
  // @override
  // int get schemaVersion => 1;
}

// LazyDatabase _openConnection() {
//   return LazyDatabase(() async {
//     final dbFolder = await getApplicationDocumentsDirectory();
//     final file = File(p.join(dbFolder.path, 'db.sqlite'));
//     return NativeDatabase.createInBackground(file);
//   });
// }
