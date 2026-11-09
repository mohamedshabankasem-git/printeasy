import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../domain/default_templates.dart';
import '../domain/template_model.dart';

class TemplateRepository {
  Future<Database> get _db => DatabaseService.instance.database;

  Future<List<TemplateModel>> getAll() async {
    final rows = await (await _db).query(DatabaseService.templatesTable, orderBy: 'updated_at DESC');
    return rows.map(TemplateModel.fromMap).toList();
  }

  Future<int> insert(TemplateModel t) async =>
      (await _db).insert(DatabaseService.templatesTable, t.toMap()..remove('id'));

  Future<void> update(TemplateModel t) async {
    await (await _db).update(
      DatabaseService.templatesTable,
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<void> delete(int id) async {
    await (await _db).delete(DatabaseService.templatesTable, where: 'id = ?', whereArgs: [id]);
  }

  /// إنشاء قالب الفاتورة الافتراضي إن كانت القائمة فارغة
  Future<void> ensureDefaults() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseService.templatesTable}')) ??
        0;
    if (count == 0) {
      final now = DateTime.now();
      await insert(TemplateModel(
        name: 'فاتورة افتراضية',
        content: kDefaultInvoiceTemplate,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }
}
