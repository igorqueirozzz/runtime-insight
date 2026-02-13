// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:runtime_insight/runtime_insight.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runtime insight init test', (WidgetTester tester) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    await RuntimeInsight.init();

    final isAnyTier =
        RuntimeInsight.isLowEnd ||
        RuntimeInsight.isMidEnd ||
        RuntimeInsight.isHighEnd;

    expect(isAnyTier, true);
    final parallel = RuntimeInsight.maxParallelRecommended;
    expect([1, 3, 6].contains(parallel.cpu), true);
    expect([2, 6, 12].contains(parallel.io), true);
    expect([2, 4, 8].contains(parallel.network), true);
  });
}
