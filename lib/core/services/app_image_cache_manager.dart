import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared image cache for the admin app.
///
/// Any network image using this manager is downloaded once, then reused from
/// cache on later views. A changed/new image URL is treated as a new image and
/// will be downloaded the first time it is seen.
class AppImageCacheManager {
  AppImageCacheManager._();

  static const String key = 'legacy_admin_app_image_cache_v1';
  static const Duration _cacheLifetime = Duration(days: 36500);

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: _cacheLifetime,
      maxNrOfCacheObjects: 50000,
      fileService: _ForeverHttpFileService(_cacheLifetime),
    ),
  );
}

class _ForeverHttpFileService extends HttpFileService {
  _ForeverHttpFileService(this.cacheLifetime);

  final Duration cacheLifetime;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await super.get(url, headers: headers);
    return _ForeverFileServiceResponse(response, cacheLifetime);
  }
}

class _ForeverFileServiceResponse implements FileServiceResponse {
  _ForeverFileServiceResponse(this._response, this._cacheLifetime);

  final FileServiceResponse _response;
  final Duration _cacheLifetime;

  @override
  Stream<List<int>> get content => _response.content;

  @override
  int? get contentLength => _response.contentLength;

  @override
  String? get eTag => _response.eTag;

  @override
  String get fileExtension => _response.fileExtension;

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill => DateTime.now().add(_cacheLifetime);
}
