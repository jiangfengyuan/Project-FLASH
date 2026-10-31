// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
// Synthetic C ABI fuzz harness. Never linked into an application.
#include "flash_lan.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <vector>

static void check(int64_t result) { if (result < 0) abort(); }
static std::vector<uint8_t> output(uint64_t id) {
    int64_t length = flash_lan_output_len(id, 0); check(length);
    if (length == 0) return {};
    if (length > 65570) abort();
    std::vector<uint8_t> bytes((size_t)length);
    if (flash_lan_copy_output(id, bytes.data(), bytes.size()) != length) abort();
    return bytes;
}
static void drain(uint64_t from, uint64_t to) {
    for (;;) {
        auto bytes = output(from); if (bytes.empty()) return;
        check(flash_lan_receive(to, bytes.data(), bytes.size(), 0));
        check(flash_lan_wrote(from, 0));
    }
}
struct Pair {
    uint64_t s, r;
    Pair() {
        s = flash_lan_new(1, 0, 120000); r = flash_lan_new(2, 0, 120000);
        if (!s || !r) abort();
    }
    ~Pair() { flash_lan_free(s); flash_lan_free(r); }
};
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size == 0 || size > 4096) return 0;
    Pair p;
    if ((data[0] & 1) == 0) {
        // Arbitrary pre-auth stream: no local acceptance and no snapshot.
        uint64_t id = (data[0] & 2) ? p.s : p.r;
        int64_t result = flash_lan_receive(id, data + 1, size - 1, 0);
        if (result == -100 || flash_lan_state(id) == 13 || flash_lan_state(id) == 8 ||
            flash_lan_received_len(id) >= 0) abort();
        const uint8_t secret[] = "must not be accepted";
        if (flash_lan_provide(id, secret, sizeof secret, 0) >= 0) abort();
        return 0;
    }
    // Real key agreement, then mutate an authenticated record in a valid state.
    drain(p.r, p.s); drain(p.s, p.r); drain(p.r, p.s); drain(p.s, p.r);
    uint16_t a[3], b[3]; check(flash_lan_sas(p.s, a)); check(flash_lan_sas(p.r, b));
    if (memcmp(a, b, sizeof a)) abort();
    check(flash_lan_accept(p.s, 0)); check(flash_lan_accept(p.r, 0));
    drain(p.s, p.r); drain(p.r, p.s);
    const uint8_t fixture[] = "{\"synthetic\":true}";
    check(flash_lan_provide(p.s, fixture, sizeof fixture - 1, 0));
    auto frame = output(p.s); auto original = frame;
    for (size_t i = 1; i + 1 < size; i += 2) frame[data[i] % frame.size()] ^= data[i + 1];
    size_t chunk = 1 + data[0] % 31;
    int64_t result = 0;
    for (size_t offset = 0; offset < frame.size() && result >= 0; offset += chunk) {
        size_t n = frame.size() - offset; if (n > chunk) n = chunk;
        result = flash_lan_receive(p.r, frame.data() + offset, n, 0);
    }
    if (result == -100 || flash_lan_received_len(p.r) >= 0) abort();
    auto finish = output(p.s);
    if (result >= 0) result = flash_lan_receive(p.r, finish.data(), finish.size(), 0);
    if (result == -100) abort();
    if (frame != original && flash_lan_received_len(p.r) >= 0) abort();
    if (flash_lan_state(p.s) == 13) abort(); // no receipt was issued
    return 0;
}
