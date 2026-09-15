import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/progress_ring.dart';

/// شاشة القفل: تُعرض عند فتح التطبيق وعند العودة إليه بعد انتهاء مهلة السماح.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  int _attempts = 0;
  int _waitSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _waitSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _waitSeconds -= 1);
      if (_waitSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_busy || _waitSeconds > 0) return;
    final String password = _controller.text;
    if (password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // التحقق يتم في عزلة الحساب نفسها (PBKDF2 ثقيل نسبيًا).
    final bool ok = await context.appRead.unlock(password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) return;
    _attempts += 1;
    _controller.clear();
    setState(() => _error = context.tr('security.wrongPassword'));
    // تخفيف هجمات التخمين: تأخير متزايد بعد كل ٣ محاولات.
    if (_attempts % 3 == 0) {
      _startCooldown(30);
    }
    _focus.requestFocus();
  }

  Future<void> _forgot() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.tr('security.forgot')),
        content: Text(context.tr('security.forgotDesc')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('common.close')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE05B5B)),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmReset();
            },
            child: Text(context.tr('security.resetApp')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: context.tr('security.resetApp'),
      message: context.tr('security.resetAppConfirm'),
      confirmLabel: context.tr('common.delete'),
    );
    if (!confirmed) return;
    await context.appRead.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final String name = app.settings.name.trim();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.gap.screenPadding + 8, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const AppLogomark(size: 84),
                const SizedBox(height: 18),
                Text(
                  name.isEmpty ? context.tr('security.lockTitle') : name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('security.lockMessage'),
                  style: Theme.of(context).textTheme.labelMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        obscureText: _obscure,
                        enabled: _waitSeconds <= 0,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: Theme.of(context).textTheme.titleMedium,
                        decoration: InputDecoration(
                          labelText: context.tr('security.password'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE05B5B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: const Color(0xFFE05B5B)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_waitSeconds > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          context.tr('security.tooManyAttempts', <String, String>{
                            'n': context.numStr(_waitSeconds),
                          }),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: const Color(0xFFE0A02E)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy || _waitSeconds > 0 ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(context.tr('security.unlock')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _forgot,
                  child: Text(context.tr('security.forgot')),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('security.encryptedHint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
