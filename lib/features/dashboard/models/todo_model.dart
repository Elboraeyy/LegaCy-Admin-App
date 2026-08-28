import 'package:intl/intl.dart';

class TodoItem {
  final String id;
  final String title;
  final String description;
  final DateTime deadline;
  final DateTime createdAt;
  final String createdBy;
  bool isCompleted;

  TodoItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.deadline,
    required this.createdAt,
    required this.createdBy,
    this.isCompleted = false,
  });

  /// Factory method لتحويل JSON إلى TodoItem
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    String createdByName = '';
    final createdBy = json['createdBy'];
    if (createdBy is Map) {
      createdByName = createdBy['name'] ?? '';
    } else if (createdBy is String) {
      createdByName = createdBy;
    }
    
    return TodoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      deadline: DateTime.parse(json['deadline'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      createdBy: createdByName,
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'deadline': deadline.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    'isCompleted': isCompleted,
  };

  /// هل انتهت الـ deadline؟
  bool get isOverdue => !isCompleted && deadline.isBefore(DateTime.now());

  /// كم متبقي من الوقت؟
  Duration get timeRemaining => deadline.difference(DateTime.now());

  /// نص جميل للوقت المتبقي
  String get timeRemainingText {
    final remaining = timeRemaining;
    if (remaining.isNegative) return 'Overdue';
    if (remaining.inMinutes < 1) return 'Due now';
    if (remaining.inMinutes < 60) return '${remaining.inMinutes}m left';
    if (remaining.inHours < 24) return '${remaining.inHours}h left';
    if (remaining.inDays < 7) return '${remaining.inDays}d left';
    return DateFormat('MMM d').format(deadline);
  }

  /// Is it due today?
  bool get isDueToday {
    final now = DateTime.now();
    return deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;
  }

  /// Is it due tomorrow?
  bool get isDueTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return deadline.year == tomorrow.year &&
        deadline.month == tomorrow.month &&
        deadline.day == tomorrow.day;
  }

  /// Should be removed from dashboard?
  bool get shouldBeRemoved => isCompleted || isOverdue;
}
