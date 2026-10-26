
import 'package:flutter_test/flutter_test.dart';
import 'package:mishv3/app/mish_app.dart';

void main() {
  testWidgets('Mish app can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(const MishApp());

    expect(find.byType(MishApp), findsOneWidget);
  });
}
