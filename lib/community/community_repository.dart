import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../core/api_config.dart';
import '../core/http_client.dart';

typedef Json = Map<String, dynamic>;

/// No private data is persisted locally. A repository belongs to one auth
/// session; even an A -> B -> A switch invalidates in-flight responses.
class CommunityRepository {
  CommunityRepository({
    this.uid,
    this.httpClient,
    this.sessionValid,
    this.transport,
  });
  final String? uid;
  final HttpClient? httpClient;
  final bool Function()? sessionValid;
  final Future<Json> Function(Json payload)? transport;

  String newRequestId() {
    final random = Random.secure();
    return List.generate(
      20,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  bool get validSession {
    if (sessionValid != null) return sessionValid!();
    return uid != null && (httpClient ?? HttpClient()).authToken != null;
  }

  Future<Json> call(String action, [Json data = const {}]) async {
    if (!validSession) {
      throw StateError('Phiên đăng nhập đã thay đổi. Hãy mở lại Cộng đồng.');
    }
    final payload = {'action': action, ...data};
    Json result;
    if (transport != null) {
      result = await transport!(payload);
    } else {
      // Mọi kiểm tra quyền, idempotency và hạn mức nằm ở server (/community).
      final response = await (httpClient ?? HttpClient()).post(
        ApiConfig.communityEndpoint,
        body: payload,
      );
      if (response is! Map<String, dynamic>) {
        throw ApiException(message: 'Phản hồi cộng đồng không hợp lệ.');
      }
      result = response;
    }
    if (!validSession) throw StateError('Phiên đăng nhập đã thay đổi.');
    return result;
  }

  Future<Json> mutate(String action, Json data, {String? requestId}) =>
      call(action, {...data, 'requestId': requestId ?? newRequestId()});

  Future<Uint8List> image(Json scope, {String action = 'image'}) async =>
      base64Decode((await call(action, scope))['image'] as String);

  static String error(Object error) {
    if (error is ApiException) {
      // 404 do route không tồn tại ("Cannot POST ...") khác với 404 nghiệp vụ
      // như "Người này chưa tạo hồ sơ cộng đồng."
      if (error.code == 'unimplemented' ||
          (error.code == 'not-found' && error.message.startsWith('Cannot '))) {
        return 'Dịch vụ cộng đồng chưa sẵn sàng. Hãy thử lại sau.';
      }
      if ([
        'unavailable',
        'deadline-exceeded',
        'internal',
      ].contains(error.code)) {
        return 'Chưa kết nối được cộng đồng. Nội dung bạn viết vẫn được giữ; hãy thử lại.';
      }
      return error.message;
    }
    if (error is StateError) return error.message.toString();
    return 'Không thực hiện được. Hãy kiểm tra kết nối và thử lại.';
  }
}
