import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/app_strings.dart';
import '../core/models/app_settings.dart';
import '../data/app_state.dart';
import '../ui/app_scope.dart';
import '../ui/widgets/pin_sheet.dart';

/// التحقّق من هوية صاحب الجهاز قبل كشف محتوى المنبّه.
///
/// الترتيب:
///   1. التعرّف على الوجه/البصمة (قفل الجهاز نفسه) عبر قناة أصلية.
///   2. إن لم يتوفّر: رمز التطبيق نفسه (نفس قفل التطبيق).
///   3. إن لم يكن هناك أي قفل على الإطلاق: لا شيء لنحميه ⇒ نُظهر التفاصيل.
Future<bool> verifyIdentityForAlarm(BuildContext context) async {
  final AppState app = context.appRead;
  if (!app.settings.alarmRequireUnlock) return true;

  // (1) الوجه/البصمة من نظام الجهاز.
  final String? result = await _deviceBiometrics();
  if (result == 'ok') return true;

  if (!context.mounted) return false;

  // (2) رمز التطبيق.
  if (app.settings.lockEnabled && app.settings.lockHash.isNotEmpty) {
    final bool usePasscode = await _askPasscode(context, unavailable: result == 'unavailable');
    if (!usePasscode) return false;
    if (!context.mounted) return false;
    final int length = AppSettings.clampPinLength(app.settings.lockPinLength);
    if (length >= AppSettings.minPinLength) {
      return showPinVerifySheet(
        context,
        title: context.tr('alarm.verifyTitle'),
        subtitle: context.tr('alarm.verifySubtitle'),
        length: length,
      );
    }
  }

  // (3) لا قفل على الإطلاق.
  return true;
}

/// مناداة نظام أندرويد لعرض نافذة التعرّف على الوجه/البصمة.
///
/// تعيد: 'ok' عند النجاح، 'failed' عند الفشل أو الإلغاء، 'unavailable' إذا لم
/// يوجد تعرّف وجه مُسجَّل على الجهاز أو القناة غير متاحة (مثل الاختبارات).
Future<String?> _deviceBiometrics() async {
  try {
    final String? outcome = await const MethodChannel('injaz/security')
        .invokeMethod<String>('authenticate', <String, dynamic>{'reason': 'alarm'});
    if (outcome == 'ok' || outcome == 'failed' || outcome == 'unavailable') return outcome;
    return 'unavailable';
  } on MissingPluginException {
    return 'unavailable';
  } on PlatformException {
    return 'unavailable';
  }
}

/// سؤال المستخدم: التعذّر أو الفشل ⇒ عرض خيار رمز التطبيق.
Future<bool> _askPasscode(BuildContext context, {required bool unavailable}) async {
  final bool? use = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(ctx.tr('alarm.verifyTitle')),
      content: Text(ctx.tr(unavailable ? 'alarm.verifyUnavailable' : 'alarm.verifyFailed')),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.tr('alarm.usePasscode')),
        ),
      ],
    ),
  );
  return use ?? false;
}

/// هل يسمح النظام بالشاشة الكاملة للمنبّه؟ (أندرويد ١٤+ يحتاج موافقة المستخدم)
Future<bool> alarmFullScreenAvailable() async {
  try {
    final bool? ok = await const MethodChannel('injaz/security')
        .invokeMethod<bool>('canFullScreen');
    return ok ?? true;
  } on MissingPluginException {
    return true;
  } on PlatformException {
    return true;
  }
}

/// فتح صفحة النظام للسماح بشاشة المنبّه الكاملة.
Future<void> openAlarmFullScreenSettings() async {
  try {
    await const MethodChannel('injaz/security')
        .invokeMethod<void>('openFullScreenSettings');
  } on MissingPluginException {
    // لا شيء: القناة غير متاحة (اختبارات أو سطح مكتب).
  } on PlatformException {
    // تجاهل.
  }
}
