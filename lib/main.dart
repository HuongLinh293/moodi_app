import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme.dart';
import 'state/mindra_state.dart';
import 'screens/app_lock_view.dart';
import 'screens/home_shell.dart';
import 'screens/login_view.dart';
import 'screens/onboarding_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MindraApp());
}

class MindraApp extends StatefulWidget {
  final MindraState? state;
  const MindraApp({super.key, this.state});

  @override
  State<MindraApp> createState() => _MindraAppState();
}

class _MindraAppState extends State<MindraApp> {
  bool _unlockedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final appContent = Consumer<MindraState>(
      builder: (context, state, _) {
        Widget home;
        if (!state.onboardingCompleted) {
          home = const OnboardingView();
        } else if (!state.isAuthenticated) {
          // Onboarding xong nhưng chưa đăng nhập (sau logout hoặc fresh install)
          home = const LoginView();
        } else if (state.appLockEnabled && !_unlockedThisSession) {
          home = AppLockView(
            state: state,
            onUnlocked: () => setState(() => _unlockedThisSession = true),
          );
        } else {
          home = const HomeShell();
        }

        return MaterialApp(
          key: ValueKey(
            '${state.isAuthenticated}:${state.currentUserId}:${state.sessionRevision}',
          ),
          title: 'Moodi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: home,
        );
      },
    );

    if (widget.state != null) {
      return ChangeNotifierProvider<MindraState>.value(
        value: widget.state!,
        child: appContent,
      );
    }

    return ChangeNotifierProvider<MindraState>(
      create: (_) => MindraState()..loadReminder(),
      child: appContent,
    );
  }
}
