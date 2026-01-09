import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

class QuantityResult {
  final int amount;
  final String? notes;

  QuantityResult(this.amount, this.notes);
}

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
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        QuantityResult(
          int.parse(_controller.text),
          _notesController.text.isEmpty ? null : _notesController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isIncrease ? AppColors.success : AppColors.error;
    final icon = widget.isIncrease ? Icons.add_circle : Icons.remove_circle;
    final title = widget.isIncrease
        ? context.t('add_stock')
        : context.t('reduce_stock');

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.t('quantity')}: ${widget.currentQuantity}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: context.t('quantity'),
                  hintText: '1',
                  prefixIcon: Icon(Icons.numbers, color: color),
                  border: const OutlineInputBorder(),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (Opsional)',
                  hintText: 'Contoh: Diambil oleh Budi / Stok masuk supplier',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
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
