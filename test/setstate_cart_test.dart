import 'package:cart_four_ways/setstate/cart_page_setstate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tapping Keyboard twice and applying SAVE10 displays 88.20', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SetStateCartPage()));

    final keyboardChip = find.text('Keyboard · 49');
    await tester.tap(keyboardChip);
    await tester.pump();
    await tester.tap(keyboardChip);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'SAVE10');
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(find.text('88.20'), findsOneWidget);
  });
}
