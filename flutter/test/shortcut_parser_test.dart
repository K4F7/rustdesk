import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/widgets/custom_shortcuts.dart';

void main() {
  test('parseShortcutKeyString maps modifiers and keys', () {
    expect(
      parseShortcutKeyString('Ctrl+Alt+Delete'),
      ['VK_CONTROL', 'VK_MENU', 'VK_DELETE'],
    );
  });

  test('parseShortcutKeyString normalizes input tokens', () {
    expect(
      parseShortcutKeyString('ctrl+v'),
      ['VK_CONTROL', 'VK_V'],
    );
  });

  test('describeShortcutKeys returns readable labels', () {
    expect(
      describeShortcutKeys(['VK_CONTROL', 'VK_SHIFT', 'VK_C']),
      'Ctrl+Shift+C',
    );
  });
}
