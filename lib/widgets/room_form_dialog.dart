import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../utils/extensions.dart';

class RoomFormDialog extends StatefulWidget {
  final Room? room;

  const RoomFormDialog({super.key, this.room});

  @override
  State<RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<RoomFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _buildingController;
  late TextEditingController _floorController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _buildingController = TextEditingController(
      text: widget.room?.building ?? '',
    );
    _floorController = TextEditingController(text: widget.room?.floor ?? '');
    _descriptionController = TextEditingController(
      text: widget.room?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.room != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Ruangan' : 'Tambah Ruangan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Ruangan *',
                hintText: 'Contoh: Tata Usaha, Ruang Kepala',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buildingController,
                    decoration: InputDecoration(
                      labelText: 'Gedung',
                      hintText: 'Contoh: Gedung A',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _floorController,
                    decoration: InputDecoration(
                      labelText: 'Lantai',
                      hintText: '1, 2, 3...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Keterangan tambahan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nama ruangan harus diisi')),
              );
              return;
            }

            final room = Room(
              id: widget.room?.id,
              name: _nameController.text.trim(),
              building: _buildingController.text.trim().isEmpty
                  ? null
                  : _buildingController.text.trim(),
              floor: _floorController.text.trim().isEmpty
                  ? null
                  : _floorController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
            );

            Navigator.pop(context, room);
          },
          child: Text(context.t('save')),
        ),
      ],
    );
  }
}
