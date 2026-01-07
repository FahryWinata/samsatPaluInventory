import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/inventory_model.dart';
import '../utils/app_colors.dart';
import '../services/storage_service.dart';

class InventoryFormDialog extends StatefulWidget {
  final InventoryItem? item;

  const InventoryFormDialog({super.key, this.item});

  @override
  State<InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<InventoryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _minStockController;
  late TextEditingController _descController;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '',
    );
    _unitController = TextEditingController(text: widget.item?.unit ?? '');
    _minStockController = TextEditingController(
      text: widget.item?.minimumStock.toString() ?? '',
    );
    _descController = TextEditingController(
      text: widget.item?.description ?? '',
    );
    _imagePath = widget.item?.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _minStockController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() => _isUploading = true);

        final sourceFile = File(pickedFile.path);
        // Upload to Supabase
        final url = await _storageService.uploadImage(sourceFile);

        if (mounted) {
          setState(() {
            _imagePath = url;
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking/uploading image: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload gambar: $e')));
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // 1. Logic: If unit is empty, default to "pcs"
      String finalUnit = _unitController.text.trim();
      if (finalUnit.isEmpty) {
        finalUnit = 'pcs';
      }

      final newItem = InventoryItem(
        id: widget.item?.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 0,
        unit: finalUnit, // Use the processed unit
        minimumStock: int.tryParse(_minStockController.text) ?? 5,
        imagePath: _imagePath,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Navigator.pop(context, newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 400, // Fixed width for better look on desktop
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: () => _showImageSourceActionSheet(context),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: _imagePath != null && !_isUploading
                            ? DecorationImage(
                                image: _imagePath!.startsWith('http')
                                    ? NetworkImage(_imagePath!)
                                    : FileImage(File(_imagePath!))
                                          as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imagePath == null && !_isUploading
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo, color: Colors.grey),
                                SizedBox(height: 4),
                                Text(
                                  'Add Image',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : null,
                    ),
                  ),
                ),
                if (_imagePath != null)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _imagePath = null),
                      child: const Text(
                        'Remove Image',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g. A4 Paper',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Row for Quantity and Unit
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'Default: pcs', // Visual hint for the user
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Row for Min Stock
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Stock Threshold',
                    hintText: 'Alert when quantity below this',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            context.t('cancel'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(isEditing ? 'Save Changes' : 'Add Product'),
        ),
      ],
    );
  }
}
