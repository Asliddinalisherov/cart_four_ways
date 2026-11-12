import 'package:material_ui/material_ui.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';

class SetStateCartPage extends StatefulWidget {
  const SetStateCartPage({super.key, this.api});

  final CheckoutApi? api;

  @override
  State<SetStateCartPage> createState() => _SetStateCartPageState();
}

class _SetStateCartPageState extends State<SetStateCartPage> {
  late final CheckoutApi _api = widget.api ?? CheckoutApi();
  CartState _state = const CartState();
  final List<CartState> _history = [];

  void _mutate(CartState Function(CartState) update) {
    final next = update(_state);
    if (next == _state) return;
    setState(() {
      _history.add(_state);
      _state = next;
    });
  }

  void _add(Product p) => _mutate((s) => s.withProduct(p));

  void _changeQty(String id, int delta) =>
      _mutate((s) => s.withQtyChanged(id, delta));

  void _applyCoupon(String code) => _mutate((s) => s.withCoupon(code));

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _state = _history.removeLast());
  }

  Future<void> _checkout() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    setState(() {
      _state = _state.copyWith(
        status: CheckoutStatus.submitting,
        orderId: null,
        checkoutError: null,
      );
    });

    try {
      final orderId = await _api.submit(_state.total);
      if (!mounted) return;
      setState(() {
        _history.clear();
        _state = CartState(status: CheckoutStatus.success, orderId: orderId);
      });
      messenger.showSnackBar(SnackBar(content: Text('Order placed: $orderId')));
    } on CheckoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          status: CheckoutStatus.failure,
          checkoutError: e.message,
        );
      });
      messenger.showMaterialBanner(
        MaterialBanner(
          content: Text('Checkout failed: ${e.message}'),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart · setState'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _history.isEmpty ? null : _undo,
          ),
        ],
      ),
      body: CartBody(
        lines: _state.lines,
        couponError: _state.couponError,
        status: _state.status,
        itemCount: _state.itemCount,
        subtotal: _state.subtotal,
        discount: _state.discount,
        total: _state.total,
        onAdd: _add,
        onQtyChanged: _changeQty,
        onApplyCoupon: _applyCoupon,
        onCheckout: _checkout,
      ),
    );
  }
}
