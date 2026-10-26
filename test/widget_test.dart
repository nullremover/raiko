
import 'package:flutter_test/flutter_test.dart';
import 'package:raiko/main.dart';

void main() {
  testWidgets('Raiko launches successfully', (tester) async {
    await tester.pumpWidget(const RaikoApp());

    expect(find.text('raiko'), findsWidgets);
    expect(find.text('Beyond the ordinary.'), findsOneWidget);
  });
}
