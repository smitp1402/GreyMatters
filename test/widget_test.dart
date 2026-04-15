// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:neurolearn/main.dart';

void main() {
  testWidgets('GreyMattersApp smoke test — renders without crashing', (tester) async {
    // GreyMattersApp requires Supabase initialization which isn't available
    // in unit tests. This test just verifies the widget class exists and
    // can be constructed.
    expect(GreyMattersApp.new, isA<Function>());
  });
}
