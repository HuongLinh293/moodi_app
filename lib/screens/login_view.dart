import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/http_client.dart';
import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../state/mindra_state.dart';
import 'home_shell.dart';

// ─────────────────────────────────────────
// Entry: Auth Gate — Check if user is authenticated
// ─────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final state = context.read<MindraState>();
    // Check if user is already authenticated
    if (state.isAuthenticated && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindraState>();
    if (state.isAuthenticated) return const HomeShell();
    return const LoginView();
  }
}

// ─────────────────────────────────────────
// LoginView — Màn hình Đăng nhập / Đăng ký
// ─────────────────────────────────────────
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
    context.read<MindraState>().loadSocialProviders();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
      _confirmPassCtrl.clear();
    });
    _slideCtrl
      ..reset()
      ..forward();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.lightImpact();

    final state = context.read<MindraState>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      // MindraApp chuyển sang Home khi luồng đăng nhập phát user mới.
      if (_isRegisterMode) {
        await state.register(email, pass, email.split('@').first);
      } else {
        await state.login(email, pass);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() => _socialSignIn(
    context.read<MindraState>().signInWithGoogle,
    'Không thể kết nối tài khoản Google. Vui lòng thử lại.',
  );

  Future<void> _signInWithApple() => _socialSignIn(
    context.read<MindraState>().signInWithApple,
    'Không thể kết nối tài khoản Apple. Vui lòng thử lại.',
  );

  Future<void> _socialSignIn(
    Future<void> Function() signIn,
    String fallbackMessage,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.lightImpact();
    try {
      await signIn();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e is ApiException
            ? _mapAuthError(e)
            : fallbackMessage,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(Object error) {
    if (error is! ApiException) {
      return 'Có lỗi xảy ra. Vui lòng thử lại.';
    }
    return switch (error.statusCode) {
      null || 408 => 'Không thể kết nối dịch vụ đăng nhập. Kiểm tra kết nối mạng và thử lại.',
      401 => 'Email hoặc mật khẩu không đúng.',
      429 => 'Quá nhiều lần thử. Vui lòng đợi một lúc rồi thử lại.',
      503 => 'Phương thức đăng nhập này chưa được bật trên máy chủ.',
      400 when error.message.contains('đã tồn tại') =>
        'Email này đã được đăng ký. Hãy đăng nhập.',
      400 when error.message.contains('password') =>
        'Mật khẩu cần từ 8 ký tự trở lên.',
      400 when error.message.contains('email') => 'Email không hợp lệ.',
      _ => 'Đăng nhập không thành công. Vui lòng thử lại.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final social = context.watch<MindraState>().socialProviders;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: GestureDetector(
          onTap: FocusScope.of(context).unfocus,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 48, 24, mq.viewInsets.bottom + 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo + Header ──
                    _buildHeader(),
                    const SizedBox(height: 40),
                    // ── Form ──
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildEmailField(),
                          const SizedBox(height: 14),
                          _buildPasswordField(),
                          if (_isRegisterMode) ...[
                            const SizedBox(height: 14),
                            _buildConfirmPasswordField(),
                          ],
                        ],
                      ),
                    ),
                    // ── Error ──
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(),
                    ],
                    const SizedBox(height: 28),
                    // ── CTA Button ──
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                    // ── Toggle Mode ──
                    _buildToggleMode(),
                    // ── Google & Apple: chỉ hiện khi app và server đã cấu hình ──
                    if (social.google || social.apple) ...[
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 20),
                      _buildSocialButtons(social),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            'moodi ✦',
            style: AppTypography.kicker.copyWith(
              color: AppColors.ink,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isRegisterMode ? 'Tạo tài khoản' : 'Chào mừng trở lại',
          style: AppTypography.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _isRegisterMode
              ? 'Tạo tài khoản để nhật ký của bạn luôn được lưu an toàn.'
              : 'Đăng nhập để tiếp tục hành trình cảm xúc của bạn.',
          style: AppTypography.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return _InputField(
      controller: _emailCtrl,
      label: 'Email',
      hint: 'ban@email.com',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
        if (!v.contains('@') || !v.contains('.')) return 'Email không hợp lệ';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _InputField(
      controller: _passCtrl,
      label: 'Mật khẩu',
      hint: '••••••••',
      obscureText: _obscurePass,
      textInputAction: _isRegisterMode
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: _isRegisterMode ? null : (_) => _submit(),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePass
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.textMuted,
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePass = !_obscurePass),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
        if (_isRegisterMode && v.length < 8) {
          return 'Mật khẩu cần ít nhất 8 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return _InputField(
      controller: _confirmPassCtrl,
      label: 'Xác nhận mật khẩu',
      hint: '••••••••',
      obscureText: _obscureConfirm,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureConfirm
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.textMuted,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
        if (v != _passCtrl.text) return 'Mật khẩu xác nhận không khớp';
        return null;
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange.withAlpha(60), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          disabledBackgroundColor: AppColors.ink.withAlpha(100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.paper,
                ),
              )
            : Text(
                _isRegisterMode ? 'Tạo tài khoản' : 'Đăng nhập',
                style: AppTypography.button.copyWith(color: AppColors.paper),
              ),
      ),
    );
  }

  Widget _buildToggleMode() {
    return Center(
      child: GestureDetector(
        key: const ValueKey('toggle-auth-mode'),
        onTap: _isLoading ? null : _toggleMode,
        child: RichText(
          text: TextSpan(
            style: AppTypography.bodySmall,
            children: [
              TextSpan(
                text: _isRegisterMode
                    ? 'Đã có tài khoản? '
                    : 'Chưa có tài khoản? ',
              ),
              TextSpan(
                text: _isRegisterMode ? 'Đăng nhập' : 'Đăng ký ngay',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('hoặc', style: AppTypography.caption),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }

  Widget _buildSocialButtons(({bool google, bool apple}) social) {
    return Column(
      children: [
        if (social.google)
          _buildSocialButton(
            key: const ValueKey('btn-google-sign-in'),
            label: _isRegisterMode
                ? 'Đăng ký bằng Google'
                : 'Tiếp tục với Google',
            icon: SvgPicture.string(
              '''<svg viewBox="0 0 24 24" width="20" height="20" xmlns="http://www.w3.org/2000/svg">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" fill="#EA4335"/>
</svg>''',
              width: 20,
              height: 20,
            ),
            onPressed: _isLoading ? null : _signInWithGoogle,
          ),
        if (social.google && social.apple) const SizedBox(height: 10),
        if (social.apple)
          _buildSocialButton(
            key: const ValueKey('btn-apple-sign-in'),
            label: _isRegisterMode
                ? 'Đăng ký bằng Apple'
                : 'Tiếp tục với Apple',
            icon: const Icon(Icons.apple, color: AppColors.ink, size: 22),
            onPressed: _isLoading ? null : _signInWithApple,
          ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Key key,
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.button.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Reusable Input Field
// ─────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: AppColors.textTertiary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.cream,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.ink, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.8),
            ),
            errorStyle: AppTypography.caption.copyWith(color: AppColors.orange),
          ),
        ),
      ],
    );
  }
}
