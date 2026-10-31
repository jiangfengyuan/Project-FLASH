/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
#include <jni.h>
#include <sodium.h>
#include <stdio.h>
#include <stdlib.h>
#include "flash_lan.h"

#define JNI(name) Java_com_flash_app_data_LanNative_##name
#define LIMIT (50u * 1024u * 1024u)
static void fail(JNIEnv *env, int64_t code) {
    char message[64];
    snprintf(message, sizeof message, "LAN code %lld", (long long)code);
    jclass type = (*env)->FindClass(env, "java/lang/IllegalStateException");
    if (type != NULL) (*env)->ThrowNew(env, type, message);
}
JNIEXPORT jlong JNICALL JNI(create)(JNIEnv *env, jclass cls, jint role, jlong now, jlong remaining) {
    (void)cls;
    if (now < 0 || remaining <= 0 || (role != 1 && role != 2)) { fail(env, -1); return 0; }
    uint64_t id = flash_lan_new((uint8_t)role, (uint64_t)now, (uint64_t)remaining);
    if (id == 0) fail(env, -8);
    return (jlong)id;
}
JNIEXPORT jlong JNICALL JNI(action)(JNIEnv *env, jclass cls, jlong id, jint op, jlong now, jlong parameter) {
    (void)cls;
    if (id <= 0 || now < 0) { fail(env, -1); return -1; }
    int64_t result;
    switch (op) {
        case 1: result = flash_lan_state(id); break;
        case 2: result = flash_lan_error(id); break;
        case 3: result = flash_lan_tick(id, now); break;
        case 4: result = flash_lan_wrote(id, now); break;
        case 5: result = flash_lan_accept(id, now); break;
        case 6: result = flash_lan_cancel(id); break;
        case 7: result = flash_lan_disconnected(id); break;
        case 8: result = parameter == 0 || parameter == 1 ? flash_lan_validated(id, (uint8_t)parameter, now) : -2; break;
        case 9: flash_lan_free(id); result = 0; break;
        default: result = -1;
    }
    if (result < 0) fail(env, result);
    return result;
}
JNIEXPORT jlong JNICALL JNI(input)(JNIEnv *env, jclass cls, jlong id, jint op, jbyteArray input, jlong now) {
    (void)cls;
    if (input == NULL || id <= 0 || now < 0 || (op != 1 && op != 2)) { fail(env, -1); return -1; }
    jsize length = (*env)->GetArrayLength(env, input);
    if (length < 0 || (size_t)length > LIMIT) { fail(env, -5); return -5; }
    uint8_t *buffer = malloc(length == 0 ? 1 : (size_t)length);
    if (buffer == NULL) { fail(env, -5); return -5; }
    (*env)->GetByteArrayRegion(env, input, 0, length, (jbyte *)buffer);
    int64_t result = -1;
    if (!(*env)->ExceptionCheck(env)) result = op == 1 ?
        flash_lan_receive(id, buffer, (size_t)length, now) : flash_lan_provide(id, buffer, (size_t)length, now);
    sodium_memzero(buffer, (size_t)length); free(buffer);
    if (result < 0 && !(*env)->ExceptionCheck(env)) fail(env, result);
    return result;
}
static jbyteArray copy(JNIEnv *env, uint64_t id, int64_t length, int received) {
    if (length < 0 || (uint64_t)length > LIMIT) { fail(env, length < 0 ? length : -5); return NULL; }
    if (length == 0) return NULL;
    uint8_t *buffer = malloc((size_t)length);
    if (buffer == NULL) { fail(env, -5); return NULL; }
    int64_t copied = received ? flash_lan_copy_received(id, buffer, length) : flash_lan_copy_output(id, buffer, length);
    jbyteArray result = NULL;
    if (copied == length) {
        result = (*env)->NewByteArray(env, (jsize)length);
        if (result != NULL) (*env)->SetByteArrayRegion(env, result, 0, (jsize)length, (const jbyte *)buffer);
    } else fail(env, copied < 0 ? copied : -1);
    sodium_memzero(buffer, (size_t)length); free(buffer);
    return result;
}
JNIEXPORT jbyteArray JNICALL JNI(output)(JNIEnv *env, jclass cls, jlong id, jlong now) {
    (void)cls;
    if (id <= 0 || now < 0) { fail(env, -1); return NULL; }
    return copy(env, id, flash_lan_output_len(id, now), 0);
}
JNIEXPORT jbyteArray JNICALL JNI(received)(JNIEnv *env, jclass cls, jlong id) {
    (void)cls;
    return copy(env, id, flash_lan_received_len(id), 1);
}
JNIEXPORT jintArray JNICALL JNI(sas)(JNIEnv *env, jclass cls, jlong id) {
    (void)cls;
    uint16_t groups[3];
    int64_t code = flash_lan_sas(id, groups);
    if (code < 0) { fail(env, code); return NULL; }
    jint values[3] = {groups[0], groups[1], groups[2]};
    jintArray array = (*env)->NewIntArray(env, 3);
    if (array != NULL) (*env)->SetIntArrayRegion(env, array, 0, 3, values);
    sodium_memzero(groups, sizeof groups); sodium_memzero(values, sizeof values);
    return array;
}
