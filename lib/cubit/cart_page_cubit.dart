import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../models/cart.dart';
import '../services/checkout_api.dart';
import '../widgets/cart_body.dart';
import 'cart_cubit.dart';

class CubitCartPage extends StatelessWidget {
  const CubitCartPage({super.key, this.api});

  final CheckoutApi? api;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CartCubit(api ?? CheckoutApi()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cart · Cubit'),
          actions: [
            BlocSelector<CartCubit, CartState, bool>(
              selector: (s) => s.canUndo,
              builder: (context, canUndo) => IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
                onPressed: canUndo ? context.read<CartCubit>().undo : null,
              ),
            ),
          ],
        ),
        body: BlocListener<CartCubit, CartState>(
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
          child: BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final cubit = context.read<CartCubit>();
              return CartBody(
                lines: state.lines,
                couponError: state.couponError,
                status: state.status,
                itemCount: state.itemCount,
                subtotal: state.subtotal,
                discount: state.discount,
                total: state.total,
                onAdd: cubit.add,
                onQtyChanged: cubit.changeQty,
                onApplyCoupon: cubit.applyCoupon,
                onCheckout: cubit.checkout,
                summary: const _CubitSummaryCard(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CubitSummaryCard extends StatelessWidget {
  const _CubitSummaryCard();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CartCubit,
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
        debugPrint('CubitSummaryCard build: total=${summary.total}');
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
