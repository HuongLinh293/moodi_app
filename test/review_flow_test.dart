import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mindra/main.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/screens/checkin_view.dart';
import 'package:mindra/screens/login_view.dart';
import 'package:mindra/state/mindra_state.dart';

class FailedGuestAuth extends AuthRepository {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  Future<UserCredential?> signInAnonymously() async => null;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Onboarding has three steps and no nonfunctional reminder setup',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = MindraState(authRepository: FailedGuestAuth());
      addTearDown(state.dispose);
      await tester.pumpWidget(MindraApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Cam kết an toàn'), findsOneWidget);
      await tester.tap(find.text('Tôi hiểu và bắt đầu'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginView), findsOneWidget);
      expect(state.reminderEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed guest sign-in never authenticates a local fallback', (
    tester,
  ) async {
    final state = MindraState(authRepository: FailedGuestAuth());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: LoginView()),
      ),
    );
    await tester.pumpAndSettle();
    final guest = find.text('Tiếp tục không cần tài khoản');
    await tester.ensureVisible(guest);
    await tester.tap(guest);
    await tester.pumpAndSettle();
    expect(state.isAuthenticated, isFalse);
    expect(
      find.text('Chưa mở được phiên khách. Kiểm tra kết nối và thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('Quick save closes without a garden dialog', (tester) async {
    final state = MindraState(authRepository: FailedGuestAuth())
      ..selectEmotion('calm');
    addTearDown(state.dispose);
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinView(
            state: state,
            onClose: () => closed = true,
            onOpenJournal: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu check-in nhanh'));
    await tester.tap(find.text('Lưu check-in nhanh'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(state.entries, hasLength(1));
    expect(state.gardenMoments, isEmpty);
    expect(find.text('Giữ trong vườn'), findsOneWidget);
  });
}
