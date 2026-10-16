import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth? auth;
  static Future<void>? _googleSignInInitialization;

  Future<void> _initializeGoogleSignIn() =>
      _googleSignInInitialization ??= GoogleSignIn.instance.initialize();

  AuthRepository({this.auth});

  FirebaseAuth get _instance => auth ?? FirebaseAuth.instance;

  User? get currentUser {
    try {
      return _instance.currentUser;
    } catch (e) {
      debugPrint('AuthRepository: Unable to get currentUser ($e)');
      return null;
    }
  }

  String? get currentUserId => currentUser?.uid;

  Stream<User?> get authStateChanges {
    try {
      return _instance.authStateChanges();
    } catch (e) {
      debugPrint('AuthRepository: Unable to listen to authStateChanges ($e)');
      return const Stream.empty();
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _instance.signInAnonymously();
    } catch (e) {
      debugPrint('AuthRepository: signInAnonymously error ($e)');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('AuthRepository: signInWithEmailPassword error ($e)');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmailPassword(
      String email, String password) async {
    try {
      return await _instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('AuthRepository: registerWithEmailPassword error ($e)');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await _instance.signInWithPopup(googleProvider);
      } else {
        await _initializeGoogleSignIn();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        return await _instance.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('AuthRepository: signInWithGoogle error ($e)');
      rethrow;
    } catch (e) {
      debugPrint('AuthRepository: signInWithGoogle error ($e)');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');
      if (kIsWeb) {
        return await _instance.signInWithPopup(appleProvider);
      } else {
        return await _instance.signInWithProvider(appleProvider);
      }
    } catch (e) {
      debugPrint('AuthRepository: signInWithApple error ($e)');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await _initializeGoogleSignIn();
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _instance.signOut();
    } catch (e) {
      debugPrint('AuthRepository: signOut error ($e)');
    }
  }
}
