import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
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

class _MindraAppState extends State<MindraApp> with WidgetsBindingObserver {
  MindraState? _lifecycleState;
  bool _privacyCover = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed &&
        _lifecycleState?.appLockEnabled == true)
      FocusManager.instance.primaryFocus?.unfocus();
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      _lifecycleState?.lockApplication();
    }
    if (mounted) {
      setState(() => _privacyCover = lifecycle != AppLifecycleState.resumed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appContent = Consumer<MindraState>(
      builder: (context, state, _) {
        _lifecycleState = state;
        Widget home;
        if (state.startingUp && !state.isAuthenticated) {
          // Đang đọc cài đặt / khôi phục phiên: chờ thay vì chớp onboarding.
          home = const _StartupSplash();
        } else if (!state.onboardingCompleted) {
          home = const OnboardingView();
        } else if (!state.isAuthenticated) {
          // Onboarding xong nhưng chưa đăng nhập (sau logout hoặc fresh install)
          home = const LoginView();
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
          builder: (context, child) {
            final locked =
                state.isAuthenticated &&
                state.appLockEnabled &&
                !state.appUnlocked;
            final hidden = locked || (_privacyCover && state.appLockEnabled);
            return Stack(
              children: [
                ExcludeSemantics(
                  excluding: hidden,
                  child: ExcludeFocus(
                    excluding: hidden,
                    child: IgnorePointer(ignoring: hidden, child: child!),
                  ),
                ),
                if (hidden)
                  Positioned.fill(
                    child: locked
                        ? AppLockView(state: state)
                        : const _StartupSplash(),
                  ),
              ],
            );
          },
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
      create: (_) => MindraState()
        ..loadReminder()
        ..loadLocalPreferences(),
      child: appContent,
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    body: Center(
      // Tĩnh, không hoạt ảnh: thường chỉ hiện trong chốc lát khi mở app.
      child: Semantics(
        label: 'Đang mở Moodi',
        child: Text(
          'moodi',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ),
    ),
  );
}
