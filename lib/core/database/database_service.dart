import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// خدمة قاعدة البيانات (Singleton): جدول القوالب وجدول سجل الطباعة
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String templatesTable = 'templates';
  static const String historyTable = 'print_history';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'printeasy.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $templatesTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'dsl',   -- dsl أو visual
            content TEXT NOT NULL,              -- نص DSL أو JSON للمحرر المرئي
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $historyTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,              -- النص النهائي بعد تعويض المتغيرات (لإعادة الطباعة)
            status TEXT NOT NULL,               -- success أو failed
            error TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }
}
