import 'package:bloc_test/bloc_test.dart';
import 'package:cart_four_ways/cubit/cart_cubit.dart';
import 'package:cart_four_ways/models/cart.dart';
import 'package:cart_four_ways/services/checkout_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckoutApi extends Mock implements CheckoutApi {}

void main() {
  final keyboard = catalog.first;
  late MockCheckoutApi mockApi;

  setUp(() {
    mockApi = MockCheckoutApi();
  });

  blocTest<CartCubit, CartState>(
    'emits 3 states for add, add, applyCoupon SAVE10 ending with total 88.2',
    build: () => CartCubit(mockApi),
    act: (c) {
      c.add(keyboard);
      c.add(keyboard);
      c.applyCoupon('SAVE10');
    },
    expect: () => [
      CartState(lines: [CartLine(product: keyboard, qty: 1)]),
      CartState(lines: [CartLine(product: keyboard, qty: 2)]),
      CartState(lines: [CartLine(product: keyboard, qty: 2)], coupon: 'SAVE10'),
    ],
    verify: (c) => expect(c.state.total, 88.2),
  );

  blocTest<CartCubit, CartState>(
    'emits submitting then failure when CheckoutApi throws, keeping cart lines',
    setUp: () {
      when(
        () => mockApi.submit(any()),
      ).thenAnswer((_) async => throw const CheckoutException('Card declined'));
    },
    seed: () => CartState(lines: [CartLine(product: keyboard, qty: 1)]),
    build: () => CartCubit(mockApi),
    act: (c) => c.checkout(),
    expect: () => [
      CartState(
        lines: [CartLine(product: keyboard, qty: 1)],
        status: CheckoutStatus.submitting,
      ),
      CartState(
        lines: [CartLine(product: keyboard, qty: 1)],
        status: CheckoutStatus.failure,
        checkoutError: 'Card declined',
      ),
    ],
  );
}
