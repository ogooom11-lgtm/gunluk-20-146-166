import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../app_scope.dart';
import 'common.dart';
import 'pin_pad.dart';

/// وضع الورقة: تعيين رمز جديد (مع تأكيد) أو التحقق من الرمز الحالي.
enum _PinMode { setup, verify }

/// ورقة إدخال الرمز بالأرقام فقط — لوحة مخصّصة + نقاط متحرّكة.
class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.mode,
    required this.title,
    this.subtitle,
    this.length = 4,
    this.confirmLength,
  });

  final _PinMode mode;
  final String title;
  final String? subtitle;
  final int length;
  final int? confirmLength;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final List<String> _digits = <String>[];
  String? _firstPin;
  String? _error;
  PinState _state = PinState.idle;
  int _shake = 0;
  bool _busy = false;

  /// طول الرمز المطلوب في الخطوة الحالية.
  int get _target {
    if (widget.mode == _PinMode.setup && _firstPin != null) {
      return widget.confirmLength ?? widget.length;
    }
    return widget.length;
  }

  bool get _confirming => widget.mode == _PinMode.setup && _firstPin != null;

  void _push(String digit) {
    if (_busy || _digits.length >= _target) return;
    setState(() {
      _digits.add(digit);
      _error = null;
      _state = PinState.idle;
    });
    if (_digits.length == _target) {
      // عند اكتمال الرمز ننتقل تلقائيًا للخطوة التالية/التحقق.
      Timer(const Duration(milliseconds: 140), () {
        if (mounted) _submit();
      });
    }
  }

  void _pop() {
    if (_busy || _digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = null;
      _state = PinState.idle;
    });
  }

  void _clear() {
    if (_busy || _digits.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _digits.clear();
      _error = null;
      _state = PinState.idle;
    });
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _state = PinState.error;
      _shake++;
    });
    Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _digits.clear();
        _state = PinState.idle;
      });
    });
  }

  Future<void> _submit() async {
    if (_busy || _digits.length < _target) return;
    final String pin = _digits.join();
    if (widget.mode == _PinMode.verify) {
      setState(() {
        _busy = true;
        _state = PinState.verifying;
      });
      final bool ok = await context.appRead.verifyLockPin(pin);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) {
        _fail(context.tr('security.wrongPassword'));
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _state = PinState.success);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    // وضع التعيين: الخطوة الأولى ثم التأكيد.
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _digits.clear();
      });
      return;
    }
    if (_firstPin != pin) {
      setState(() => _firstPin = null);
      _fail(context.tr('security.pinMismatch'));
      return;
    }
    setState(() => _state = PinState.success);
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (mounted) Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final String hint = _confirming
        ? context.tr('security.pinConfirm')
        : (widget.mode == _PinMode.setup
            ? context.tr('security.pinNew', <String, String>{'n': context.numStr(_target)})
            : context.tr('security.pinEnter'));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.gap.screenPadding, 14, context.gap.screenPadding, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.seed.withAlpha(70),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(Icons.lock_outline_rounded, size: 20, color: context.palette.seed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!, style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.tr('common.cancel'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(hint, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 18),
              ShakeWidget(
                trigger: _shake,
                child: PinDots(
                  length: _target,
                  filled: _digits.length,
                  state: _state,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox(height: 18)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE05B5B)),
                            const SizedBox(width: 6),
                            Flexible(
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
                      ),
              ),
              const SizedBox(height: 6),
              PinPad(
                enabled: !_busy,
                maxKeySize: 66,
                onDigit: _push,
                onBackspace: _pop,
                onClearAll: _clear,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.dialpad_rounded, size: 15, color: context.palette.seed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('security.pinNumbersOnly'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (_busy)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// إظهار ورقة تعيين رمز جديد (أرقام فقط) مع تأكيد.
/// يعيد الرمز، أو null عند الإلغاء.
Future<String?> showPinSetupSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int length = 4,
  int? confirmLength,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => _PinSheet(
      mode: _PinMode.setup,
      title: title,
      subtitle: subtitle,
      length: length,
      confirmLength: confirmLength,
    ),
  );
}

/// إظهار ورقة التحقق من الرمز الحالي. تعيد true عند النجاح.
Future<bool> showPinVerifySheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int length = 4,
}) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => _PinSheet(
      mode: _PinMode.verify,
      title: title,
      subtitle: subtitle,
      length: length,
    ),
  );
  return ok ?? false;
}
