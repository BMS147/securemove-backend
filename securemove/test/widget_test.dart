import 'package:flutter_test/flutter_test.dart';
import 'package:secure_move/main.dart';

void main() {
  testWidgets('App starts with LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const SecureMoveApp());
    expect(find.text('Secure Move'), findsOneWidget);
  });
}
