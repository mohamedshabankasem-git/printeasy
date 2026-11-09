import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/template_repository.dart';
import '../domain/template_model.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) => TemplateRepository());

final templatesProvider =
    AsyncNotifierProvider<TemplatesNotifier, List<TemplateModel>>(TemplatesNotifier.new);

class TemplatesNotifier extends AsyncNotifier<List<TemplateModel>> {
  @override
  Future<List<TemplateModel>> build() => ref.read(templateRepositoryProvider).getAll();

  Future<void> save(TemplateModel t) async {
    final repo = ref.read(templateRepositoryProvider);
    if (t.id == null) {
      await repo.insert(t);
    } else {
      await repo.update(t);
    }
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int id) async {
    await ref.read(templateRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}
