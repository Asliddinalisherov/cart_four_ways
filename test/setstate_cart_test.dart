import 'package:cart_four_ways/main.dart';
import 'package:cart_four_ways/models/cart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CartLines and CartState calculate derived totals', () {
    final kb = catalog.first;
    final state = const CartState().withProduct(kb).withProduct(kb).withCoupon('SAVE10');
    expect(state.itemCount, 2);
    expect(state.subtotal, 98.0);
    expect(state.discount, 9.8);
    expect(state.total, 88.2);
  });

  testWidgets('HomePage shows four navigation buttons', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CartFourWaysApp()));
    expect(find.text('1. setState'), findsOneWidget);
    expect(find.text('2. Riverpod'), findsOneWidget);
    expect(find.text('3. Cubit'), findsOneWidget);
    expect(find.text('4. Bloc'), findsOneWidget);
  });
}
