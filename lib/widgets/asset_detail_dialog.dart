import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/extensions.dart';
import 'package:intl/intl.dart';
import '../models/asset_model.dart';
import '../models/user_model.dart';
import '../models/asset_category_model.dart';
import '../models/room_model.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../services/category_service.dart';
import '../services/room_service.dart';
import '../services/transfer_report_service.dart';
import '../utils/app_colors.dart';
import '../utils/snackbar_helper.dart';

class AssetDetailDialog extends StatefulWidget {
  final Asset asset;
  final VoidCallback onUpdate;
  final bool maintenanceMode;
  final VoidCallback? onSplit;
  final VoidCallback? onMerge;

  const AssetDetailDialog({
    super.key,
    required this.asset,
    required this.onUpdate,
    this.maintenanceMode = false,
    this.onSplit,
    this.onMerge,
  });

  @override
  State<AssetDetailDialog> createState() => _AssetDetailDialogState();
}

class _AssetDetailDialogState extends State<AssetDetailDialog> {
  final AssetService assetService = AssetService();
  final UserService userService = UserService();
  final CategoryService categoryService = CategoryService();
  final RoomService roomService = RoomService();

  late Asset _asset;
  bool isLoading = true;
  User? currentHolder;
  AssetCategory? assetCategory;
  Room? assignedRoom;
  List<Map<String, dynamic>> transferHistory = [];

  // Edit Mode State
  bool _isEditMode = false;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _identifierController = TextEditingController();
  int? _editCategoryId;
  int? _editRoomId;
  DateTime? _editPurchaseDate;
  File? _pickedImage;
  bool _removeImage = false;
  List<AssetCategory> _allCategories = [];
  List<Room> _allRooms = [];

  @override
  void initState() {
    super.initState();
    _asset = widget.asset;
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch fresh asset data
      final freshAsset = await assetService.getAssetById(_asset.id!);
      if (freshAsset != null) {
        _asset = freshAsset;
      }

      // 2. Fetch current holder
      if (_asset.currentHolderId != null) {
        currentHolder = await userService.getUserById(_asset.currentHolderId!);
      } else {
        currentHolder = null;
      }

      // 3. Fetch category
      if (_asset.categoryId != null) {
        assetCategory = await categoryService.getCategoryById(
          _asset.categoryId!,
        );
      } else {
        assetCategory = null;
      }

      // 4. Fetch assigned room
      if (_asset.assignedToRoomId != null) {
        assignedRoom = await roomService.getRoomById(_asset.assignedToRoomId!);
      } else {
        assignedRoom = null;
      }

      // 5. Fetch history
      final history = await assetService.getTransferHistoryWithNames(
        _asset.id!,
      );

      if (mounted) {
        setState(() {
          transferHistory = history;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Enter edit mode and populate controllers with current values
  void _enterEditMode() async {
    // Load all categories and rooms for dropdowns
    final categories = await categoryService.getAllCategories();
    final rooms = await roomService.getAllRooms();

    setState(() {
      _isEditMode = true;
      _nameController.text = _asset.name;
      _descController.text = _asset.description ?? '';
      _identifierController.text = _asset.identifierValue ?? '';
      _editCategoryId = _asset.categoryId;
      _editRoomId = _asset.assignedToRoomId;
      _editPurchaseDate = _asset.purchaseDate;
      _editPurchaseDate = _asset.purchaseDate;
      _pickedImage = null; // Reset picked image
      _removeImage = false; // Reset remove flag
      _allCategories = categories;
      _allRooms = rooms;
    });
  }

  /// Pick an image from gallery or camera
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        _removeImage = false; // Reset remove flag since we picked a new one
      });
    }
  }

  /// Save changes and exit edit mode
  Future<void> _saveChanges() async {
    try {
      String? newImagePath = _asset.imagePath;

      // Handle new image persistence
      if (_pickedImage != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_pickedImage!.path)}';
        final savedImage = await _pickedImage!.copy('${appDir.path}/$fileName');
        newImagePath = savedImage.path;
      }

