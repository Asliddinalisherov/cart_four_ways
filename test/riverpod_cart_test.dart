import 'package:cart_four_ways/models/cart.dart';
import 'package:cart_four_ways/riverpod/cart_notifier.dart';
import 'package:cart_four_ways/services/checkout_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckoutApi extends Mock implements CheckoutApi {}

void main() {
  test('adding Keyboard twice and applying SAVE10 yields total 88.2', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final keyboard = catalog.first;
    final notifier = container.read(cartProvider.notifier);
    notifier.add(keyboard);
    notifier.add(keyboard);
    notifier.applyCoupon('SAVE10');

    expect(container.read(cartProvider).total, 88.2);
  });

  test('checkout failure sets failure status and preserves cart lines', () async {
    final mockApi = MockCheckoutApi();
    when(
      () => mockApi.submit(any()),
    ).thenAnswer((_) async => throw const CheckoutException('Card declined'));

    final container = ProviderContainer(
      overrides: [checkoutApiProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);

    final keyboard = catalog.first;
    final notifier = container.read(cartProvider.notifier);
    notifier.add(keyboard);

    await notifier.checkout();

    final state = container.read(cartProvider);
    expect(state.status, CheckoutStatus.failure);
    expect(state.checkoutError, 'Card declined');
    expect(state.lines, [CartLine(product: keyboard, qty: 1)]);
  });
}
