import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';

class UserFormDialog extends StatefulWidget {
  final User? user;

  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _departmentController;

  final RoomService _roomService = RoomService();
  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  String? _selectedRoomName;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _departmentController = TextEditingController(
      text: widget.user?.department ?? '',
    );
    _selectedRoomName = widget.user?.department;
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _roomService.getAllRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoadingRooms = false;

          // Verify if the current selected room exists in the list
          if (_selectedRoomName != null && _selectedRoomName!.isNotEmpty) {
            final exists = _rooms.any((r) => r.name == _selectedRoomName);
            if (!exists) {
              // If current value is not in list (legacy data), deciding whether to keep it or force selection.
              // For a strict dropdown, we might clear it or add it to list?
              // Standard behavior: reset to null if invalid, or allow custom validation.
              // Here we'll set to null to force user to pick a valid room.
              _selectedRoomName = null;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load rooms: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final user = User(
        id: widget.user?.id,
        name: _nameController.text.trim(),
        department: _selectedRoomName, // Use selected room name
        createdAt: widget.user?.createdAt ?? DateTime.now(),
      );
      Navigator.of(context).pop(user);
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
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? 'Edit User' : 'Add New User',
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

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g., John Doe',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter user name';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),

                  // Department Dropdown (Rooms)
                  _isLoadingRooms
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedRoomName,
                          decoration: const InputDecoration(
                            labelText: 'Department / Room',
                            hintText: 'Select Room',
                            prefixIcon: Icon(
                              Icons.meeting_room,
                            ), // Changed icon to represent Room
                          ),
                          items: _rooms.map((room) {
                            return DropdownMenuItem<String>(
                              value: room.name,
                              child: Text(room.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRoomName = value;
                              _departmentController.text = value ?? '';
                            });
                          },
                          validator: (value) {
                            // Optional: Make it required? User didn't specify.
                            // department is optional in model (based on 'String?' in User class? Let's assume matches TextField logic which was optional or checked in submit)
                            // Original submit: department: _department.text.isEmpty ? null : ...
                            return null;
                          },
                          isExpanded: true,
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
                        label: Text(isEditing ? 'Save Changes' : 'Add User'),
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
