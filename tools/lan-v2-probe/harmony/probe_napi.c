/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
#include <napi/native_api.h>
#include "flash_lan_probe.h"

static napi_value run(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value value;
    if (napi_create_int32(env, flash_lan_probe_run(), &value) != napi_ok) {
        napi_throw_error(env, NULL, "Native probe result unavailable");
        return NULL;
    }
    return value;
}

static napi_value initialize(napi_env env, napi_value exports) {
    napi_property_descriptor property = {
        .utf8name = "run", .method = run, .attributes = napi_default
    };
    if (napi_define_properties(env, exports, 1, &property) != napi_ok) {
        napi_throw_error(env, NULL, "Native probe initialization failed");
        return NULL;
    }
    return exports;
}

static napi_module module = {
    .nm_version = 1, .nm_register_func = initialize, .nm_modname = "flash_lan_probe"
};

__attribute__((constructor)) static void register_module(void) {
    napi_module_register(&module);
}
