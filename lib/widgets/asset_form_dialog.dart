import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/asset_model.dart';
import '../models/asset_category_model.dart';
import '../models/room_model.dart';
import '../utils/app_colors.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../services/room_service.dart';
import '../utils/extensions.dart';

class AssetFormDialog extends StatefulWidget {
  final Asset? asset;

  const AssetFormDialog({super.key, this.asset});

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _serialController;
  late TextEditingController _descriptionController;
  DateTime? _purchaseDate;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final CategoryService _categoryService = CategoryService();
  final RoomService _roomService = RoomService();
  bool _isUploading = false;

  // Category & Room state
  List<AssetCategory> _categories = [];
  List<Room> _rooms = [];
  int? _selectedCategoryId;
  int? _selectedRoomId;
  AssetCategory? _selectedCategory;

  bool get isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.asset?.name ?? '');
    _serialController = TextEditingController(
      text: widget.asset?.identifierValue ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.asset?.description ?? '',
    );
    _purchaseDate = widget.asset?.purchaseDate;
    _imagePath = widget.asset?.imagePath;
    _selectedCategoryId = widget.asset?.categoryId;
    _selectedRoomId = widget.asset?.assignedToRoomId;
    _loadCategoriesAndRooms();
  }

  Future<void> _loadCategoriesAndRooms() async {
    try {
      final categories = await _categoryService.getAllCategories();
      final rooms = await _roomService.getAllRooms();
      if (mounted) {
        setState(() {
          _categories = categories;
          _rooms = rooms;
          if (_selectedCategoryId != null) {
            _selectedCategory = categories
                .where((c) => c.id == _selectedCategoryId)
                .firstOrNull;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories/rooms: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() => _isUploading = true);

        // Delete old image if exists (when replacing)
        if (_imagePath != null && _imagePath!.startsWith('http')) {
          await _storageService.deleteImage(_imagePath);
        }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal upload gambar (Pastikan bucket "assets_image" ada): $e',
            ),
          ),
        );
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
      final now = DateTime.now();
      final asset = Asset(
        id: widget.asset?.id,
        name: _nameController.text.trim(),
        identifierValue: _serialController.text.trim().isEmpty
            ? null
            : _serialController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        purchaseDate: _purchaseDate,
        status: widget.asset?.status ?? 'available',
        currentHolderId: widget.asset?.currentHolderId,
        categoryId: _selectedCategoryId,
        assignedToRoomId: _selectedRoomId,
        imagePath: _imagePath,
        createdAt: widget.asset?.createdAt ?? now,
        updatedAt: now,
      );
      Navigator.of(context).pop(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.laptop_mac,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit Asset' : 'Add New Asset',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                        onPressed: () async {
                          // Delete from Supabase if it's a remote URL
                          if (_imagePath != null &&
                              _imagePath!.startsWith('http')) {
                            await _storageService.deleteImage(_imagePath);
                          }
                          setState(() => _imagePath = null);
                        },
                        child: const Text(
                          'Remove Image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Asset Name *',
                      hintText: 'e.g., MacBook Pro 2023',
                      prefixIcon: Icon(Icons.devices),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter asset name';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    hint: const Text('Pilih Kategori (Opsional)'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tidak Ada Kategori'),
                      ),
                      ..._categories.map(
                        (cat) => DropdownMenuItem<int?>(
                          value: cat.id,
                          child: Text(cat.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                        _selectedCategory = value != null
                            ? _categories
                                  .where((c) => c.id == value)
                                  .firstOrNull
                            : null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Identifier (optional, label changes based on category)
                  TextFormField(
                    controller: _serialController,
                    decoration: InputDecoration(
                      labelText:
                          _selectedCategory?.identifierLabel ?? 'Identifier',
                      hintText:
                          _selectedCategory?.identifierType == 'vehicle_id'
                          ? 'Contoh: DN 1234 AB'
                          : 'Contoh: SN-12345',
                      prefixIcon: const Icon(Icons.qr_code),
                      helperText: 'Opsional',
                    ),
                    textCapitalization:
                        _selectedCategory?.identifierType == 'vehicle_id'
                        ? TextCapitalization.characters
                        : TextCapitalization.none,
                  ),
                  const SizedBox(height: 16),

                  // Room Assignment (shown if category supports room)
                  if (_selectedCategory == null ||
                      _selectedCategory!.requiresRoom) ...[
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedRoomId,
                      decoration: InputDecoration(
                        labelText: 'Ruangan',
                        prefixIcon: const Icon(Icons.meeting_room),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      hint: const Text('Pilih Ruangan (Opsional)'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tidak Ada Ruangan'),
                        ),
                        ..._rooms.map(
                          (room) => DropdownMenuItem<int?>(
                            value: room.id,
                            child: Text(room.displayName),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedRoomId = value),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional description',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Purchase Date
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Purchase Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _purchaseDate != null
                            ? '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}'
                            : 'Select date',
                        style: TextStyle(
                          color: _purchaseDate != null
                              ? AppColors.textPrimary
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('cancel')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(isEditing ? Icons.save : Icons.add),
                        label: Text(isEditing ? 'Save Changes' : 'Add Asset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
