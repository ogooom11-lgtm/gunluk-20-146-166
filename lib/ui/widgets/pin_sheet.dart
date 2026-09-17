import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../app_scope.dart';
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

  /// الكتابة من كيبورد الجهاز (خيار متاح دائمًا بجانب لوحة الأرقام).
  bool _kbMode = false;
  final TextEditingController _kbText = TextEditingController();
  final FocusNode _kbFocus = FocusNode();

  @override
  void dispose() {
    _kbText.dispose();
    _kbFocus.dispose();
    super.dispose();
  }

  void _toggleKeyboard() {
    HapticFeedback.selectionClick();
    setState(() {
      _kbMode = !_kbMode;
      _error = null;
      _state = PinState.idle;
      if (_kbMode) {
        _kbText.text = _digits.join();
        _kbText.selection = TextSelection.collapsed(offset: _kbText.text.length);
      } else {
        _digits
          ..clear()
          ..addAll(_kbText.text.split(''));
      }
    });
    if (_kbMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kbFocus.requestFocus();
      });
    } else {
      _kbFocus.unfocus();
    }
  }

  void _onKeyboardChanged(String value) {
    if (_busy) return;
    final String clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean != value) {
      _kbText.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    setState(() {
      _digits
        ..clear()
        ..addAll(clean.split(''));
      _error = null;
      _state = PinState.idle;
    });
    if (_digits.length >= _target) {
      Timer(const Duration(milliseconds: 140), () {
        if (mounted) _submit();
      });
    }
  }

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
    if (_kbText.text.isNotEmpty) _kbText.clear();
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
    _kbFocus.unfocus();
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _kbMode
                    ? TextField(
                        key: const ValueKey<String>('pin_sheet_keyboard'),
                        controller: _kbText,
                        focusNode: _kbFocus,
                        enabled: !_busy,
                        obscureText: true,
                        obscuringCharacter: '●',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: AppSettings.maxPinLength,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onKeyboardChanged,
                        onSubmitted: (_) => _submit(),
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: context.tr('security.pinEnter'),
                          prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                        ),
                      )
                    : PinPad(
                        key: const ValueKey<String>('pin_sheet_pad'),
                        enabled: !_busy,
                        maxKeySize: MediaQuery.of(context).size.height > 760 ? 74 : 66,
                        onDigit: _push,
                        onBackspace: _pop,
                        onClearAll: _clear,
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _busy ? null : _toggleKeyboard,
                    icon: Icon(_kbMode ? Icons.dialpad_rounded : Icons.keyboard_alt_outlined, size: 17),
                    label: Text(context.tr(_kbMode ? 'security.usePad' : 'security.useKeyboard')),
                  ),
                  const Spacer(),
                  if (_busy)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Flexible(
                      child: Text(
                        context.tr('security.pinNumbersOnly'),
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
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
      length: AppSettings.clampPinLength(length),
      confirmLength: confirmLength == null ? null : AppSettings.clampPinLength(confirmLength),
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
      length: AppSettings.clampPinLength(length),
    ),
  );
  return ok ?? false;
}


/// ورقة اختيار طول كلمة المرور: خيارات سريعة + خانة مخصّصة حتى ٦٤.
/// تعيد الطول المختار أو null عند الإلغاء.
Future<int?> showPinLengthSheet(
  BuildContext context, {
  required int current,
}) {
  const List<int> quick = <int>[4, 5, 6, 7, 8, 9, 10, 12, 16, 20, 24, 32, 48, 64];
  final TextEditingController custom = TextEditingController();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(ctx.gap.screenPadding, 14, ctx.gap.screenPadding, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.palette.seed.withAlpha(70),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Icon(Icons.pin_rounded, size: 20, color: ctx.palette.seed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(ctx.tr('security.pinLength'), style: Theme.of(ctx).textTheme.titleMedium),
                          Text(ctx.tr('security.pinLengthDesc'), style: Theme.of(ctx).textTheme.labelSmall),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: ctx.tr('common.cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final int n in quick)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: n == current,
                        onSelected: (_) => Navigator.of(ctx).pop(n),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: custom,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textDirection: TextDirection.ltr,
                        maxLength: 2,
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: ctx.tr('security.pinLengthCustom'),
                          helperText: ctx.tr('security.pinLengthRange'),
                        ),
                        onSubmitted: (_) {
                          final int? n = int.tryParse(custom.text.trim());
                          if (n == null) return;
                          Navigator.of(ctx).pop(AppSettings.clampPinLength(n));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        final int? n = int.tryParse(custom.text.trim());
                        if (n == null) return;
                        Navigator.of(ctx).pop(AppSettings.clampPinLength(n));
                      },
                      child: Text(ctx.tr('common.confirm')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
