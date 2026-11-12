import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';

final checkoutApiProvider = Provider<CheckoutApi>((ref) => CheckoutApi());

class CartNotifier extends Notifier<CartState> {
  final _history = <CartState>[];

  @override
  CartState build() {
    _history.clear();
    return const CartState();
  }

  void _mutate(CartState Function(CartState) update) {
    final next = update(state);
    if (next == state) {
      state = next;
      return;
    }
    _history.add(state.copyWith(history: const []));
    state = next.copyWith(history: List.unmodifiable(_history));
  }

  void add(Product p) => _mutate((s) => s.withProduct(p));

  void changeQty(String id, int delta) =>
      _mutate((s) => s.withQtyChanged(id, delta));

  void applyCoupon(String code) => _mutate((s) => s.withCoupon(code));

  void undo() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    state = previous.copyWith(history: List.unmodifiable(_history));
  }

  Future<void> checkout() async {
    final api = ref.read(checkoutApiProvider);
    state = state.copyWith(
      status: CheckoutStatus.submitting,
      orderId: null,
      checkoutError: null,
    );
    try {
      final orderId = await api.submit(state.total);
      _history.clear();
      state = CartState(status: CheckoutStatus.success, orderId: orderId);
    } on CheckoutException catch (e) {
      state = state.copyWith(
        status: CheckoutStatus.failure,
        checkoutError: e.message,
      );
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

final canUndoProvider = Provider<bool>(
  (ref) => ref.watch(cartProvider.select((s) => s.history.isNotEmpty)),
);
