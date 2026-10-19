import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:admin_app/core/config/api_config.dart';

/// A thin wrapper around [http] that automatically attaches
/// the auth token and handles common error scenarios.
class ApiClient {
  final String? _token;

  ApiClient({String? token}) : _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Generic GET request
  Future<Map<String, dynamic>> get(String path) async {
    final response = await _withTimeout(
      http.get(_uri(path), headers: _headers),
      ApiConfig.connectionTimeout,
      'Request',
    );
    return _handleResponse(response);
  }

  /// Generic POST request
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _withTimeout(
      http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      ApiConfig.mutationTimeout,
      'Request',
    );
    return _handleResponse(response);
  }

  /// Generic PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _withTimeout(
      http.put(_uri(path), headers: _headers, body: jsonEncode(body)),
      ApiConfig.mutationTimeout,
      'Request',
    );
    return _handleResponse(response);
  }

  /// Generic PATCH request
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _withTimeout(
      http.patch(_uri(path), headers: _headers, body: jsonEncode(body)),
      ApiConfig.mutationTimeout,
      'Request',
    );
    return _handleResponse(response);
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _withTimeout(
      http.delete(_uri(path), headers: _headers),
      ApiConfig.mutationTimeout,
      'Request',
    );
    return _handleResponse(response);
  }

  /// Multipart POST request for file uploads
  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required String filePath,
    required String fileField,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    
    if (fields != null) {
      request.fields.addAll(fields);
    }
    
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    
    final streamedResponse = await _withTimeout(
      request.send(),
      ApiConfig.uploadTimeout,
      'Image upload',
    );
    final response = await _withTimeout(
      http.Response.fromStream(streamedResponse),
      ApiConfig.uploadTimeout,
      'Image upload response',
    );
    return _handleResponse(response);
  }

  Future<T> _withTimeout<T>(
    Future<T> request,
    Duration timeout,
    String operation,
  ) async {
    try {
      return await request.timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: '$operation timed out. Please check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['error'] ?? body['message'] ?? 'Unknown error';
    throw ApiException(
      statusCode: response.statusCode,
      message: message.toString(),
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
