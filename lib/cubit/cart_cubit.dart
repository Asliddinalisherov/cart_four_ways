import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit(this.api) : super(const CartState());

  final CheckoutApi api;

  void _mutate(CartState Function(CartState) update) =>
      emit(state.recordMutation(update(state)));

  void add(Product p) => _mutate((s) => s.withProduct(p));

  void changeQty(String id, int delta) =>
      _mutate((s) => s.withQtyChanged(id, delta));

  void applyCoupon(String code) => _mutate((s) => s.withCoupon(code));

  void undo() => emit(state.undoLast());

  Future<void> checkout() async {
    emit(
      state.copyWith(
        status: CheckoutStatus.submitting,
        orderId: null,
        checkoutError: null,
      ),
    );
    try {
      final orderId = await api.submit(state.total);
      if (isClosed) return;
      emit(CartState(status: CheckoutStatus.success, orderId: orderId));
    } on CheckoutException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          checkoutError: e.message,
        ),
      );
    }
  }

  @override
  void onChange(Change<CartState> change) {
    super.onChange(change);
    debugPrint(
      'CartCubit onChange: ${change.currentState.status} -> ${change.nextState.status} (total=${change.nextState.total})',
    );
  }
}
