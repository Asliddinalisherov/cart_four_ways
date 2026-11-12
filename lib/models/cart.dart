import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final double price;

  @override
  List<Object?> get props => [id, name, price];
}

const catalog = [
  Product(id: 'p1', name: 'Keyboard', price: 49),
  Product(id: 'p2', name: 'Mouse', price: 25),
  Product(id: 'p3', name: 'Monitor', price: 199),
];

class CartLine extends Equatable {
  const CartLine({required this.product, required this.qty});

  final Product product;
  final int qty;

  double get subtotal => product.price * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);

  @override
  List<Object?> get props => [product, qty];
}

/// Pure, style-independent cart line helpers.
extension CartLines on List<CartLine> {
  List<CartLine> withProduct(Product p) {
    final i = indexWhere((l) => l.product.id == p.id);
    if (i == -1) return [...this, CartLine(product: p, qty: 1)];
    return [
      for (final l in this)
        l.product.id == p.id ? l.copyWith(qty: l.qty + 1) : l,
    ];
  }

  List<CartLine> without(String productId) => [
    for (final l in this)
      if (l.product.id != productId) l,
  ];

  List<CartLine> changeQty(String id, int delta) => [
    for (final l in this)
      if (l.product.id != id)
        l
      else if (l.qty + delta > 0)
        l.copyWith(qty: l.qty + delta),
  ];

  double get subtotal => fold(0.0, (s, l) => s + l.subtotal);

  int get itemCount => fold(0, (s, l) => s + l.qty);
}

enum CheckoutStatus { idle, submitting, success, failure }

const _unset = Object();

class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.coupon,
    this.couponError,
    this.status = CheckoutStatus.idle,
    this.orderId,
    this.checkoutError,
    this.history = const [],
  });

  final List<CartLine> lines;
  final String? coupon;
  final String? couponError;
  final CheckoutStatus status;
  final String? orderId;
  final String? checkoutError;
  final List<CartState> history;

  int get itemCount => lines.itemCount;
  double get subtotal => lines.subtotal;
  double get discount => coupon == 'SAVE10' ? subtotal * 0.1 : 0.0;
  double get total => subtotal - discount;
  bool get canUndo => history.isNotEmpty;

  CartState withProduct(Product p) => copyWith(
    lines: lines.withProduct(p),
    status: CheckoutStatus.idle,
    orderId: null,
    checkoutError: null,
  );

  CartState withQtyChanged(String id, int delta) => copyWith(
    lines: lines.changeQty(id, delta),
    status: CheckoutStatus.idle,
    orderId: null,
    checkoutError: null,
  );

  CartState withCoupon(String rawCode) {
    final code = rawCode.trim();
    if (code == 'SAVE10') {
      return copyWith(
        coupon: code,
        couponError: null,
        status: CheckoutStatus.idle,
        orderId: null,
        checkoutError: null,
      );
    }
    return copyWith(
      coupon: null,
      couponError: 'Invalid coupon code',
      status: CheckoutStatus.idle,
      orderId: null,
      checkoutError: null,
    );
  }

  CartState recordMutation(CartState next) {
    if (next == this) return this;
    return next.copyWith(history: [...history, copyWith(history: const [])]);
  }

  CartState undoLast() {
    if (!canUndo) return this;
    final previous = history.last;
    return previous.copyWith(history: history.sublist(0, history.length - 1));
  }

  CartState copyWith({
    List<CartLine>? lines,
    Object? coupon = _unset,
    Object? couponError = _unset,
    CheckoutStatus? status,
    Object? orderId = _unset,
    Object? checkoutError = _unset,
    List<CartState>? history,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      coupon: identical(coupon, _unset) ? this.coupon : coupon as String?,
      couponError: identical(couponError, _unset)
          ? this.couponError
          : couponError as String?,
      status: status ?? this.status,
      orderId: identical(orderId, _unset) ? this.orderId : orderId as String?,
      checkoutError: identical(checkoutError, _unset)
          ? this.checkoutError
          : checkoutError as String?,
      history: history ?? this.history,
    );
  }

  @override
  List<Object?> get props => [
    lines,
    coupon,
    couponError,
    status,
    orderId,
    checkoutError,
  ];
}

