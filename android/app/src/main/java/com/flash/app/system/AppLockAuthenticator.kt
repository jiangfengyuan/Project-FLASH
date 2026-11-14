// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.system

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import com.flash.app.data.AppLockAuthResult

/**
 * 系统身份验证（不引入 androidx.biometric）：
 * - Android 11+：平台 BiometricPrompt，生物识别（含 Class 2）或锁屏 PIN / 图案 / 密码任选；
 * - Android 8–10：KeyguardManager 的确认锁屏凭据页面。
 * 两条路径都允许设备凭据，所以只要设备设了锁屏就一定能解开。
 * 必须在 Activity 构造期创建（registerForActivityResult 要求在 STARTED 之前注册）。
 */
class AppLockAuthenticator(private val activity: ComponentActivity) {

    private var pending: ((AppLockAuthResult) -> Unit)? = null

    private val credentialLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        val callback = pending
        pending = null
        callback?.invoke(if (result.resultCode == Activity.RESULT_OK) AppLockAuthResult.SUCCESS else AppLockAuthResult.CANCELLED)
    }

    fun isAvailable(): Boolean = isDeviceSecure(activity)

    fun authenticate(title: String, subtitle: String, onResult: (AppLockAuthResult) -> Unit) {
        if (!isAvailable()) {
            onResult(AppLockAuthResult.UNAVAILABLE)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            biometricPrompt(title, subtitle, onResult)
        } else {
            confirmCredential(title, subtitle, onResult)
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.R)
    private fun biometricPrompt(title: String, subtitle: String, onResult: (AppLockAuthResult) -> Unit) {
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
            .build()
        var delivered = false
        fun deliver(result: AppLockAuthResult) {
            if (delivered) return
            delivered = true
            onResult(result)
        }
        prompt.authenticate(
            CancellationSignal(),
            activity.mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    deliver(AppLockAuthResult.SUCCESS)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    deliver(
                        when (errorCode) {
                            BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                            BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
                            BiometricPrompt.BIOMETRIC_ERROR_TIMEOUT,
                            -> AppLockAuthResult.CANCELLED
                            BiometricPrompt.BIOMETRIC_ERROR_NO_DEVICE_CREDENTIAL -> AppLockAuthResult.UNAVAILABLE
                            else -> AppLockAuthResult.FAILED
                        },
                    )
                }
                // onAuthenticationFailed：单次指纹 / 面部不匹配，提示框仍在，可重试或改用密码，不结束流程
            },
        )
    }

    @Suppress("DEPRECATION") // API 26–29 没有支持设备凭据的平台 BiometricPrompt
    private fun confirmCredential(title: String, subtitle: String, onResult: (AppLockAuthResult) -> Unit) {
        val keyguard = activity.getSystemService(KeyguardManager::class.java)
        val intent = keyguard?.createConfirmDeviceCredentialIntent(title, subtitle)
        if (intent == null) {
            onResult(AppLockAuthResult.UNAVAILABLE)
            return
        }
        pending = onResult
        credentialLauncher.launch(intent)
    }

    companion object {
        /** 设备是否设了 PIN / 图案 / 密码（生物识别都以它为前提） */
        fun isDeviceSecure(context: Context): Boolean =
            context.getSystemService(KeyguardManager::class.java)?.isDeviceSecure == true
    }
}
