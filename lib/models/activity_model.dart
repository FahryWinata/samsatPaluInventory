class ActivityLog {
  final int? id;
  final String action; // 'create', 'update', 'delete', 'transfer'
  final String entityType; // 'inventory', 'asset', 'user'
  final int entityId;
  final String entityName;
  final String performedBy;
  final DateTime timestamp;
  final String details;

  ActivityLog({
    this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.performedBy,
    required this.timestamp,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'performed_by': performedBy,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      action: map['action'],
      entityType: map['entity_type'],
      entityId: map['entity_id'],
      entityName: map['entity_name'] ?? 'Unknown',
      performedBy: map['performed_by'],
      timestamp: DateTime.parse(map['timestamp']),
      details: map['details'] ?? '',
    );
  }
}