      final updatedAsset = _asset.copyWith(
        name: _nameController.text.trim(),
        identifierValue: _identifierController.text.trim().isEmpty
            ? null
            : _identifierController.text.trim(),
        clearIdentifierValue: _identifierController.text.trim().isEmpty,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        clearDescription: _descController.text.trim().isEmpty,
        categoryId: _editCategoryId,

        assignedToRoomId: _editRoomId,
        clearAssignedToRoomId: _editRoomId == null,
        purchaseDate: _editPurchaseDate,
        imagePath: newImagePath,
        clearImagePath: _removeImage && _pickedImage == null,
      );

      await assetService.updateAsset(updatedAsset);
      _asset = updatedAsset;
      widget.onUpdate();

      if (mounted) {
        setState(() => _isEditMode = false);
        _loadData(); // Refresh to get updated related data
        SnackBarHelper.showSuccess(context, 'Asset updated successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to update: $e');
      }
    }
  }

  /// Cancel edit mode and discard changes
  void _cancelEdit() {
    setState(() => _isEditMode = false);
  }

  /// Show date picker for purchase date
  Future<void> _selectPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editPurchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _editPurchaseDate = picked);
    }
  }

  /// Show dialog to input handover report details
  void _showHandoverReportDialog(Map<String, dynamic> transferLog) {
    final fromName = TextEditingController(
      text: transferLog['from_user_name'] ?? '',
    );
    final fromNip = TextEditingController();
    final fromPosition = TextEditingController();
    final toName = TextEditingController(
      text: transferLog['to_user_name'] ?? '',
    );
    final toNip = TextEditingController();
    final toPosition = TextEditingController();
    final approverName = TextEditingController();
    final approverNip = TextEditingController();
    final approverPosition = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool includeApprover = true;
        return StatefulBuilder(
          builder: (dialogStateContext, setState) {
            return AlertDialog(
              title: const Text('Generate Handover Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Party 1 (From)
                    Text(
                      'PIHAK PERTAMA (I) - Pemberi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fromName,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fromNip,
                      decoration: const InputDecoration(
                        labelText: 'NIP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fromPosition,
                      decoration: const InputDecoration(
                        labelText: 'Jabatan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Party 2 (To)
                    Text(
                      'PIHAK KEDUA (II) - Penerima',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: toName,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: toNip,
                      decoration: const InputDecoration(
                        labelText: 'NIP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: toPosition,
                      decoration: const InputDecoration(
                        labelText: 'Jabatan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Approver Toggle
                    const Divider(),
                    CheckboxListTile(
                      title: Text(
                        'Include MENGETAHUI / MENGESAHKAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      value: includeApprover,
                      onChanged: (val) {
                        setState(() {
                          includeApprover = val ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),

                    if (includeApprover) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: approverName,
                        decoration: const InputDecoration(
                          labelText: 'Nama',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: approverNip,
                        decoration: const InputDecoration(
                          labelText: 'NIP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: approverPosition,
                        decoration: const InputDecoration(
                          labelText: 'Jabatan',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final transferDate = DateTime.parse(
                      transferLog['transfer_date'],
                    );
                    final reportService = TransferReportService();

                    await reportService.generateHandoverReport(
                      transferDate: transferDate,
                      fromPerson: PersonInfo(
                        name: fromName.text,
                        nip: fromNip.text,
                        position: fromPosition.text,
                      ),
                      toPerson: PersonInfo(
                        name: toName.text,
                        nip: toNip.text,
                        position: toPosition.text,
                      ),
                      approver: includeApprover
                          ? PersonInfo(
                              name: approverName.text,
                              nip: approverNip.text,
                              position: approverPosition.text,
                            )
                          : null,
                      asset: HandoverAssetInfo(
                        name: _asset.name,
                        serialNumber: _asset.identifierValue,
                        brand: _asset.description,
                        year: _asset.purchaseDate?.year.toString(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignDialog() async {
    final users = await userService.getAllUsers();
    if (!mounted) return;

    // Filter out the current holder
    final availableUsers = users
        .where((u) => u.id != _asset.currentHolderId)
        .toList();

    final User? selectedUser = await showDialog<User>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredUsers = availableUsers
                .where(
                  (u) =>
                      u.name.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      (u.department?.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ) ??
                          false),
                )
                .toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 350, // Slightly wider for search bar
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('select_holder'), // Used key 'select_holder'
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: context.t('search_users'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          searchQuery.isEmpty
                              ? context.t('no_other_users_available')
                              : context.t('no_users_found'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                user.department ?? '-',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => Navigator.pop(context, user),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hoverColor: Colors.grey.shade100,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(context.t('cancel')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedUser != null) {
      await assetService.transferAsset(
        assetId: _asset.id!,
        toUserId: selectedUser.id!,
      );
      widget.onUpdate(); // Notify parent to refresh
      _loadData(); // Refresh local data (will fetch new holder)
    }
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('delete_asset_title')),
        content: Text(
          'Are you sure you want to delete "${_asset.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await assetService.deleteAsset(_asset.id!);
      widget.onUpdate();
      if (mounted) {
        Navigator.pop(context);
        SnackBarHelper.showSuccess(context, 'Asset deleted successfully');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.available;
      case 'assigned':
        return AppColors.assigned;
      case 'maintenance':
        return AppColors.maintenance;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build an editable row for edit mode
  Widget _buildEditRow(String label, Widget editWidget) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: editWidget),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Image Section
                  GestureDetector(
                    onTap: _isEditMode ? _pickImage : null,
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            image: _pickedImage != null
                                ? DecorationImage(
                                    image: FileImage(_pickedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_asset.imagePath != null && !_removeImage)
                                ? DecorationImage(
                                    image: _asset.imagePath!.startsWith('http')
                                        ? NetworkImage(_asset.imagePath!)
                                        : FileImage(File(_asset.imagePath!))
                                              as ImageProvider,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              (_pickedImage == null &&
                                  (_asset.imagePath == null || _removeImage))
                              ? const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 32,
                                )
                              : null,
                        ),
                        // Edit Overlay (Camera Icon)
                        if (_isEditMode &&
                            _pickedImage == null &&
                            (_asset.imagePath == null || _removeImage))
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        // Remove Image Button
                        if (_isEditMode &&
                            (_pickedImage != null ||
                                (_asset.imagePath != null && !_removeImage)))
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _pickedImage = null;
                                  _removeImage = true;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditMode)
                          TextField(
                            controller: _nameController,
                            cursorColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Asset Name',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              filled: false,
                            ),
                          )
                        else
                          Text(
                            _asset.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (_isEditMode)
                          TextField(
                            controller: _identifierController,
                            cursorColor: Colors.white70,
                            style: const TextStyle(color: Colors.white70),
                            decoration: const InputDecoration(
                              hintText: 'Identifier (optional)',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              filled: false,
                            ),
                          )
                        else
                          Text(
                            _asset.identifierValue ?? '-',
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Mode Buttons
                  if (_isEditMode) ...[
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.greenAccent),
                      onPressed: _saveChanges,
                      tooltip: 'Save Changes',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _cancelEdit,
                      tooltip: 'Cancel',
                    ),
                  ] else ...[
                    // View Mode Buttons
                    // Split Button
                    if (widget.onSplit != null && !widget.maintenanceMode)
                      IconButton(
                        icon: const Icon(
                          Icons.call_split,
                          color: Colors.orangeAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSplit!();
                        },
                        tooltip: 'Split Asset',
                      ),
                    // Merge Button
                    if (widget.onMerge != null && !widget.maintenanceMode)
                      IconButton(
                        icon: const Icon(
                          Icons.merge_type,
                          color: Colors.tealAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onMerge!();
                        },
                        tooltip: 'Merge Asset',
                      ),
                    if (!widget.maintenanceMode)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: _enterEditMode,
                        tooltip: 'Edit Asset',
                      ),
                    if (!widget.maintenanceMode)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: _deleteAsset,
                        tooltip: 'Delete Asset',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fixed Content: Status & Details
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            children: [
                              // Status & Holder
                              _buildInfoSection(
                                context,
                                title: 'Current Status',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          _asset.status,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _asset.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(_asset.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (currentHolder != null) ...[
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.arrow_right_alt,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        currentHolder!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    // Assign Button
                                    if (!widget.maintenanceMode)
                                      ElevatedButton.icon(
                                        onPressed: _showAssignDialog,
                                        icon: const Icon(
                                          Icons.person_add,
                                          size: 16,
                                        ),
                                        label: Text(context.t('assign')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Details
                              _buildInfoSection(
                                context,
                                title: 'Details',
                                child: _isEditMode
                                    ? Column(
                                        children: [
                                          // Category Dropdown
                                          _buildEditRow(
                                            'Kategori',
                                            DropdownButton<int?>(
                                              value: _editCategoryId,
                                              isExpanded: true,
                                              hint: const Text(
                                                'Pilih Kategori',
                                              ),
                                              underline: const SizedBox(),
                                              items: [
                                                const DropdownMenuItem<int?>(
                                                  value: null,
                                                  child: Text(
                                                    'Tidak Berkategori',
                                                  ),
                                                ),
                                                ..._allCategories.map(
                                                  (c) => DropdownMenuItem<int?>(
                                                    value: c.id,
                                                    child: Text(c.name),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => _editCategoryId = v,
                                              ),
                                            ),
                                          ),
                                          // Room Dropdown
                                          _buildEditRow(
                                            'Ruangan',
                                            DropdownButton<int?>(
                                              value: _editRoomId,
                                              isExpanded: true,
                                              hint: const Text('Pilih Ruangan'),
                                              underline: const SizedBox(),
                                              items: [
                                                const DropdownMenuItem<int?>(
                                                  value: null,
                                                  child: Text('Tidak Ada'),
                                                ),
                                                ..._allRooms.map(
                                                  (r) => DropdownMenuItem<int?>(
                                                    value: r.id,
                                                    child: Text(r.displayName),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => _editRoomId = v,
                                              ),
                                            ),
                                          ),
                                          // Description TextField
                                          _buildEditRow(
                                            'Description',
                                            TextField(
                                              controller: _descController,
                                              decoration: InputDecoration(
                                                hintText: 'Enter description',
                                                hintStyle: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 14,
                                                ),
                                                isDense: true,
                                                border: UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                              ),
                                              maxLines: null,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          // Purchase Date Picker
                                          _buildEditRow(
                                            'Purchase Date',
                                            InkWell(
                                              onTap: _selectPurchaseDate,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _editPurchaseDate !=
                                                                null
                                                            ? DateFormat(
                                                                'dd MMM yyyy',
                                                              ).format(
                                                                _editPurchaseDate!,
                                                              )
                                                            : 'Select date',
                                                        style: TextStyle(
                                                          color:
                                                              _editPurchaseDate !=
                                                                  null
                                                              ? Colors.black87
                                                              : Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _buildDetailRow(
                                            'Kategori',
                                            assetCategory?.name ??
                                                'Tidak Berkategori',
                                          ),
                                          _buildDetailRow(
                                            'Jumlah',
                                            '${_asset.quantity} unit',
                                          ),
                                          _buildDetailRow(
                                            'Ruangan',
                                            assignedRoom?.displayName ??
                                                'Tidak Ada',
                                          ),
                                          _buildDetailRow(
                                            'Description',
                                            _asset.description ?? '-',
                                          ),
                                          _buildDetailRow(
                                            'Purchase Date',
                                            _asset.purchaseDate != null
                                                ? DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(_asset.purchaseDate!)
                                                : '-',
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // Maintenance Settings Section
                              _buildInfoSection(
                                context,
                                title: context.t('maintenance_settings'),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Toggle Row
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.build,
                                            size: 20,
                                            color: _asset.requiresMaintenance
                                                ? Colors.orange
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            context.t('requires_maintenance'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Switch(
                                            value: _asset.requiresMaintenance,
                                            onChanged: (value) async {
                                              // Optimistic local update
                                              final newInterval = value
                                                  ? 90
                                                  : null;
                                              DateTime? nextDate;
                                              if (value &&
                                                  newInterval != null) {
                                                final baseDate =
                                                    _asset
                                                        .lastMaintenanceDate ??
                                                    DateTime.now();
                                                nextDate = baseDate.add(
                                                  Duration(days: newInterval),
                                                );
                                              }
                                              setState(() {
                                                _asset = _asset.copyWith(
                                                  requiresMaintenance: value,
                                                  maintenanceIntervalDays:
                                                      newInterval,
                                                  nextMaintenanceDate: nextDate,
                                                );
                                              });
                                              // Save to backend
                                              await assetService
                                                  .updateMaintenanceSettings(
                                                    assetId: _asset.id!,
                                                    requiresMaintenance: value,
                                                    intervalDays: newInterval,
                                                  );
                                              widget.onUpdate();
                                            },
                                            activeTrackColor:
                                                Colors.orange.shade200,
                                            activeThumbColor: Colors.orange,
                                          ),
                                        ],
                                      ),
                                      if (_asset.requiresMaintenance) ...[
                                        const Divider(),
                                        // Interval Dropdown
                                        Row(
                                          children: [
                                            Text(
                                              context.t('maintenance_interval'),
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            DropdownButton<int>(
                                              value:
                                                  _asset
                                                      .maintenanceIntervalDays ??
                                                  90,
                                              items: [30, 60, 90, 120, 180, 365]
                                                  .map(
                                                    (days) => DropdownMenuItem(
                                                      value: days,
                                                      child: Text(
                                                        '$days ${context.t('days')}',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) async {
                                                if (value != null) {
                                                  // Optimistic local update
                                                  final baseDate =
                                                      _asset
                                                          .lastMaintenanceDate ??
                                                      DateTime.now();
                                                  final nextDate = baseDate.add(
                                                    Duration(days: value),
                                                  );
                                                  setState(() {
                                                    _asset = _asset.copyWith(
                                                      maintenanceIntervalDays:
                                                          value,
                                                      nextMaintenanceDate:
                                                          nextDate,
                                                    );
                                                  });
                                                  // Save to backend
                                                  await assetService
                                                      .updateMaintenanceSettings(
                                                        assetId: _asset.id!,
                                                        requiresMaintenance:
                                                            true,
                                                        intervalDays: value,
                                                      );
                                                  widget.onUpdate();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Last Maintained & Next Due
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.t(
                                                      'last_maintained',
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    _asset.lastMaintenanceDate !=
                                                            null
                                                        ? DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            _asset
                                                                .lastMaintenanceDate!,
                                                          )
                                                        : context.t('never'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.t(
                                                      'next_maintenance',
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  Text(
                                                    _asset.nextMaintenanceDate !=
                                                            null
                                                        ? DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            _asset
                                                                .nextMaintenanceDate!,
                                                          )
                                                        : context.t('not_set'),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          _asset
                                                              .isMaintenanceOverdue
                                                          ? Colors.red
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Mark as Maintained Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              // Optimistic local update
                                              final now = DateTime.now();
                                              DateTime? nextDate;
                                              if (_asset
                                                      .maintenanceIntervalDays !=
                                                  null) {
                                                nextDate = now.add(
                                                  Duration(
                                                    days: _asset
                                                        .maintenanceIntervalDays!,
                                                  ),
                                                );
                                              }
                                              setState(() {
                                                _asset = _asset.copyWith(
                                                  lastMaintenanceDate: now,
                                                  nextMaintenanceDate: nextDate,
                                                );
                                              });
                                              // Save to backend
                                              final success = await assetService
                                                  .markAsMaintained(_asset.id!);
                                              if (!context.mounted) return;
                                              if (success) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.t(
                                                        'maintenance_updated',
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                widget.onUpdate();
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.check,
                                              size: 18,
                                            ),
                                            label: Text(
                                              context.t('mark_as_maintained'),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 32),

                              // History Header
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  'Transfer History',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        // Scrollable History
                        Expanded(
                          child: transferHistory.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'No transfer history available',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    24,
                                  ),
                                  itemCount: transferHistory.length,
                                  itemBuilder: (context, index) {
                                    final log = transferHistory[index];
                                    final date = DateTime.parse(
                                      log['transfer_date'],
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            children: [
                                              const CircleAvatar(
                                                radius: 4,
                                                backgroundColor:
                                                    AppColors.textSecondary,
                                              ),
                                              if (index !=
                                                  transferHistory.length - 1)
                                                Container(
                                                  width: 1,
                                                  height: 40,
                                                  color: Colors.grey.shade300,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Transferred to ${log['to_user_name'] ?? 'Unknown'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat(
                                                    'MMM dd, HH:mm',
                                                  ).format(date),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (log['notes'] != null &&
                                                    log['notes']
                                                        .toString()
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      log['notes'],
                                                      style: const TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                // Generate Report Button
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _showHandoverReportDialog(
                                                          log,
                                                        ),
                                                    icon: const Icon(
                                                      Icons
                                                          .description_outlined,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Generate Report',
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          AppColors.primary,
                                                      side: BorderSide(
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 4,
                                                          ),
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
}
