import 'package:flutter_test/flutter_test.dart';
import 'package:glow_booking/theme.dart';

void main() {
  test('formatters', () {
    expect(time12('09:00'), '9:00 AM');
    expect(time12('13:15'), '1:15 PM');
    expect(time12('00:30'), '12:30 AM');
    expect(duration(90), '1h 30m');
    expect(duration(45), '45 min');
  });
}
