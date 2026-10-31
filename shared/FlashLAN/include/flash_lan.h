/* Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0 */
#ifndef FLASH_LAN_H
#define FLASH_LAN_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Role 1=sender, 2=receiver. Times are monotonic milliseconds.
 * New returns 0 on failure. Remaining opening budget is 1..120000ms.
 * Other calls return >=0 on success, negative error code on failure.
 * Error: 1 state, 2 malformed, 3 incompatible, 4 auth, 5 size,
 * 6 timeout, 7 canceled, 8 crypto, 9 peer, 100 caught panic/handle removed.
 * State: 1 wait R hello, 2 wait S hello, 3 commitment, 4 R key, 5 S key,
 * 6 local confirmation, 7 peer confirmation, 8 ready for deferred snapshot,
 * 9 sending, 10 receiving, 11 strict validation required, 12 receipt,
 * 13 done, 14 failed. No state implies database import or commit.
 * All buffers must remain valid for the duration of the call. Never log
 * buffers/SAS, reuse freed handles, or queue another socket write before the
 * current immutable frame completes. Free is idempotent; IDs are not reused.
 */
uint64_t flash_lan_new(uint8_t role, uint64_t now_ms, uint64_t remaining_ms);
void flash_lan_free(uint64_t id);
int64_t flash_lan_state(uint64_t id);
int64_t flash_lan_error(uint64_t id);
int64_t flash_lan_tick(uint64_t id, uint64_t now_ms);
int64_t flash_lan_wrote(uint64_t id, uint64_t now_ms);
int64_t flash_lan_accept(uint64_t id, uint64_t now_ms);
int64_t flash_lan_cancel(uint64_t id);
int64_t flash_lan_disconnected(uint64_t id);
int64_t flash_lan_receive(uint64_t id, const uint8_t *data, size_t len, uint64_t now_ms);
int64_t flash_lan_provide(uint64_t id, const uint8_t *data, size_t len, uint64_t now_ms);
int64_t flash_lan_output_len(uint64_t id, uint64_t now_ms);
int64_t flash_lan_copy_output(uint64_t id, uint8_t *out, size_t capacity);
int64_t flash_lan_sas(uint64_t id, uint16_t *out_three);
int64_t flash_lan_received_len(uint64_t id);
int64_t flash_lan_copy_received(uint64_t id, uint8_t *out, size_t capacity);
int64_t flash_lan_validated(uint64_t id, uint8_t valid, uint64_t now_ms);
#ifdef __cplusplus
}
#endif
#endif
