import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
// LoginView — Login / Register Screen
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
  final _passwordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<MindraState>();
    _clearError();

    try {
      if (_isRegisterMode) {
        await state.register(
          _emailCtrl.text,
          _passwordCtrl.text,
          _displayNameCtrl.text,
        );
      } else {
        await state.login(_emailCtrl.text, _passwordCtrl.text);
      }

      if (mounted && state.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _setError(_isRegisterMode ? 'Đăng ký thất bại' : 'Đăng nhập thất bại');
    }
  }

  void _setError(String msg) {
    setState(() => _errorMessage = msg);
  }

  void _clearError() {
    setState(() => _errorMessage = null);
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
      _displayNameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindraState>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Moodi',
                      style: MindraTypography.heading1.copyWith(
                        color: MindraColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _isRegisterMode ? 'Tạo tài khoản' : 'Đăng nhập',
                      style: MindraTypography.heading3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Display Name (Register only)
                        if (_isRegisterMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: _displayNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Tên hiển thị',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? 'Nhập tên' : null,
                            ),
                          ),

                        // Email
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Nhập email';
                              if (!v!.contains('@')) return 'Email không hợp lệ';
                              return null;
                            },
                          ),
                        ),

                        // Password
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: TextFormField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Nhập mật khẩu';
                              if (v!.length < 6)
                                return 'Mật khẩu ít nhất 6 ký tự';
                              return null;
                            },
                          ),
                        ),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border:
                                    Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MindraColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode ? 'Đăng ký' : 'Đăng nhập',
                                    style: MindraTypography.button.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Toggle Mode Button
                        Center(
                          child: GestureDetector(
                            onTap: _toggleMode,
                            child: RichText(
                              text: TextSpan(
                                text: _isRegisterMode
                                    ? 'Đã có tài khoản? '
                                    : 'Chưa có tài khoản? ',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: _isRegisterMode
                                        ? 'Đăng nhập'
                                        : 'Đăng ký',
                                    style: TextStyle(
                                      color: MindraColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Powered by Moodi API',
                      style: MindraTypography.bodySmall.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
