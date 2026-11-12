import 'package:material_ui/material_ui.dart';
import '../models/cart.dart';

class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({
    super.key,
    required this.itemCount,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final int itemCount;
  final double subtotal;
  final double discount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRow(label: 'Items', value: '$itemCount'),
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'Subtotal',
              value: subtotal.toStringAsFixed(2),
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'Discount',
              value: '-${discount.toStringAsFixed(2)}',
            ),
            const Divider(height: 16),
            _SummaryRow(
              label: 'Total',
              value: total.toStringAsFixed(2),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class CartBody extends StatelessWidget {
  const CartBody({
    super.key,
    required this.lines,
    required this.couponError,
    required this.status,
    required this.itemCount,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.onAdd,
    required this.onQtyChanged,
    required this.onApplyCoupon,
    required this.onCheckout,
    this.summary,
  });

  final List<CartLine> lines;
  final String? couponError;
  final CheckoutStatus status;
  final int itemCount;
  final double subtotal;
  final double discount;
  final double total;
  final void Function(Product) onAdd;
  final void Function(String productId, int delta) onQtyChanged;
  final void Function(String code) onApplyCoupon;
  final VoidCallback onCheckout;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in catalog)
                ActionChip(
                  label: Text('${p.name} · ${p.price.toStringAsFixed(0)}'),
                  onPressed: () => onAdd(p),
                ),
            ],
          ),
        ),
        Expanded(
          child: lines.isEmpty
              ? const Center(child: Text('Cart is empty'))
              : ListView(
                  children: [
                    for (final l in lines)
                      ListTile(
                        key: ValueKey(l.product.id),
                        title: Text(l.product.name),
                        subtitle: Text(
                          '× ${l.qty} · ${l.subtotal.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('dec_${l.product.id}'),
                              icon: const Icon(Icons.remove),
                              tooltip: 'Decrease ${l.product.name}',
                              onPressed: () => onQtyChanged(l.product.id, -1),
                            ),
                            Text('${l.qty}'),
                            IconButton(
                              key: ValueKey('inc_${l.product.id}'),
                              icon: const Icon(Icons.add),
                              tooltip: 'Increase ${l.product.name}',
                              onPressed: () => onQtyChanged(l.product.id, 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _CouponField(couponError: couponError, onApply: onApplyCoupon),
        summary ??
            CartSummaryCard(
              itemCount: itemCount,
              subtotal: subtotal,
              discount: discount,
              total: total,
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: lines.isEmpty ? null : onCheckout,
              child: status == CheckoutStatus.submitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Checkout'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponField extends StatefulWidget {
  const _CouponField({required this.couponError, required this.onApply});

  final String? couponError;
  final void Function(String code) onApply;

  @override
  State<_CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<_CouponField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Coupon code',
                hintText: 'SAVE10',
                errorText: widget.couponError,
                errorStyle: errorStyle,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => widget.onApply(_controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

