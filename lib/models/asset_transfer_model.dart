class AssetTransfer {
  final int? id;
  final int assetId;
  final int? fromUserId;
  final int toUserId;
  final DateTime transferDate;
  final String? notes;

  AssetTransfer({
    this.id,
    required this.assetId,
    this.fromUserId,
    required this.toUserId,
    required this.transferDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_id': assetId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'transfer_date': transferDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory AssetTransfer.fromMap(Map<String, dynamic> map) {
    return AssetTransfer(
      id: map['id'],
      assetId: map['asset_id'],
      fromUserId: map['from_user_id'],
      toUserId: map['to_user_id'],
      transferDate: DateTime.parse(map['transfer_date']),
      notes: map['notes'],
    );
  }
}
