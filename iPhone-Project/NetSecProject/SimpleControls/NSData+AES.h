/**
 http://mythosil.hatenablog.com/entry/20111017/1318873155
 http://blog.dealforest.net/2012/03/ios-android-per-aes-crypt-connection/
 */

#import <CommonCrypto/CommonCryptor.h>

@interface NSData (AES)

- (NSData *)AES128EncryptedDataWithKey:(NSData*)key;
- (NSData *)AES128DecryptedDataWithKey:(NSData*)key;
- (NSData *)AES128EncryptedDataWithKey:(NSData*)key iv:(NSData*)iv;
- (NSData *)AES128DecryptedDataWithKey:(NSData*)key iv:(NSData*)iv;
//- (NSData *)AES128Operation:(CCOperation)operation key:(unsigned char *)key iv:(NSString *)iv;

@end
