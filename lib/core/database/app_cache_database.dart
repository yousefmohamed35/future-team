import 'dart:convert';

import 'package:future_app/core/models/banner_model.dart';
import 'package:future_app/features/courses/data/models/courses_model.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppCacheDatabase {
  AppCacheDatabase._internal();
  static final AppCacheDatabase instance = AppCacheDatabase._internal();

  static const _dbName = 'app_cache.db';
  static const _dbVersion = 3;

  static const String coursesTable = 'courses_cache';
  static const String bannersTable = 'banners_cache';
  static const String endpointCacheTable = 'endpoint_cache';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $coursesTable(
            id TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            grade INTEGER,
            is_free INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $bannersTable(
            id TEXT NOT NULL,
            source TEXT NOT NULL,
            json TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (source, id)
          )
        ''');
        await db.execute('''
          CREATE TABLE $endpointCacheTable(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $bannersTable(
              id TEXT PRIMARY KEY,
              json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $endpointCacheTable(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          try {
            await db.execute(
                'ALTER TABLE $bannersTable ADD COLUMN source TEXT DEFAULT \'courses\'');
            await db.rawUpdate(
              'UPDATE $bannersTable SET source = ? WHERE source IS NULL',
              ['courses'],
            );
          } catch (_) {
            // Recreate banners with source if alter fails
            await db.execute('DROP TABLE IF EXISTS ${bannersTable}_old');
            await db.execute(
                'ALTER TABLE $bannersTable RENAME TO ${bannersTable}_old');
            await db.execute('''
              CREATE TABLE $bannersTable(
                id TEXT NOT NULL,
                source TEXT NOT NULL,
                json TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (source, id)
              )
            ''');
            final rows = await db.query('${bannersTable}_old');
            for (final row in rows) {
              await db.insert(bannersTable, {
                'id': row['id'],
                'source': 'courses',
                'json': row['json'],
                'updated_at': row['updated_at'],
              });
            }
            await db.execute('DROP TABLE ${bannersTable}_old');
          }
        }
      },
    );
  }

  /// Save/replace all courses from latest API response.
  Future<void> upsertCourses(List<CourseModel> courses) async {
    if (courses.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final course in courses) {
      batch.insert(
        coursesTable,
        {
          'id': course.id,
          'json': jsonEncode(course.toJson()),
          'grade': course.grade,
          'is_free': course.isFree ? 1 : 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Load cached courses, optionally filtered by grade id.
  ///
  /// This is used when there is no internet or the API fails.
  Future<List<CourseModel>> getCachedCourses({int? filtersLevels}) async {
    final db = await database;

    List<Map<String, Object?>> rows;
    if (filtersLevels != null) {
      rows = await db.query(
        coursesTable,
        where: 'grade = ?',
        whereArgs: [filtersLevels],
      );
    } else {
      rows = await db.query(coursesTable);
    }

    if (rows.isEmpty) return [];

    final List<CourseModel> courses = [];
    for (final row in rows) {
      final jsonString = row['json'] as String?;
      if (jsonString == null) continue;
      try {
        final Map<String, dynamic> map =
            jsonDecode(jsonString) as Map<String, dynamic>;
        courses.add(CourseModel.fromJson(map));
      } catch (_) {
        // Ignore corrupted rows
      }
    }

    return courses;
  }

  /// Save/replace all banners from latest API response.
  /// [source] e.g. 'courses', 'home', 'college'
  Future<void> upsertBanners(String source, List<BannerModel> banners) async {
    if (banners.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < banners.length; i++) {
      final banner = banners[i];
      final id = banner.id ?? 'b_${now}_$i';
      batch.insert(
        bannersTable,
        {
          'id': id,
          'source': source,
          'json': jsonEncode(banner.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Load cached banners for offline mode.
  /// [source] e.g. 'courses', 'home', 'college'
  Future<List<BannerModel>> getCachedBanners(
      [String source = 'courses']) async {
    final db = await database;
    final rows = await db.query(
      bannersTable,
      where: 'source = ?',
      whereArgs: [source],
    );
    if (rows.isEmpty) return [];

    final List<BannerModel> banners = [];
    for (final row in rows) {
      final jsonString = row['json'] as String?;
      if (jsonString == null) continue;
      try {
        final Map<String, dynamic> map =
            jsonDecode(jsonString) as Map<String, dynamic>;
        banners.add(BannerModel.fromJson(map));
      } catch (_) {
        // Ignore corrupted rows
      }
    }
    return banners;
  }

  /// Store any endpoint response as JSON for offline fallback.
  Future<void> putEndpoint(String key, Map<String, dynamic> json) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      endpointCacheTable,
      {
        'key': key,
        'value': jsonEncode(json),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Read cached endpoint response. Returns null if not found or invalid.
  Future<Map<String, dynamic>?> getEndpoint(String key) async {
    final db = await database;
    final rows = await db.query(
      endpointCacheTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
