#include "SMCRead.h"
#include <IOKit/IOKitLib.h>
#include <stddef.h>
#include <string.h>

typedef struct {
    uint32_t key;
    uint8_t reserved_prefix[24];
    uint32_t size;
    uint32_t type;
    uint8_t reserved_attributes[4];
    uint8_t result;
    uint8_t status;
    uint8_t command;
    uint8_t reserved_alignment;
    uint32_t index;
    uint8_t bytes[32];
} Request;

_Static_assert(sizeof(Request) == 80, "AppleSMC ABI size changed");
_Static_assert(offsetof(Request, size) == 28, "AppleSMC metadata offset changed");
_Static_assert(offsetof(Request, result) == 40, "AppleSMC result offset changed");
_Static_assert(offsetof(Request, command) == 42, "AppleSMC selector offset changed");
_Static_assert(offsetof(Request, index) == 44, "AppleSMC index offset changed");
_Static_assert(offsetof(Request, bytes) == 48, "AppleSMC payload offset changed");

typedef enum { read_bytes = 5, read_index = 8, read_metadata = 9 } ReadOperation;

static int32_t invoke(uint32_t connection, ReadOperation operation, Request input, Request *output) {
    input.command = (uint8_t)operation;
    size_t size = sizeof(*output);
    memset(output, 0, size);
    kern_return_t error = IOConnectCallStructMethod(connection, 2, &input, sizeof(input), output, &size);
    if (error != KERN_SUCCESS) return error;
    if (size != sizeof(*output)) return TD_SMC_BAD_REPLY;
    if (output->result == 0x84) return TD_SMC_MISSING;
    return output->result == 0 ? 0 : TD_SMC_FIRMWARE_REJECTED;
}

int32_t td_smc_open(uint32_t *connection) {
    *connection = IO_OBJECT_NULL;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) return TD_SMC_UNAVAILABLE;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, connection);
    IOObjectRelease(service);
    return result;
}

void td_smc_close(uint32_t connection) {
    if (connection != IO_OBJECT_NULL) IOServiceClose(connection);
}

int32_t td_smc_key_at(uint32_t connection, uint32_t index, uint32_t *key) {
    Request reply;
    int32_t result = invoke(connection, read_index, (Request){ .index = index }, &reply);
    if (result == 0) *key = reply.key;
    return result;
}

int32_t td_smc_describe(uint32_t connection, uint32_t key, TDReadValue *value) {
    Request reply;
    int32_t result = invoke(connection, read_metadata, (Request){ .key = key }, &reply);
    if (result != 0) return result;
    if (reply.size == 0 || reply.size > sizeof(value->bytes) || reply.type == 0) return TD_SMC_BAD_REPLY;
    value->size = reply.size;
    value->type = reply.type;
    return 0;
}

int32_t td_smc_read(uint32_t connection, uint32_t key, TDReadValue *value) {
    if (value->size == 0 || value->size > sizeof(value->bytes)) return TD_SMC_BAD_REPLY;
    Request reply;
    int32_t result = invoke(connection, read_bytes, (Request){ .key = key, .size = value->size }, &reply);
    if (result == 0) memcpy(value->bytes, reply.bytes, value->size);
    return result;
}
