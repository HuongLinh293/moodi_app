import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

/// No private data is persisted locally. A repository belongs to one auth
/// session; even an A -> B -> A switch invalidates in-flight responses.
class CommunityRepository {
  CommunityRepository({
    this.uid,
    this.functions,
    this.sessionValid,
    this.transport,
  });
  final String? uid;
  final FirebaseFunctions? functions;
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
    return uid != null && FirebaseAuth.instance.currentUser?.uid == uid;
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
      final response =
          await (functions ??
                  FirebaseFunctions.instanceFor(region: 'asia-southeast1'))
              .httpsCallable(
                'community',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 60),
                ),
              )
              .call<dynamic>(payload);
      result = Map<String, dynamic>.from(response.data as Map);
    }
    if (!validSession) throw StateError('Phiên đăng nhập đã thay đổi.');
    return result;
  }

  Future<Json> mutate(String action, Json data, {String? requestId}) =>
      call(action, {...data, 'requestId': requestId ?? newRequestId()});

  Future<Uint8List> image(Json scope, {String action = 'image'}) async =>
      base64Decode((await call(action, scope))['image'] as String);

  static String error(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found' || error.code == 'unimplemented') {
        return error.message?.contains('Bài viết') == true
            ? error.message!
            : 'Dịch vụ cộng đồng chưa sẵn sàng. Hãy thử lại sau.';
      }
      if ([
        'unavailable',
        'deadline-exceeded',
        'internal',
      ].contains(error.code)) {
        return 'Chưa kết nối được cộng đồng. Nội dung bạn viết vẫn được giữ; hãy thử lại.';
      }
      return error.message ?? 'Không thực hiện được. Hãy thử lại.';
    }
    if (error is StateError) return error.message.toString();
    return 'Không thực hiện được. Hãy kiểm tra kết nối và thử lại.';
  }
}
