import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';

void main() {
  test('plugin diagnostics accept the current single-root layout shape', () {
    final nodes = debugLayoutNodes({
      'type': 'Column',
      'props': <String, Object?>{},
    });

    expect(nodes, hasLength(1));
    expect(nodes.single['type'], 'Column');
  });

  test('plugin diagnostics keep accepting the legacy layout list', () {
    final nodes = debugLayoutNodes([
      {'type': 'Text'},
      {'type': 'Button'},
    ]);

    expect(nodes.map((node) => node['type']), ['Text', 'Button']);
  });
}
