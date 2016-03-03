//
//  functions.h
//  SimpleControls
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#ifndef functions_h
#define functions_h

// Bluetooth
#import "BLE.h"

// OpenSSL
#import "openssl/bn.h"
#import "openssl/dh.h"
#import "stdlib.h"

#import <CommonCrypto/CommonCryptor.h>
#import "NSData+AES.h"
#import "NSData+Conversion.h"

#define CONST_P_PRIME 23
#define CONST_G_BASE 5

#define PRIME_LENGTH 128
#define NUM_BIT_IN_BYTE 8
#define NUM_PKT_HEADER 2

#define KEY_LENGTH_BYTE PRIME_LENGTH/NUM_BIT_IN_BYTE

@interface functions : NSObject 

@end


#endif /* functions_h */
