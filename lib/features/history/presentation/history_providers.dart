import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/history_repository.dart';
import '../domain/history_entry.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() => ref.read(historyRepositoryProvider).getAll();

  Future<void> remove(int id) async {
    await ref.read(historyRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    await ref.read(historyRepositoryProvider).clear();
    ref.invalidateSelf();
  }
}
