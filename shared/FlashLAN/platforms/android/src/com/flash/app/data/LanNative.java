// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
package com.flash.app.data;

/** C ABI bridge only. The application owns I/O, lifecycle and strict parsing. */
public final class LanNative {
    private LanNative() {}
    static { System.loadLibrary("flash_lan"); }
    public static native long create(int role, long now, long remaining);
    // 1 state, 2 error, 3 tick, 4 wrote, 5 accept, 6 cancel, 7 EOF,
    // 8 validated (parameter 0/1), 9 free. Never pass wall-clock time.
    public static native long action(long id, int operation, long now, long parameter);
    // 1 receive, 2 provide. Caller should wipe temporary byte arrays after use.
    public static native long input(long id, int operation, byte[] input, long now);
    public static native byte[] output(long id, long now);
    public static native byte[] received(long id);
    public static native int[] sas(long id);
}
