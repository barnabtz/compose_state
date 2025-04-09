import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Persistable', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persist and restore int', () async {
      final vm = TestViewModel();

      await vm.persist('key', 42);
      final restored = await vm.restore<int>('key');

      expect(restored, 42);
    });

    test('persist and restore String', () async {
      final vm = TestViewModel();

      await vm.persist('key', 'hello');
      final restored = await vm.restore<String>('key');

      expect(restored, 'hello');
    });

    test('persist null clears key', () async {
      final vm = TestViewModel();

      await vm.persist('key', 42);
      expect(await vm.restore<int>('key'), 42);

      await vm.persist('key', null);
      expect(await vm.restore<int>('key'), null);
    });

    test('restore non-existent key returns null', () async {
      final vm = TestViewModel();

      final restored = await vm.restore<int>('non_existent');
      expect(restored, null);
    });

    test('persist and restore custom Serializable', () async {
      final vm = TestViewModel();
      final data = TestSerializable(value: 100);

      await vm.persist('key', data);
      final restored = await vm.restore<TestSerializable>(
        'key',
        fromJson: (json) => TestSerializable.fromJson(jsonDecode(json) as Map<String, dynamic>),
      );

      expect(restored?.value, 100);
    });
  });
}

class TestViewModel extends ComposeViewModel with Persistable {
  @override
  void dispose() {
    super.dispose(); // Call super.dispose() for ChangeNotifier
  }
}

class TestSerializable implements Serializable {
  final int value;

  TestSerializable({required this.value});

  @override
  Map<String, dynamic> toJson() => {'value': value};

  factory TestSerializable.fromJson(Map<String, dynamic> json) {
    return TestSerializable(value: json['value'] as int);
  }

  @override
  bool operator ==(Object other) => other is TestSerializable && value == other.value;

  @override
  int get hashCode => value.hashCode;
}