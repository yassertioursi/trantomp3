import 'package:flutter_test/flutter_test.dart';

import 'package:trantomp3/main.dart';

void main() {
  testWidgets('App builds and shows TRANTOMP3 title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const Trantomp3App());
    expect(find.text('TRANTOMP3'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
