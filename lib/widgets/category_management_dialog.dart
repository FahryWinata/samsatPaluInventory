import 'package:flutter/material.dart';
import '../models/asset_category_model.dart';
import '../services/category_service.dart';
import '../utils/app_colors.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';

class CategoryManagementDialog extends StatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  State<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<CategoryManagementDialog> {
  final CategoryService _categoryService = CategoryService();
  List<AssetCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryService.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackBarHelper.showError(context, 'Failed to load categories: $e');
      }
    }
  }

  Future<void> _showAddEditDialog([AssetCategory? category]) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedIdentifierType = category?.identifierType ?? 'none';
    bool requiresPerson = category?.requiresPerson ?? true;
    bool requiresRoom = category?.requiresRoom ?? false;
    String selectedIconName = category?.iconName ?? 'inventory_2';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kategori',
                    hintText: 'Contoh: Laptop, Kendaraan, AC',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Icon Picker
                Text(
                  'Ikon Kategori',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AssetCategory.iconMap.entries.map((entry) {
                      final isSelected = entry.key == selectedIconName;
                      return Tooltip(
                        message:
                            AssetCategory.iconDisplayNames[entry.key] ??
                            entry.key,
                        child: InkWell(
                          onTap: () {
                            setDialogState(() => selectedIconName = entry.key);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              entry.value,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Jenis Identifier',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedIdentifierType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Tidak Ada')),
                    DropdownMenuItem(
                      value: 'serial_number',
                      child: Text('Serial Number'),
                    ),
                    DropdownMenuItem(
                      value: 'vehicle_id',
                      child: Text('Nomor Kendaraan'),
                    ),
                    DropdownMenuItem(
                      value: 'room_tag',
                      child: Text('Kode Ruangan'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedIdentifierType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Penugasan',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Dapat ditugaskan ke Pengguna'),
                  subtitle: const Text('Laptop, HP, Kendaraan'),
                  value: requiresPerson,
                  onChanged: (value) {
                    setDialogState(() => requiresPerson = value ?? true);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Dapat ditugaskan ke Ruangan'),
                  subtitle: const Text('AC, Furnitur, Printer'),
                  value: requiresRoom,
                  onChanged: (value) {
                    setDialogState(() => requiresRoom = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  SnackBarHelper.showError(
                    context,
                    'Nama kategori harus diisi',
                  );
                  return;
                }

                final newCategory = AssetCategory(
                  id: category?.id,
                  name: nameController.text.trim(),
                  identifierType: selectedIdentifierType,
                  requiresPerson: requiresPerson,
                  requiresRoom: requiresRoom,
                  iconName: selectedIconName,
                );

                try {
                  if (category == null) {
                    await _categoryService.createCategory(newCategory);
                  } else {
                    await _categoryService.updateCategory(newCategory);
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    SnackBarHelper.showError(context, 'Error: $e');
                  }
                }
              },
              child: Text(context.t('save')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(AssetCategory category) async {
    final assetCount = await _categoryService.getAssetCountForCategory(
      category.id!,
    );
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus kategori "${category.name}"?',
            ),
            if (assetCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$assetCount aset menggunakan kategori ini. Mereka akan menjadi "Tidak Berkategori".',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _categoryService.deleteCategory(category.id!);
        await _loadCategories();
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Kategori berhasil dihapus');
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Gagal menghapus kategori: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kelola Kategori Aset',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada kategori',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.category,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _buildSubtitle(category),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showAddEditDialog(category),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red.shade400,
                                ),
                                onPressed: () => _deleteCategory(category),
                                tooltip: 'Hapus',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Kategori'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(AssetCategory category) {
    final parts = <String>[];

    if (category.requiresIdentifier) {
      parts.add(category.identifierLabel);
    } else {
      parts.add('No Identifier');
    }

    if (category.requiresPerson && category.requiresRoom) {
      parts.add('Person & Room');
    } else if (category.requiresPerson) {
      parts.add('Person Only');
    } else if (category.requiresRoom) {
      parts.add('Room Only');
    }

    return parts.join(' • ');
  }
}
