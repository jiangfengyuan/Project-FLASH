// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
package com.flash.app.data;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Host JVM JNI test only. Not Android/device/import acceptance. */
public final class LanNativeSmoke {
    private static void drain(long from, long to) {
        byte[] frame;
        while ((frame = LanNative.output(from, 0)) != null) {
            for (byte one : frame) LanNative.input(to, 1, new byte[] {one}, 0);
            LanNative.action(from, 4, 0, 0);
            Arrays.fill(frame, (byte)0);
        }
    }
    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("JNI candidate check failed");
    }
    public static void main(String[] args) {
        long s = LanNative.create(1, 0, 120000);
        long r = LanNative.create(2, 0, 120000);
        try {
            drain(r, s); drain(s, r); drain(r, s); drain(s, r);
            check(Arrays.equals(LanNative.sas(s), LanNative.sas(r)));
            byte[] input = "{\"fixture\":\"JNI round-trip\"}".getBytes(StandardCharsets.UTF_8);
            boolean refused = false;
            try { LanNative.input(s, 2, input, 0); }
            catch (IllegalStateException expected) { refused = true; }
            check(refused);
            LanNative.action(s, 5, 0, 0); LanNative.action(r, 5, 0, 0);
            drain(s, r); drain(r, s);
            LanNative.input(s, 2, input, 0); drain(s, r);
            byte[] received = LanNative.received(r);
            check(Arrays.equals(input, received));
            check(LanNative.action(s, 1, 0, 0) == 12);
            LanNative.action(r, 8, 0, 1); drain(r, s);
            check(LanNative.action(s, 1, 0, 0) == 13);
            Arrays.fill(input, (byte)0); Arrays.fill(received, (byte)0);
        } finally {
            LanNative.action(s, 9, 0, 0); LanNative.action(r, 9, 0, 0);
        }
        boolean staleRefused = false;
        try { LanNative.action(s, 6, 0, 0); }
        catch (IllegalStateException expected) { staleRefused = true; }
        check(staleRefused);
        System.out.println("Host JVM/JNI/Rust candidate round-trip: PASS (not Android device acceptance)");
    }
}
