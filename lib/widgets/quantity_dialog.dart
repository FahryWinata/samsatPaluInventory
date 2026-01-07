import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

class QuantityDialog extends StatefulWidget {
  final String itemName;
  final int currentQuantity;
  final bool isIncrease;

  const QuantityDialog({
    super.key,
    required this.itemName,
    required this.currentQuantity,
    required this.isIncrease,
  });

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _controller = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(int.parse(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isIncrease ? AppColors.success : AppColors.error;
    final icon = widget.isIncrease ? Icons.add_circle : Icons.remove_circle;
    final title = widget.isIncrease ? 'Increase Quantity' : 'Decrease Quantity';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.itemName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Current quantity: ${widget.currentQuantity}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Amount to ${widget.isIncrease ? "add" : "remove"}',
                hintText: '1',
                prefixIcon: Icon(Icons.numbers, color: color),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = int.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter valid amount';
                }
                if (!widget.isIncrease && amount > widget.currentQuantity) {
                  return 'Cannot remove more than current quantity';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: Text(context.t('confirm')),
        ),
      ],
    );
  }
}
