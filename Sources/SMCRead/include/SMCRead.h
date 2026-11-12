#ifndef TD_SMC_READ_H
#define TD_SMC_READ_H

#include <stdint.h>

typedef struct {
    uint32_t size;
    uint32_t type;
    uint8_t bytes[32];
} TDReadValue;

enum {
    TD_SMC_MISSING = -1,
    TD_SMC_BAD_REPLY = -2,
    TD_SMC_UNAVAILABLE = -3,
    TD_SMC_FIRMWARE_REJECTED = -4
};

int32_t td_smc_open(uint32_t *connection);
void td_smc_close(uint32_t connection);
int32_t td_smc_key_at(uint32_t connection, uint32_t index, uint32_t *key);
int32_t td_smc_describe(uint32_t connection, uint32_t key, TDReadValue *value);
int32_t td_smc_read(uint32_t connection, uint32_t key, TDReadValue *value);

#endif
