import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import '../widgets/pin_pad.dart';
import '../widgets/pickers.dart';
import '../widgets/progress_ring.dart';

/// شاشة القفل: لوحة أرقام مخصّصة + نقاط متحرّكة + فتح تلقائي اختياري.
///
/// - الرمز أرقام فقط، وعدد خاناته من الإعدادات (افتراضي ٤).
/// - عند تفعيل «الفتح التلقائي» يُفتح التطبيق بمجرد اكتمال الرمز الصحيح.
/// - عند إيقافه يظهر زر ✓ للتأكيد.
/// - بعد كل ٣ محاولات خاطئة يتوقف الإدخال ٣٠ ثانية مع عدّاد دائري.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final List<String> _digits = <String>[];
  PinState _state = PinState.idle;
  String? _error;
  bool _busy = false;
  int _attempts = 0;
  int _waitSeconds = 0;
  int _shake = 0;
  Timer? _timer;

  /// حركة دخول الشاشة.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  int get _pinLength {
    final int stored = context.appRead.settings.lockPinLength;
    return stored >= 4 ? stored : 4;
  }

  bool get _autoUnlock => context.appRead.settings.lockAutoUnlock;

  bool get _legacy => context.appRead.settings.lockPinLength <= 0;

  @override
  void dispose() {
    _timer?.cancel();
    _enter.dispose();
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

  void _push(String digit) {
    if (_busy || _waitSeconds > 0 || _digits.length >= _pinLength) return;
    setState(() {
      _digits.add(digit);
      _error = null;
      _state = PinState.idle;
    });
    // الفتح التلقائي: بمجرد اكتمال عدد الأرقام نتحقق مباشرة.
    if (_autoUnlock && _digits.length == _pinLength) {
      Timer(const Duration(milliseconds: 130), () {
        if (mounted) _submit();
      });
    }
  }

  void _pop() {
    if (_busy || _waitSeconds > 0 || _digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = null;
      _state = PinState.idle;
    });
  }

  void _clearAll() {
    if (_busy || _digits.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _digits.clear();
      _error = null;
      _state = PinState.idle;
    });
  }

  Future<void> _submit() async {
    if (_busy || _waitSeconds > 0 || _digits.length < _pinLength) return;
    final String pin = _digits.join();
    setState(() {
      _busy = true;
      _state = PinState.verifying;
      _error = null;
    });
    final bool ok = await context.appRead.unlock(pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      setState(() => _state = PinState.success);
      return;
    }
    // خطأ: اهتزاز + وميض أحمر ثم تفريغ النقاط.
    _attempts += 1;
    HapticFeedback.heavyImpact();
    setState(() {
      _error = context.tr('security.wrongPassword');
      _state = PinState.error;
      _shake++;
    });
    if (_attempts % 3 == 0) _startCooldown(30);
    Timer(const Duration(milliseconds: 560), () {
      if (!mounted) return;
      setState(() {
        _digits.clear();
        _state = PinState.idle;
      });
    });
  }

  Future<void> _legacyEntry() async {
    final String? pin = await showPasswordDialog(
      context,
      title: context.tr('security.legacyPin'),
      submitLabel: context.tr('security.unlock'),
      hint: context.tr('security.legacyPinDesc'),
    );
    if (pin == null || pin.isEmpty || !mounted) return;
    final bool ok = await context.appRead.unlock(pin);
    if (!mounted || ok) return;
    setState(() {
      _error = context.tr('security.wrongPassword');
      _shake++;
    });
    HapticFeedback.heavyImpact();
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
    final bool blocked = _waitSeconds > 0;
    final int remainingAttempts = 3 - (_attempts % 3);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
            colors: <Color>[
              context.palette.gradient.first.withAlpha(context.isDark ? 120 : 46),
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _enter, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
                CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.gap.screenPadding + 6,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _header(context, name),
                        _middle(context, blocked, remainingAttempts),
                        _keypad(context, blocked),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// الشعار والاسم والرسالة.
  Widget _header(BuildContext context, String name) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 6),
        _PulsingLogo(color: context.palette.seed, success: _state == PinState.success),
        const SizedBox(height: 16),
        Text(
          name.isEmpty ? context.tr('security.lockTitle') : name,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Text(
            _state == PinState.success
                ? context.tr('common.loading')
                : (_error ?? context.tr('security.lockMessage')),
            key: ValueKey<String>('${_state.name}-${_error ?? ''}'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _error != null && _state == PinState.error
                      ? const Color(0xFFE05B5B)
                      : null,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// النقاط + رسائل المساعدة/الانتظار.
  Widget _middle(BuildContext context, bool blocked, int remainingAttempts) {
    return Column(
      children: <Widget>[
        ShakeWidget(
          trigger: _shake,
          child: PinDots(
            length: _pinLength,
            filled: _digits.length,
            state: _state,
            dotSize: 18,
            spacing: 20,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: blocked
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        value: _waitSeconds / 30,
                        color: const Color(0xFFE0A02E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.tr('security.tooManyAttempts', <String, String>{
                          'n': context.numStr(_waitSeconds),
                        }),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: const Color(0xFFE0A02E)),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          _autoUnlock ? Icons.bolt_rounded : Icons.touch_app_rounded,
                          size: 15,
                          color: context.palette.seed.withAlpha(190),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr(_autoUnlock ? 'security.autoUnlockHint' : 'security.manualUnlockHint'),
                            style: Theme.of(context).textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    if (_attempts > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        context.tr('security.attemptsLeft', <String, String>{
                          'n': context.numStr(remainingAttempts),
                        }),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// لوحة الأرقام + روابط المساعدة.
  Widget _keypad(BuildContext context, bool blocked) {
    return Column(
      children: <Widget>[
        PinPad(
          enabled: !blocked && !_busy,
          onDigit: _push,
          onBackspace: _pop,
          onClearAll: _clearAll,
          // زر التأكيد يظهر فقط عندما يكون الفتح التلقائي معطّلًا.
          onConfirm: _autoUnlock ? null : _submit,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (_legacy)
              TextButton.icon(
                onPressed: _legacyEntry,
                icon: const Icon(Icons.password_rounded, size: 17),
                label: Text(context.tr('security.legacyPin')),
              )
            else
              const SizedBox(width: 8),
            TextButton(
              onPressed: _forgot,
              child: Text(context.tr('security.pinForgot')),
            ),
          ],
        ),
        Text(
          context.tr('security.pinLockedTip'),
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('security.encryptedHint'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).textTheme.labelSmall?.color?.withAlpha(150),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// شعار بنبض هادئ، يتحول إلى اللون الأخضر عند نجاح الرمز.
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo({required this.color, required this.success});

  final Color color;
  final bool success;

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.success ? const Color(0xFF2FA86A) : widget.color;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1 + t * 0.045,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.palette.linearGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withAlpha((40 + t * 60).round()),
                  blurRadius: 26 + t * 18,
                  spreadRadius: 2 + t * 3,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: AppLogomark(size: 54, color: Colors.white),
    );
  }
}
