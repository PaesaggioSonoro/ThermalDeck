#ifndef TD_HID_TEMPERATURE_READ_H
#define TD_HID_TEMPERATURE_READ_H

#include <stddef.h>

typedef struct TDHIDTemperatures TDHIDTemperatures;

TDHIDTemperatures *td_hid_temperatures_open(void);
void td_hid_temperatures_close(TDHIDTemperatures *source);
size_t td_hid_temperatures_count(const TDHIDTemperatures *source);
int td_hid_temperature_name(const TDHIDTemperatures *source, size_t index, char *name, size_t size);
double td_hid_temperature_read(const TDHIDTemperatures *source, size_t index);

#endif
