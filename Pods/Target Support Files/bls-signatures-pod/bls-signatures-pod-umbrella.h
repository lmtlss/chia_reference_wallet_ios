#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "bls.hpp"
#import "elements.hpp"
#import "hdkeys.hpp"
#import "hkdf.hpp"
#import "privatekey.hpp"
#import "schemes.hpp"
#import "util.hpp"

FOUNDATION_EXPORT double bls_signatures_podVersionNumber;
FOUNDATION_EXPORT const unsigned char bls_signatures_podVersionString[];

