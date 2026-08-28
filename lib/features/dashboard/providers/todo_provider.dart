import 'dart:async';
import 'package:flutter/material.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/dashboard/models/todo_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TodoProvider extends ChangeNotifier {
  List<TodoItem> _todos = [];
  bool _isLoading = false;
  String? _error;
  String? _token;
  Timer? _pollingTimer;

  static const _pollingInterval = Duration(seconds: 30);

  List<TodoItem> get todos => _todos.where((t) => !t.isOverdue).toList();
  List<TodoItem> get allTodos => _todos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => todos.length;

  /// Start polling for real-time sync
  void _startPolling(String token) {
    _token = token;
    _stopPolling();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (_token != null) {
        loadTodos(_token!);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Load todos from backend/local storage
  Future<void> loadTodos(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      try {
        final client = ApiClient(token: token);
        final response = await client.get('/api/admin/auth/todos');
        final todosData = response['todos'] as List<dynamic>? ?? [];
        _todos = todosData.map((t) => TodoItem.fromJson(t as Map<String, dynamic>)).toList();
        
        if (_token == null) {
          _startPolling(token);
        }
      } catch (e) {
        await _loadFromLocalStorage();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manual refresh
  Future<void> refresh() async {
    if (_token != null) {
      await loadTodos(_token!);
    }
  }

  /// Add a new todo
  Future<void> addTodo({
    required String title,
    required String description,
    required DateTime deadline,
    required String adminName,
    required String? token,
  }) async {
    _error = null;
    
    try {
      final newTodo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        deadline: deadline,
        createdAt: DateTime.now(),
        createdBy: adminName,
      );

      // Try to save to backend
      try {
        if (token != null) {
          final client = ApiClient(token: token);
          await client.post(
            '/api/admin/auth/todos',
            body: newTodo.toJson(),
          );
        }
      } catch (e) {
        // Continue with local storage
      }

      _todos.add(newTodo);
      await _saveToLocalStorage();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Complete a todo
  Future<void> completeTodo(String todoId, {String? token}) async {
    try {
      final index = _todos.indexWhere((t) => t.id == todoId);
      if (index != -1) {
        _todos[index].isCompleted = true;

        // Try to update backend
        try {
          if (token != null) {
            final client = ApiClient(token: token);
            await client.put(
              '/api/admin/auth/todos/$todoId',
              body: {'isCompleted': true},
            );
          }
        } catch (e) {
          // Continue with local storage
        }

        await _saveToLocalStorage();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a todo
  Future<void> deleteTodo(String todoId, {String? token}) async {
    try {
      _todos.removeWhere((t) => t.id == todoId);

      // Try to delete from backend
      try {
        if (token != null) {
          final client = ApiClient(token: token);
          await client.delete('/api/admin/auth/todos/$todoId');
        }
      } catch (e) {
        // Continue with local storage
      }

      await _saveToLocalStorage();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Auto-clean expired todos
  Future<void> cleanExpiredTodos({String? token}) async {
    final expiredCount = _todos.where((t) => t.shouldBeRemoved).length;
    if (expiredCount > 0) {
      _todos.removeWhere((t) => t.shouldBeRemoved);
      await _saveToLocalStorage();
      notifyListeners();
    }
  }

  /// Save to local storage (fallback)
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_todos.map((t) => t.toJson()).toList());
      await prefs.setString('admin_todos', json);
    } catch (e) {
      // Silent fail
    }
  }

/// Load from local storage (fallback)
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('admin_todos');
      if (json != null) {
        final data = jsonDecode(json) as List<dynamic>;
        _todos = data.map((t) => TodoItem.fromJson(t as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _todos = [];
    }
  }

@override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
