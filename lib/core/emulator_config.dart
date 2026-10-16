import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Chỉ dùng Emulator Suite khi bật --dart-define=USE_FIREBASE_EMULATORS=true.
/// Gọi sau Firebase.initializeApp() trong main().
Future<void> connectToEmulatorIfDebug() async {
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (!kDebugMode || !useEmulators) return;

  const configuredHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  final host = configuredHost.isNotEmpty
      ? configuredHost
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';

  try {
    // Auth Emulator — port 9099
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Firestore Emulator — port 8080
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    // Cloud Functions Emulator — port 5001
    FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .useFunctionsEmulator(host, 5001);

    debugPrint('Firebase Emulator: đã cấu hình địa chỉ $host');
  } catch (e) {
    debugPrint('⚠️  Firebase Emulator: không kết nối được ($e)');
  }
}
