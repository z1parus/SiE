/// A file or image attached to a plan node (Goal/SubGoal/Task/Milestone).
/// Visible in both list and map modes.
///
/// [storagePath] is the path inside the `goal-attachments` Storage bucket.
/// Signed URLs for display are generated on demand by [PlanningNotifier] and
/// NOT stored here (they expire; [storagePath] is the stable reference).
class NodeAttachment {
  const NodeAttachment({
    required this.id,
    required this.goalId,
    required this.nodeType,
    required this.nodeId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.createdAt,
    this.localPath,
  });

  final String id;
  final String goalId;
  final String nodeType; // 'goal' | 'subgoal' | 'task' | 'milestone'
  final String nodeId;
  final String storagePath; // path in goal-attachments bucket
  final String? localPath;  // offline cache; null once uploaded and evicted
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final DateTime createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf   => mimeType == 'application/pdf';

  factory NodeAttachment.fromMap(Map<String, dynamic> m) => NodeAttachment(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        nodeType: m['node_type'] as String,
        nodeId: m['node_id'] as String,
        storagePath: m['storage_path'] as String,
        fileName: m['file_name'] as String,
        mimeType: m['mime_type'] as String,
        sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
        uploadedBy: m['uploaded_by'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'goal_id': goalId,
        'node_type': nodeType,
        'node_id': nodeId,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'uploaded_by': uploadedBy,
        'created_at': createdAt.toIso8601String(),
      };
}
