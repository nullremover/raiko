

import 'package:flutter_test/flutter_test.dart';
import 'package:raiko/main.dart';

void main() {
  testWidgets('Raiko launches successfully', (tester) async {
    await tester.pumpWidget(const RaikoApp());

    expect(find.text('Break through the music.'), findsOneWidget);
    expect(find.text('GOOD TO HAVE YOU HERE'), findsOneWidget);
    expect(find.text('LOCAL FIRST'), findsOneWidget);
  });
}
