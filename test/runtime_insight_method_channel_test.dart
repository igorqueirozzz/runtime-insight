import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_insight/device/device_specs.dart';
import 'package:runtime_insight/runtime_insight_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelRuntimeInsight();
  const MethodChannel channel = MethodChannel('runtime_insight/device_specs');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return <String, dynamic>{
            'cpuCores': 8,
            'ramMb': 6144,
            'osVersion': 34,
            'performanceClass': 2,
            'isEmulator': false,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('collectDeviceSpecs maps values correctly', () async {
    final specs = await platform.collectDeviceSpecs();
    expect(specs.platform, DevicePlatform.android);
    expect(specs.cpuCores, 8);
    expect(specs.ramMb, 6144);
    expect(specs.osVersion, 34);
    expect(specs.performanceClass, 2);
    expect(specs.isEmulator, false);
  });
}
