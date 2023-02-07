#ifndef key_h
#define key_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
long factorial(int n);
const char* generate_key(const char* seed_str);
const char* get_g1(const char* key);
const char* derive_child_key_hardened(const char* key, int index);
const char* derive_child_key_unhardened(const char* key, int index);
const char* add_g1(const char* key, const char* key1);
const char* swift_sign(const char* key_str, const char* message_str);
const char* swift_aggregate(const char* sig1, const char* sig2);

#ifdef __cplusplus
}
#endif
#endif /* key_h */
