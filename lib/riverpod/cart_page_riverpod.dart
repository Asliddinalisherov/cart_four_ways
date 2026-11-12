import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/cart.dart';
import '../widgets/cart_body.dart';
import 'cart_notifier.dart';

class RiverpodCartPage extends ConsumerWidget {
  const RiverpodCartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CheckoutStatus>(cartProvider.select((s) => s.status), (
      prev,
      next,
    ) {
      final messenger = ScaffoldMessenger.of(context);
      if (next == CheckoutStatus.submitting) {
        messenger.clearMaterialBanners();
      } else if (next == CheckoutStatus.success) {
        final orderId = ref.read(cartProvider).orderId;
        messenger.showSnackBar(
          SnackBar(content: Text('Order placed: $orderId')),
        );
      } else if (next == CheckoutStatus.failure) {
        final error = ref.read(cartProvider).checkoutError;
        messenger.showMaterialBanner(
          MaterialBanner(
            content: Text('Checkout failed: $error'),
            actions: [
              TextButton(
                onPressed: messenger.hideCurrentMaterialBanner,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    });

    final state = ref.watch(cartProvider);
    final canUndo = ref.watch(canUndoProvider);
    final cart = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart · Riverpod'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: canUndo ? cart.undo : null,
          ),
        ],
      ),
      body: CartBody(
        lines: state.lines,
        couponError: state.couponError,
        status: state.status,
        itemCount: state.itemCount,
        subtotal: state.subtotal,
        discount: state.discount,
        total: state.total,
        onAdd: cart.add,
        onQtyChanged: cart.changeQty,
        onApplyCoupon: cart.applyCoupon,
        onCheckout: cart.checkout,
        summary: const _RiverpodSummaryCard(),
      ),
    );
  }
}

class _RiverpodSummaryCard extends ConsumerWidget {
  const _RiverpodSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (itemCount, subtotal, discount, total) = ref.watch(
      cartProvider.select(
        (s) => (s.itemCount, s.subtotal, s.discount, s.total),
      ),
    );
    debugPrint('RiverpodSummaryCard build: total=$total');
    return CartSummaryCard(
      itemCount: itemCount,
      subtotal: subtotal,
      discount: discount,
      total: total,
    );
  }
}
