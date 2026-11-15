/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
#include <jni.h>
#include "flash_lan_probe.h"

JNIEXPORT jint JNICALL Java_com_flash_lan_probe_NativeProbe_run(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    return (jint)flash_lan_probe_run();
}
