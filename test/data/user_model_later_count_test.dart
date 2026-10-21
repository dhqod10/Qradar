import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/models/user_model.dart';

void main() {
  group('UserModelFactory.parseLaterCount', () {
    test('absent / null -> 0', () {
      expect(UserModelFactory.parseLaterCount(null), 0);
    });
    test('int passes through', () {
      expect(UserModelFactory.parseLaterCount(2), 2);
    });
    test('double is truncated', () {
      expect(UserModelFactory.parseLaterCount(2.0), 2);
      expect(UserModelFactory.parseLaterCount(1.9), 1);
    });
    test('string -> 0', () {
      expect(UserModelFactory.parseLaterCount('2'), 0);
    });
    test('negative clamps to 0', () {
      expect(UserModelFactory.parseLaterCount(-1), 0);
      expect(UserModelFactory.parseLaterCount(-0.5), 0);
    });
    test('NaN / infinity -> 0', () {
      expect(UserModelFactory.parseLaterCount(double.nan), 0);
      expect(UserModelFactory.parseLaterCount(double.infinity), 0);
    });
  });
}
