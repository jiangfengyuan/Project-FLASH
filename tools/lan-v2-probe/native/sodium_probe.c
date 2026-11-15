/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
/* Dependency/ABI smoke test, not a pairing protocol. Synthetic input only. */
#include <sodium.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int32_t flash_lan_sodium_probe_run(void) {
    if (sodium_init() < 0) return 1;
    if (strcmp(sodium_version_string(), "1.0.22") != 0) return 2;
    unsigned char key[crypto_aead_xchacha20poly1305_ietf_KEYBYTES];
    unsigned char nonce[crypto_aead_xchacha20poly1305_ietf_NPUBBYTES];
    const unsigned char message[] = "fictional probe, no backup";
    const unsigned char aad[] = "build probe";
    unsigned char ciphertext[sizeof message + crypto_aead_xchacha20poly1305_ietf_ABYTES];
    unsigned char plain[sizeof message];
    unsigned long long length = 0;
    int32_t result = 0;
    randombytes_buf(key, sizeof key);
    randombytes_buf(nonce, sizeof nonce);
    if (crypto_aead_xchacha20poly1305_ietf_encrypt(ciphertext, &length,
        message, sizeof message, aad, sizeof aad, NULL, nonce, key) != 0 ||
        length != sizeof ciphertext) { result = 3; goto cleanup; }
    if (crypto_aead_xchacha20poly1305_ietf_decrypt(plain, &length, NULL,
        ciphertext, sizeof ciphertext, aad, sizeof aad, nonce, key) != 0 ||
        length != sizeof message || memcmp(plain, message, sizeof message) != 0) {
        result = 4; goto cleanup;
    }
    ciphertext[0] ^= 1;
    if (crypto_aead_xchacha20poly1305_ietf_decrypt(plain, &length, NULL,
        ciphertext, sizeof ciphertext, aad, sizeof aad, nonce, key) == 0) result = 5;
cleanup:
    sodium_memzero(key, sizeof key);
    if (!sodium_is_zero(key, sizeof key)) result = 6;
    sodium_memzero(plain, sizeof plain);
    return result;
}

#ifdef FLASH_PROBE_MAIN
int main(void) {
    int32_t result = flash_lan_sodium_probe_run();
    printf("libsodium native probe code=%d (not production pairing)\n", result);
    return result;
}
#endif
