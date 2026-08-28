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
    final response = await http
        .get(_uri(path), headers: _headers)
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Generic POST request
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Generic PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Generic PATCH request
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.connectionTimeout);
    return _handleResponse(response);
  }

  /// Generic DELETE request
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http
        .delete(_uri(path), headers: _headers)
        .timeout(ApiConfig.connectionTimeout);
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
    
    final streamedResponse = await request.send().timeout(ApiConfig.connectionTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

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
