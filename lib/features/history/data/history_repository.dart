import '../../../core/database/database_service.dart';
import '../domain/history_entry.dart';

class HistoryRepository {
  Future<List<HistoryEntry>> getAll({int limit = 300}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(DatabaseService.historyTable, orderBy: 'created_at DESC', limit: limit);
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> add(HistoryEntry e) async {
    final db = await DatabaseService.instance.database;
    await db.insert(DatabaseService.historyTable, e.toMap()..remove('id'));
  }

  Future<void> delete(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(DatabaseService.historyTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await DatabaseService.instance.database;
    await db.delete(DatabaseService.historyTable);
  }
}
