package com.twt.service.install


import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import com.twt.service.common.LogUtil
import com.twt.service.common.WbyPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

class WbyInstallPlugin : WbyPlugin(), ActivityAware, PluginRegistry.ActivityResultListener {

    override val name: String
        get() = "com.twt.service/install"

    private lateinit var activityBinding: ActivityPluginBinding
    private lateinit var resultFile: File
    private var methodCall: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        LogUtil.d(TAG, "onMethodCall + ${call.method}")

        kotlin.runCatching {
            when (call.method) {
                "install" -> {
                    val path = call.argument<String>("path")!!
                    if (methodCall != null) {
                        result.error("INSTALL_BUSY", "Installation already active", null)
                    } else {
                        methodCall = result
                        installAPK(path, call.argument<Number>("versionCode")?.toLong())
                    }
                }

                "goToMarket" -> goToMarket(result)
                "canGoToMarket" -> canGoToMarket(result)
                else -> result.notImplemented()
            }
        }.onFailure {
            LogUtil.e(TAG, it)
            result.error("", "$it", "")
        }
    }

    private fun canGoToMarket(result: MethodChannel.Result) {
        if (marketIntent.resolveActivity(context.packageManager) != null) {
            result.success(true)
        } else {
            result.success(false)
        }
    }

    /**
     * 跳转到应用市场的intent
     */
    private val marketIntent
        get() = Intent(Intent.ACTION_VIEW).apply {
            // 现在只上架了 HUAWEI,XIAOMI,OPPO,VIVO
            `package` = when (Build.BRAND.lowercase()) {
                "huawei", "honor" -> "com.huawei.appmarket"
                "xiaomi" -> "com.xiaomi.market"
                "oppo" -> "com.oppo.market"
                "vivo" -> "com.bbk.appstore"
                else -> null
            }
            // 去掉后缀
            val packageName = context.packageName.split(".").subList(0, 3).joinToString(".")
            data = Uri.parse("market://details?id=$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

    private fun goToMarket(result: MethodChannel.Result) {
        context.startActivity(marketIntent)
        result.success(true)
    }

    @Suppress("DEPRECATION")
    private fun installAPK(path: String, expectedVersionCode: Long?) {
        try {
            resultFile = File(path)
            require(resultFile.isFile) { "APK file is missing" }
            if (context.packageName == "com.twt.service.pad") {
                val pm = context.packageManager
                val archive = pm.getPackageArchiveInfo(path, PackageManager.GET_SIGNATURES)
                    ?: error("Invalid APK")
                val current = pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
                require(archive.packageName == context.packageName) { "APK package mismatch" }
                require(archive.signatures?.isNotEmpty() == true &&
                    archive.signatures?.toSet() == current.signatures?.toSet()) {
                    "APK signing certificate mismatch"
                }
                require(expectedVersionCode != null &&
                    PackageInfoCompat.getLongVersionCode(archive) == expectedVersionCode) {
                    "APK version does not match release metadata"
                }
                require(PackageInfoCompat.getLongVersionCode(archive) >
                    PackageInfoCompat.getLongVersionCode(current)) { "APK is not a newer version" }
            }
            activityBinding.addActivityResultListener(this)
            installApkWithSdkVersion()
        } catch (e: Exception) {
            completeInstall(e.message ?: "Could not start APK installation")
        }
    }

    private fun installApkWithSdkVersion() {
        // version < N 时 直接通过 intent 安装
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // N == version 或 canRequestPackageInstalls 直接安装
            // 因为 Android O(8) 之后安装未知来源应用需要申请权限
            // Android N(7) 之后需要 FileProvider
            if (canRequestPackageInstalls) {
                activityBinding.activity.startActivityForResult(intentAfterN, INSTALL_APK)
            } else {
                // version >= O(8) 且 需要请求权限
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:" + context.packageName)
                }
                activityBinding.activity.startActivityForResult(intent, REQUEST_PERMISSION)
            }
        } else {
            activityBinding.activity.startActivityForResult(intentBeforeN, INSTALL_APK)
        }
    }

    private val intentBeforeN: Intent
        get() = Intent(Intent.ACTION_VIEW).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val uri = Uri.fromFile(resultFile)
            setDataAndType(uri, "application/vnd.android.package-archive")
        }

    private val intentAfterN: Intent
        get() = Intent(Intent.ACTION_VIEW).apply {
            //参数1 上下文, 参数2 Provider主机地址 和配置文件中保持一致   参数3  共享的文件
            val apkUri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.ApkProvider",
                    resultFile,
            )
            //添加这一句表示对目标应用临时授权该Uri所代表的文件
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            setDataAndType(apkUri, "application/vnd.android.package-archive")
        }

    private val canRequestPackageInstalls: Boolean
        get() = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                context.packageManager.canRequestPackageInstalls()

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        LogUtil.d(TAG, "onAttachedToActivity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding.removeActivityResultListener(this)
        LogUtil.d(TAG, "onDetachedFromActivityForConfigChanges")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        if (methodCall != null) binding.addActivityResultListener(this)
        LogUtil.d(TAG, "onReattachedToActivityForConfigChanges")
    }

    override fun onDetachedFromActivity() {
        completeInstall("Installation activity detached")
        LogUtil.d(TAG, "onDetachedFromActivity")

    }

    private fun completeInstall(error: String? = null) {
        val pending = methodCall ?: return
        methodCall = null
        activityBinding.removeActivityResultListener(this)
        if (error == null) pending.success(null)
        else pending.error(INSTALL_APK_ERROR, error, null)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (methodCall == null) return false
        when (requestCode) {
            REQUEST_PERMISSION -> {
                // Settings may return RESULT_CANCELED even after permission was granted.
                if (canRequestPackageInstalls) {
                    runCatching {
                        activityBinding.activity.startActivityForResult(intentAfterN, INSTALL_APK)
                    }.onFailure { completeInstall(it.message ?: "Could not open installer") }
                } else {
                    Toast.makeText(context, "请允许安装第三方应用权限", Toast.LENGTH_LONG).show()
                    completeInstall("Unknown-app installation permission denied")
                }
            }
            INSTALL_APK -> completeInstall() // The system still owns the final user consent.
            else -> return false
        }
        return true
    }

    companion object {
        const val TAG = "INSTALL"
        const val REQUEST_PERMISSION = 101
        const val INSTALL_APK = 202
        const val NO_PERMISSION = ""
        const val INSTALL_APK_ERROR = ""
        const val NO_PATH_ERROR = ""
    }
}