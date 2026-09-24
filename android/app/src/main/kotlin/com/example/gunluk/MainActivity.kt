package com.example.gunluk

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

/**
 * جسر بسيط مع نظام أندرويد لخدمة الملفات (بدون حزم خارجية):
 * - saveFile: يفتح مستكشف الملفات ليختار المستخدم مكان الحفظ (SAF).
 * - pickFile: يفتح المستكشف لاختيار ملف نسخة احتياطية وقراءة محتواه.
 * - setSecure: يمنع التقاط الشاشة أو ظهور المحتوى في مبدّل التطبيقات.
 *
 * وقناة ثانية للحماية (injaz/security):
 * - authenticate: نافذة التعرّف على الوجه/البصمة (أو قفل الجهاز) قبل كشف
 *   تفاصيل المنبّه. تُعيد "ok" أو "failed" أو "unavailable".
 *
 * ملاحظة: نستخدم FlutterFragmentActivity لأن نافذة التعرّف (androidx.biometric)
 * تحتاج FragmentActivity، وFlutterActivity العادية لا تصلح لذلك.
 */
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "injaz/files"
    private val saveRequest = 4001
    private val pickRequest = 4002

    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var pendingName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(true)
                    "saveFile" -> handleSaveFile(call.argument("name"), call.argument("bytes"), result)
                    "pickFile" -> handlePickFile(result)
                    "setSecure" -> {
                        setSecureScreen(call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(canAuthenticate())
                    "authenticate" -> authenticate(result)
                    "canFullScreen" -> result.success(canFullScreen())
                    "openFullScreenSettings" -> {
                        openFullScreenSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ===== التعرّف على الوجه/البصمة =====

    private val securityChannel = "injaz/security"
    private var authResult: MethodChannel.Result? = null

    /**
     * هل يسمح النظام بفتح شاشة كاملة من إشعار (أندرويد ١٤+ يحتاج موافقة
     * المستخدم من الإعدادات). على الإصدارات الأقدم مسموح دائمًا.
     */
    private fun canFullScreen(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(NotificationManager::class.java)
        return manager?.canUseFullScreenIntent() ?: true
    }

    /** فتح صفحة النظام للسماح بشاشة المنبّه الكاملة. */
    private fun openFullScreenSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (e: Exception) {
            // بعض الأجهزة لا توفّر الصفحة — نكتفي بالإشعار العادي.
        }
    }

    /** هل يمكن للجهاز التحقّق (وجه/بصمة أو قفل شاشة)؟ */
    private fun canAuthenticate(): Boolean {
        val allowed = BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        return BiometricManager.from(this).canAuthenticate(allowed) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    /** يعرض نافذة التحقّق ويُعيد النتيجة إلى دارت. */
    private fun authenticate(result: MethodChannel.Result) {
        if (!canAuthenticate()) {
            result.success("unavailable")
            return
        }
        if (authResult != null) {
            result.error("busy", "هناك تحقّق جارٍ", null)
            return
        }
        authResult = result
        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    auth: BiometricPrompt.AuthenticationResult,
                ) {
                    authResult?.success("ok")
                    authResult = null
                }

                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    authResult?.success("failed")
                    authResult = null
                }

                override fun onAuthenticationFailed() {
                    // محاولة فاشلة — تبقى النافذة معروضة للمحاولة مرة أخرى.
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("تأكيد الهوية")
            .setSubtitle("أظهر وجهك أو استخدم قفل الجهاز لعرض التفاصيل")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
            .build()
        try {
            prompt.authenticate(info)
        } catch (e: Exception) {
            authResult?.success("unavailable")
            authResult = null
        }
    }

    private fun handleSaveFile(name: String?, bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null) {
            result.error("no_data", "لا توجد بيانات للحفظ", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "هناك عملية ملفات جارية", null)
            return
        }
        pendingResult = result
        pendingBytes = bytes
        pendingName = name ?: "injazi-backup.json"

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, pendingName)
        }
        try {
            startActivityForResult(intent, saveRequest)
        } catch (error: Exception) {
            clearPending()
            result.error("no_picker", error.message, null)
        }
    }

    private fun handlePickFile(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "هناك عملية ملفات جارية", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            startActivityForResult(intent, pickRequest)
        } catch (error: Exception) {
            clearPending()
            result.error("no_picker", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != saveRequest && requestCode != pickRequest) return
        val result = pendingResult
        val uri: Uri? = data?.data

        if (result == null) {
            clearPending()
            return
        }
        if (resultCode != Activity.RESULT_OK || uri == null) {
            clearPending()
            result.success(null)
            return
        }

        if (requestCode == saveRequest) {
            val bytes = pendingBytes
            val name = pendingName
            clearPending()
            if (bytes == null) {
                result.error("no_data", "لا توجد بيانات للحفظ", null)
                return
            }
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IllegalStateException("تعذّر فتح الملف للحفظ")
                result.success(name)
            } catch (error: Exception) {
                result.error("write_failed", error.message, null)
            }
            return
        }

        // اختيار ملف: نقرأ أول ٤ ميجابايت كحد أقصى.
        clearPending()
        try {
            val input: InputStream? = contentResolver.openInputStream(uri)
            if (input == null) {
                result.error("read_failed", "تعذّر فتح الملف", null)
                return
            }
            val buffer = ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            var total = 0
            input.use { stream ->
                while (true) {
                    val read = stream.read(chunk)
                    if (read <= 0) break
                    total += read
                    if (total > 4 * 1024 * 1024) break
                    buffer.write(chunk, 0, read)
                }
            }
            val payload = mapOf(
                "name" to (queryFileName(uri) ?: "backup"),
                "bytes" to buffer.toByteArray()
            )
            result.success(payload)
        } catch (error: Exception) {
            result.error("read_failed", error.message, null)
        }
    }

    private fun queryFileName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            }
        } catch (error: Exception) {
            null
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingBytes = null
        pendingName = null
    }

    private fun setSecureScreen(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}
