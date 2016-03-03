//
//  NSData+Conversion.h
//  SimpleControls
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#ifndef NSData_Conversion_h
#define NSData_Conversion_h

#import <Foundation/Foundation.h>

@interface NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSString *)hexString;
-(NSString*)hexRepresentationWithSpaces_AS:(BOOL)spaces;

@end


#endif /* NSData_Conversion_h */
