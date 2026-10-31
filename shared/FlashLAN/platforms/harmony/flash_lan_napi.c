/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
#include <napi/native_api.h>
#include <math.h>
#include <stdio.h>
#include "flash_lan.h"
#define LIMIT (50u * 1024u * 1024u)
#define SAFE_INTEGER 9007199254740991.0
static napi_value fail(napi_env env, int64_t code) {
    char text[64]; snprintf(text, sizeof text, "LAN code %lld", (long long)code);
    napi_throw_error(env, NULL, text); return NULL;
}
static int integer(napi_env env, napi_value value, uint64_t *out) {
    double number;
    if (napi_get_value_double(env, value, &number) != napi_ok || !isfinite(number) ||
        number < 0 || number > SAFE_INTEGER || (double)(uint64_t)number != number) return 0;
    *out = (uint64_t)number; return 1;
}
static int args(napi_env env, napi_callback_info info, size_t expected, napi_value *values) {
    size_t count = expected + 1; // callers reserve one extra slot to reject extra arguments
    return napi_get_cb_info(env, info, &count, values, NULL, NULL) == napi_ok && count == expected;
}
static napi_value value(napi_env env, int64_t code) {
    if (code < 0) return fail(env, code);
    napi_value output;
    if (napi_create_double(env, (double)code, &output) != napi_ok) return fail(env, -1);
    return output;
}
static napi_value create(napi_env env, napi_callback_info info) {
    napi_value a[4]; uint64_t role, now, remaining;
    if (!args(env, info, 3, a) || !integer(env, a[0], &role) || !integer(env, a[1], &now) ||
        !integer(env, a[2], &remaining) || (role != 1 && role != 2)) return fail(env, -1);
    uint64_t id = flash_lan_new((uint8_t)role, now, remaining);
    if (id == 0) return fail(env, -8);
    if (id > (uint64_t)SAFE_INTEGER) { flash_lan_free(id); return fail(env, -1); }
    return value(env, (int64_t)id);
}
static napi_value action(napi_env env, napi_callback_info info) {
    napi_value a[5]; uint64_t id, op, now, parameter;
    if (!args(env, info, 4, a) || !integer(env, a[0], &id) || !integer(env, a[1], &op) ||
        !integer(env, a[2], &now) || !integer(env, a[3], &parameter)) return fail(env, -1);
    int64_t result;
    switch (op) {
        case 1: result = flash_lan_state(id); break;
        case 2: result = flash_lan_error(id); break;
        case 3: result = flash_lan_tick(id, now); break;
        case 4: result = flash_lan_wrote(id, now); break;
        case 5: result = flash_lan_accept(id, now); break;
        case 6: result = flash_lan_cancel(id); break;
        case 7: result = flash_lan_disconnected(id); break;
        case 8: result = parameter <= 1 ? flash_lan_validated(id, (uint8_t)parameter, now) : -2; break;
        case 9: flash_lan_free(id); result = 0; break;
        default: result = -1;
    }
    return value(env, result);
}
static napi_value input(napi_env env, napi_callback_info info) {
    napi_value a[5]; uint64_t id, op, now; void *data; size_t length;
    if (!args(env, info, 4, a) || !integer(env, a[0], &id) || !integer(env, a[1], &op) ||
        !integer(env, a[3], &now) || napi_get_arraybuffer_info(env, a[2], &data, &length) != napi_ok ||
        length > LIMIT || (op != 1 && op != 2)) return fail(env, -1);
    return value(env, op == 1 ? flash_lan_receive(id, data, length, now) : flash_lan_provide(id, data, length, now));
}
static napi_value copy(napi_env env, uint64_t id, int64_t length, int received) {
    if (length < 0 || (uint64_t)length > LIMIT) return fail(env, length < 0 ? length : -5);
    napi_value result;
    if (length == 0) { napi_get_null(env, &result); return result; }
    void *data;
    if (napi_create_arraybuffer(env, (size_t)length, &data, &result) != napi_ok) return fail(env, -5);
    int64_t copied = received ? flash_lan_copy_received(id, data, length) : flash_lan_copy_output(id, data, length);
    if (copied != length) return fail(env, copied < 0 ? copied : -1);
    return result;
}
static napi_value output(napi_env env, napi_callback_info info) {
    napi_value a[3]; uint64_t id, now;
    if (!args(env, info, 2, a) || !integer(env, a[0], &id) || !integer(env, a[1], &now)) return fail(env, -1);
    return copy(env, id, flash_lan_output_len(id, now), 0);
}
static napi_value received(napi_env env, napi_callback_info info) {
    napi_value a[2]; uint64_t id;
    if (!args(env, info, 1, a) || !integer(env, a[0], &id)) return fail(env, -1);
    return copy(env, id, flash_lan_received_len(id), 1);
}
static napi_value sas(napi_env env, napi_callback_info info) {
    napi_value a[2], result; uint64_t id; uint16_t groups[3];
    if (!args(env, info, 1, a) || !integer(env, a[0], &id)) return fail(env, -1);
    int64_t code = flash_lan_sas(id, groups);
    if (code < 0) return fail(env, code);
    if (napi_create_array_with_length(env, 3, &result) != napi_ok) return fail(env, -5);
    for (uint32_t i = 0; i < 3; i++) {
        napi_value group;
        if (napi_create_uint32(env, groups[i], &group) != napi_ok || napi_set_element(env, result, i, group) != napi_ok) return fail(env, -1);
    }
    return result;
}
#define METHOD(name) {.utf8name = #name, .method = name, .attributes = napi_default}
static napi_value initialize(napi_env env, napi_value exports) {
    napi_property_descriptor methods[] = {METHOD(create), METHOD(action), METHOD(input), METHOD(output), METHOD(received), METHOD(sas)};
    if (napi_define_properties(env, exports, sizeof methods / sizeof methods[0], methods) != napi_ok) return fail(env, -1);
    return exports;
}
static napi_module module = {.nm_version = 1, .nm_register_func = initialize, .nm_modname = "flash_lan"};
__attribute__((constructor)) static void register_module(void) { napi_module_register(&module); }
