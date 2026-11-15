#include "HIDTemperatureRead.h"
#include <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <stdlib.h>

// The SDK does not publish the IOHID event client declarations used here.
extern CFTypeRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientSetMatching(CFTypeRef client, CFDictionaryRef matching);
extern CFArrayRef IOHIDEventSystemClientCopyServices(CFTypeRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(CFTypeRef service, CFStringRef key);
extern CFTypeRef IOHIDServiceClientCopyEvent(CFTypeRef service, int type, int options, long timeout);
extern double IOHIDEventGetFloatValue(CFTypeRef event, int field);

struct TDHIDTemperatures {
    CFTypeRef client;
    CFArrayRef services;
};

TDHIDTemperatures *td_hid_temperatures_open(void) {
    CFTypeRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return NULL;

    const int page = 0xff00;
    const int usage = 5;
    CFNumberRef page_value = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFNumberRef usage_value = CFNumberCreate(NULL, kCFNumberIntType, &usage);
    const void *keys[] = {CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage")};
    const void *values[] = {page_value, usage_value};
    CFDictionaryRef matching = page_value && usage_value ?
        CFDictionaryCreate(NULL, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) : NULL;
    if (page_value) CFRelease(page_value);
    if (usage_value) CFRelease(usage_value);
    if (!matching) {
        CFRelease(client);
        return NULL;
    }
    IOHIDEventSystemClientSetMatching(client, matching);
    CFRelease(matching);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    TDHIDTemperatures *source = services ? malloc(sizeof(*source)) : NULL;
    if (!source) {
        if (services) CFRelease(services);
        CFRelease(client);
        return NULL;
    }
    source->client = client;
    source->services = services;
    return source;
}

void td_hid_temperatures_close(TDHIDTemperatures *source) {
    CFRelease(source->services);
    CFRelease(source->client);
    free(source);
}

size_t td_hid_temperatures_count(const TDHIDTemperatures *source) {
    return (size_t)CFArrayGetCount(source->services);
}

int td_hid_temperature_name(const TDHIDTemperatures *source, size_t index, char *name, size_t size) {
    if (index >= td_hid_temperatures_count(source)) return 0;
    CFTypeRef service = CFArrayGetValueAtIndex(source->services, (CFIndex)index);
    CFTypeRef product = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
    if (!product) return 0;
    int found = CFGetTypeID(product) == CFStringGetTypeID() &&
        CFStringGetCString(product, name, (CFIndex)size, kCFStringEncodingUTF8);
    CFRelease(product);
    return found;
}

double td_hid_temperature_read(const TDHIDTemperatures *source, size_t index) {
    if (index >= td_hid_temperatures_count(source)) return NAN;
    const int temperature_event = 15;
    CFTypeRef service = CFArrayGetValueAtIndex(source->services, (CFIndex)index);
    CFTypeRef event = IOHIDServiceClientCopyEvent(service, temperature_event, 0, 0);
    if (!event) return NAN;
    double value = IOHIDEventGetFloatValue(event, temperature_event << 16);
    CFRelease(event);
    return value;
}
