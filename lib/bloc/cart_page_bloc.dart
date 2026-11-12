import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';
import 'cart_bloc.dart';
import 'cart_event.dart';

class BlocCartPage extends StatelessWidget {
  const BlocCartPage({super.key, this.api});

  final CheckoutApi? api;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CartBloc(api ?? CheckoutApi()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cart · Bloc'),
          actions: [
            BlocSelector<CartBloc, CartState, bool>(
              selector: (s) => s.canUndo,
              builder: (context, canUndo) => IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
                onPressed: canUndo
                    ? () => context.read<CartBloc>().add(const CartUndone())
                    : null,
              ),
            ),
          ],
        ),
        body: BlocListener<CartBloc, CartState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            if (state.status == CheckoutStatus.submitting) {
              messenger.clearMaterialBanners();
            } else if (state.status == CheckoutStatus.success) {
              messenger.showSnackBar(
                SnackBar(content: Text('Order placed: ${state.orderId}')),
              );
            } else if (state.status == CheckoutStatus.failure) {
              messenger.showMaterialBanner(
                MaterialBanner(
                  content: Text('Checkout failed: ${state.checkoutError}'),
                  actions: [
                    TextButton(
                      onPressed: messenger.hideCurrentMaterialBanner,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              );
            }
          },
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              final bloc = context.read<CartBloc>();
              return CartBody(
                lines: state.lines,
                couponError: state.couponError,
                status: state.status,
                itemCount: state.itemCount,
                subtotal: state.subtotal,
                discount: state.discount,
                total: state.total,
                onAdd: (p) => bloc.add(CartProductAdded(p)),
                onQtyChanged: (id, delta) =>
                    bloc.add(CartQtyChanged(id, delta)),
                onApplyCoupon: (code) => bloc.add(CartCouponApplied(code)),
                onCheckout: () => bloc.add(const CartCheckoutRequested()),
                summary: const _BlocSummaryCard(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlocSummaryCard extends StatelessWidget {
  const _BlocSummaryCard();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CartBloc,
      CartState,
      ({int itemCount, double subtotal, double discount, double total})
    >(
      selector: (s) => (
        itemCount: s.itemCount,
        subtotal: s.subtotal,
        discount: s.discount,
        total: s.total,
      ),
      builder: (context, summary) {
        debugPrint('BlocSummaryCard build: total=${summary.total}');
        return CartSummaryCard(
          itemCount: summary.itemCount,
          subtotal: summary.subtotal,
          discount: summary.discount,
          total: summary.total,
        );
      },
    );
  }
}
