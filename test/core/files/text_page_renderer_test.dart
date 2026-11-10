import 'package:flutter_test/flutter_test.dart';
import 'package:printeasy/core/files/text_page_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders RTL text into PNG at the requested thermal width', () async {
    final pages = await TextPageRenderer.render(
      const ['فاتورة تجريبية', 'Total 125.50', ''],
      widthDots: 384,
    );

    expect(pages, isNotEmpty);
    expect(pages.first.length, greaterThan(8));
    expect(pages.first.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('rejects invalid paper width', () async {
    expect(
      TextPageRenderer.render(const ['test'], widthDots: 0),
      throwsArgumentError,
    );
  });
}
