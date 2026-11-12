import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import 'cart_event.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this.api) : super(const CartState()) {
    on<CartProductAdded>(_onMutation);
    on<CartQtyChanged>(_onMutation);
    on<CartCouponApplied>(_onMutation);
    on<CartUndone>(_onMutation);
    on<CartCheckoutRequested>(_onCheckout, transformer: droppable());
  }

  final CheckoutApi api;

  void _onMutation(CartEvent event, Emitter<CartState> emit) {
    final next = switch (event) {
      CartProductAdded(:final product) => state.withProduct(product),
      CartQtyChanged(:final productId, :final delta) =>
        state.withQtyChanged(productId, delta),
      CartCouponApplied(:final code) => state.withCoupon(code),
      CartUndone() => state.undoLast(),
      CartCheckoutRequested() => state,
    };

    final shouldRecordHistory = switch (event) {
      CartProductAdded() || CartQtyChanged() || CartCouponApplied() => true,
      CartCheckoutRequested() || CartUndone() => false,
    };

    emit(shouldRecordHistory ? state.recordMutation(next) : next);
  }

  Future<void> _onCheckout(
    CartCheckoutRequested event,
    Emitter<CartState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CheckoutStatus.submitting,
        orderId: null,
        checkoutError: null,
      ),
    );
    try {
      final orderId = await api.submit(state.total);
      if (emit.isDone) return;
      emit(CartState(status: CheckoutStatus.success, orderId: orderId));
    } on CheckoutException catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          checkoutError: e.message,
        ),
      );
    }
  }
}
