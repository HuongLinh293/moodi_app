import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mindra/core/social_sign_in.dart';
import 'package:mindra/repositories/auth_repository.dart';
import 'package:mindra/screens/login_view.dart';
import 'package:mindra/state/mindra_state.dart';

class ConfiguredSocial extends SocialSignIn {
  @override
  bool get googleConfigured => true;
  @override
  Future<bool> appleAvailable() async => false;
}

class ProviderAuth extends AuthRepository {
  ProviderAuth() : super(socialSignIn: ConfiguredSocial());
  bool offline = true;
  bool googleEnabled = true;
  @override
  Future<({bool google, bool apple})> socialProviders() async {
    if (offline) throw StateError('Offline');
    return (google: googleEnabled, apple: false);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Google stays visible during outage; retry reloads provider state',
    (tester) async {
      final auth = ProviderAuth();
      final state = MindraState(authRepository: auth, isAuthenticated: false);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: LoginView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('btn-google-sign-in')), findsOneWidget);
      expect(find.text('Thử kết nối lại'), findsOneWidget);
      auth.offline = false;
      await tester.ensureVisible(find.text('Thử kết nối lại'));
      await tester.tap(find.text('Thử kết nối lại'));
      await tester.pumpAndSettle();
      expect(state.socialProvidersUnavailable, false);
      expect(find.byKey(const ValueKey('btn-google-sign-in')), findsOneWidget);
      expect(find.text('Thử kết nối lại'), findsNothing);
      auth.googleEnabled = false;
      await state.loadSocialProviders();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('btn-google-sign-in')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
