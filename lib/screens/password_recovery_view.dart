import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/http_client.dart';

class PasswordRecoveryView extends StatefulWidget {
  const PasswordRecoveryView({super.key, this.initialEmail = '', this.client});
  final String initialEmail;
  final HttpClient? client;
  @override
  State<PasswordRecoveryView> createState() => _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends State<PasswordRecoveryView> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  String? _requestId, _error, _message;
  bool _busy = false;
  HttpClient get _client => widget.client ?? HttpClient();
  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _client.post(
        '/auth/forgot-password',
        body: {'email': _email.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        _requestId = (response as Map)['requestId'] as String;
        _message = response['message'] as String;
        _code.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.statusCode == 503
              ? 'Khôi phục mật khẩu chưa sẵn sàng. Hãy thử phương thức Google/Apple đã liên kết hoặc quay lại sau.'
              : e is ApiException && e.statusCode == 429
              ? 'Bạn đã yêu cầu nhiều lần. Hãy đợi một phút rồi thử lại.'
              : 'Chưa gửi được yêu cầu. Kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.post(
        '/auth/reset-password',
        body: {
          'requestId': _requestId,
          'code': _code.text.trim(),
          'password': _password.text,
        },
      );
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.statusCode == 400
              ? 'Mã không đúng, hết hạn hoặc đã dùng. Mật khẩu cần từ 8 ký tự và tối đa 72 byte.'
              : 'Chưa đổi được mật khẩu. Kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nhận mã qua email để đặt mật khẩu mới. Các phiên đăng nhập cũ sẽ kết thúc sau khi đổi thành công.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  enabled: !_busy && _requestId == null,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? 'Nhập email hợp lệ'
                      : null,
                ),
                if (_requestId != null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mã 6 chữ số (hiệu lực 10 phút)',
                    ),
                    validator: (v) =>
                        v?.trim().length == 6 ? null : 'Nhập đủ mã 6 chữ số',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) >= 8 ? null : 'Cần ít nhất 8 ký tự',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                    ),
                    validator: (v) =>
                        v == _password.text ? null : 'Hai mật khẩu chưa khớp',
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(liveRegion: true, child: Text(_message!)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : _requestId == null
                      ? _request
                      : _reset,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _busy
                          ? 'Đang xử lý…'
                          : _requestId == null
                          ? 'Gửi mã khôi phục'
                          : 'Đặt mật khẩu mới',
                    ),
                  ),
                ),
                if (_requestId != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _requestId = null;
                              _message = null;
                              _error = null;
                            });
                          },
                    child: const Text('Đổi email hoặc yêu cầu mã mới'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
