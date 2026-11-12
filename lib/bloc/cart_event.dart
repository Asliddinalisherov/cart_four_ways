import '../models/cart.dart';

sealed class CartEvent {
  const CartEvent();
}

final class CartProductAdded extends CartEvent {
  const CartProductAdded(this.product);

  final Product product;
}

final class CartQtyChanged extends CartEvent {
  const CartQtyChanged(this.productId, this.delta);

  final String productId;
  final int delta;
}

final class CartCouponApplied extends CartEvent {
  const CartCouponApplied(this.code);

  final String code;
}

final class CartCheckoutRequested extends CartEvent {
  const CartCheckoutRequested();
}

final class CartUndone extends CartEvent {
  const CartUndone();
}
