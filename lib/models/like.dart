class Like {
  final String id;
  final String requestId;
  final String userId;
  final DateTime createdAt;

  Like({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Like.fromMap(Map<String, dynamic> map) {
    return Like(
      id: map['id'] ?? '',
      requestId: map['requestId'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Like copyWith({
    String? id,
    String? requestId,
    String? userId,
    DateTime? createdAt,
  }) {
    return Like(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
