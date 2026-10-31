// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
package com.flash.lan.probe;

/** Standalone JNI feasibility entry; deliberately outside the Flash app build. */
public final class NativeProbe {
    private NativeProbe() {}
    static { System.loadLibrary("flash_lan_probe"); }
    public static native int run();
}
