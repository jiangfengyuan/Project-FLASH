#ifndef FLASH_LAN_PROBE_H
#define FLASH_LAN_PROBE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Isolated feasibility probe only. No production pairing or network API. */
int32_t flash_lan_probe_run(void);
#ifdef __cplusplus
}
#endif
#endif
