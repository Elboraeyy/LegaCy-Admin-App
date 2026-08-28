import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/dashboard/models/todo_model.dart';
import 'package:admin_app/features/dashboard/providers/todo_provider.dart';
import 'package:admin_app/features/auth/auth_provider.dart';

/// Widget عرض TODO item واحد
class TodoItemWidget extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const TodoItemWidget({
    super.key,
    required this.todo,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = todo.isOverdue;
    final isDueToday = todo.isDueToday;
    final isDueTomorrow = todo.isDueTomorrow;

    // Select color based on urgency
    Color urgencyColor;
    if (todo.isCompleted) {
      urgencyColor = AppColors.success;
    } else if (isOverdue) {
      urgencyColor = AppColors.error;
    } else if (isDueToday) {
      urgencyColor = AppColors.warning;
    } else if (isDueTomorrow) {
      urgencyColor = const Color(0xFFF59E0B);
    } else {
      urgencyColor = AppColors.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: todo.isCompleted 
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: todo.isCompleted 
              ? AppColors.success.withValues(alpha: 0.3)
              : urgencyColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onComplete,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: todo.isCompleted ? urgencyColor : Colors.transparent,
                border: Border.all(
                  color: urgencyColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: todo.isCompleted
                  ? const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Description & Deadline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: todo.isCompleted
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    todo.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: todo.isCompleted
                          ? AppColors.textMuted.withValues(alpha: 0.7)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      todo.isCompleted ? LucideIcons.checkCircle : LucideIcons.clock,
                      size: 11,
                      color: todo.isCompleted ? AppColors.success : urgencyColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      todo.isCompleted ? 'Completed' : todo.timeRemainingText,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: todo.isCompleted ? AppColors.success : urgencyColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delete Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onDelete();
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                LucideIcons.x,
                size: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget لعرض TODO List section
class TodoListSection extends StatelessWidget {
  final List<TodoItem> todos;
  final VoidCallback onAddTodo;

  const TodoListSection({
    super.key,
    required this.todos,
    required this.onAddTodo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Tasks',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        todos.isEmpty ? _buildEmptyState() : _buildTodoCard(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.checkCircle2,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No pending tasks',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAddTodo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.plus,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Task',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        LucideIcons.listTodo,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${todos.length} pending',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onAddTodo,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: todos.asMap().entries.map((entry) {
                final index = entry.key;
                final todo = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < todos.length - 1 ? 10 : 0,
                  ),
                  child: TodoItemWidget(
                    todo: todo,
                    onComplete: () async {
                      await context.read<TodoProvider>().completeTodo(
                        todo.id,
                        token: context.read<AuthProvider>().token,
                      );
                    },
                    onDelete: () async {
                      await context.read<TodoProvider>().deleteTodo(
                        todo.id,
                        token: context.read<AuthProvider>().token,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
