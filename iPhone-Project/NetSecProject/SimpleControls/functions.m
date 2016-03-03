//
//  functions.m
//  SimpleControls
//
//  Created by Emanuele Trivella on 22/01/16.
//  Copyright © 2016 RedBearLab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "functions.h"

@implementation functions

/**
 * Manda un pacchetto contenente il comando e un big number come payload
 * @param cmd    comando da eseguire
 * @param bn     BIGNUM da inviare come payload
 */
-(NSData*)sendPkt:(UInt8)cmd bignumber:(const BIGNUM *)bn
{
    int numByteMess = 0;
    
    // contenuto del campo Payload
    UInt8 *vetDataPayload = getUIntPayload(bn, &numByteMess);
    
    //NSLog(@"vetDataPayload: %d", vetDataPayload);
    
    // quanti byte mi servono per il Payload
    int numBytePayload = numByteMess/sizeof(UInt8);
    
    // quanti byte mi servono per rappresentare la lunghezza del campo MSG Lentgh
    int numByteLengthPayload = quantiByte(numBytePayload); // nel dubbio metti 1!!
    
    NSLog(@"numByteLengthPayload: %d", numByteLengthPayload);
    NSLog(@"numBytePayload: %d", numBytePayload);
    
    // contenuto del campo MSG Length
    UInt8 *vetLengthPayload = getUIntPayloadInt(numBytePayload);
    
    UInt8 buf_pkt[NUM_PKT_HEADER + numByteLengthPayload + numBytePayload];
    
    NSLog(@"lunghezza buf_pkt: %d+%d+%d = %d", NUM_PKT_HEADER, numByteLengthPayload, numBytePayload, NUM_PKT_HEADER + numByteLengthPayload + numBytePayload);
    
    int i=0;
    
    buf_pkt[0] = cmd;
    
    buf_pkt[1] = numByteLengthPayload;
    
    // riempio il campo Length Payload
    for(i=0; i<numByteLengthPayload; i++)
        buf_pkt[i+NUM_PKT_HEADER]=vetLengthPayload[i];
        
    // riempio il campo Payload
    for(i=0; i<numBytePayload; i++)
        buf_pkt[i+NUM_PKT_HEADER+numByteLengthPayload]=vetDataPayload[i];
            
    // invio il pacchetto
    NSData *data = [[NSData alloc] initWithBytes:buf_pkt length:(sizeof(buf_pkt)/sizeof(UInt8))];
    
    return data;
    //[ble write:data];
}

/**
 * Manda un pacchetto contenente il comando e un NSData come payload
 * @param cmd    comando da eseguire
 * @param bn     NSData da inviare come payload
 */
-(NSData *)sendPkt:(UInt8)cmd stringa:(NSData *)msg
{
    // quanti byte mi servono per il Payload
    int numBytePayload = msg.length;
    
    // quanti byte mi servono per rappresentare la lunghezza del campo MSG Lentgh
    int numByteLengthPayload = quantiByte(numBytePayload); // nel dubbio metti 1!!
    
    NSLog(@"numByteLengthPayload: %d", numByteLengthPayload);
    NSLog(@"numBytePayload: %d", numBytePayload);
    
    // contenuto del campo MSG Length
    UInt8 *vetLengthPayload = getUIntPayloadInt(numBytePayload);
    
    // converto il msg in una stringa esadecimale
    NSString *strMyMSG = NSDataToHex(msg);
    
    // genero il buffer contenente il payload
    //UInt8 *buffer[strMyMSG.length];
    
    int i=0;
    int count = 0;
    
    //int numBytePadding = (BN_num_bytes(bn)/sizeof(UInt8)) - numByte;
    
    int bytePadding = 0;
    
    // padding di zeri se il numero di byte necessari non e' multiplo di 4
    if(strMyMSG.length%2)
        bytePadding++;
    
    // genero il buffer contenente il payload
    UInt8 *buffer[strMyMSG.length + bytePadding];
    
    if(bytePadding)
        buffer[0] = 0x00;
    
    // vero contenuto da inviare
    for(i=0+bytePadding; i<strMyMSG.length/2; i++)
    {
        count = i*2;
        
        NSString *str_i = [strMyMSG substringWithRange:NSMakeRange(count, 2)];
        
        // utile per convertire in intero una NSString
        unsigned int outVal;
        NSScanner* scanner = [NSScanner scannerWithString:str_i];
        [scanner scanHexInt:&outVal];
        
        buffer[i] = (UInt8) outVal;
        printf("buffer[%d]=0x%02x\n",i,buffer[i]);
    }
    
    
    UInt8 buf_pkt[NUM_PKT_HEADER + numByteLengthPayload + numBytePayload];
    
    NSLog(@"lunghezza buf_pkt: %d+%d+%d = %d", NUM_PKT_HEADER, numByteLengthPayload, numBytePayload, NUM_PKT_HEADER + numByteLengthPayload + numBytePayload);
    
    // riempio il pacchetto da inviare all'arduino
    
    buf_pkt[0] = cmd;
    
    buf_pkt[1] = numByteLengthPayload;
    
    // riempio il campo Length Payload
    for(i=0; i<numByteLengthPayload; i++)
        buf_pkt[i+NUM_PKT_HEADER]=vetLengthPayload[i];
    
    // riempio il campo Payload
    for(i=0; i<numBytePayload; i++)
        buf_pkt[i+NUM_PKT_HEADER+numByteLengthPayload]=buffer[i];
    
    // invio il pacchetto
    NSData *data = [[NSData alloc] initWithBytes:buf_pkt length:(sizeof(buf_pkt)/sizeof(UInt8))];
    
    return data;
    //[ble write:data];
    
    //printf("NSData originale %s\n", [[msg description] UTF8String]);
}

/**
 * Restituisce un vettore di UInt8 contenente il bignumber
 * @param   bn  Oggetto BIGNUM da splittare in un vettore di UInt8
 * @return      Puntatore ad un oggetto UInt8, è il primo elemento del vettore.
 */
UInt8* getUIntPayload(const BIGNUM* bn, int* byteMess)
{
    int numByte = (int) ceil(((double)BN_num_bits(bn))/NUM_BIT_IN_BYTE);
    
    NSLog(@"numByte: %d", numByte);
    
    UInt8* buffer = malloc(numByte * sizeof(UInt8));
    
    NSLog(@"sizeof(buffer): %lu", sizeof(*buffer));
    NSLog(@"BN_num_bytes(bn): %d", BN_num_bytes(bn));
    
    // NB non si può usare sizeof con le malloc,
    // bisogna sistemare la lunghezza del payload nel caso in cui la lunghezza del numero primo sia > 32
    
    int numBytePadding = (BN_num_bytes(bn)/sizeof(UInt8)) - numByte;
    
    NSLog(@"numBytePadding: %d/%d - %d", BN_num_bytes(bn), sizeof(UInt8), numByte);
    
    NSLog(@"numBytePadding: %d", numBytePadding);
    
    if (buffer != NULL)
    {
        //NSString* str = [self BIGNUM2NSString:bn];
        
        NSString* str = BIGNUM2NSString(bn);
        
        NSLog(@"BNstr: %@", str);
        
        int i=0;
        int count = 0;
        
        // padding di zeri se il numero di byte necessari non e' multiplo di 4
        for(i=0; i<numBytePadding; i++)
            buffer[i] = 0x00;
        
        // vero contenuto da inviare
        for(i=0; i<numByte; i++)
        {
            count = i*2;
            
            NSString *str_i = [str substringWithRange:NSMakeRange(count, 2)];
            
            // utile per convertire in intero una NSString
            unsigned int outVal;
            NSScanner* scanner = [NSScanner scannerWithString:str_i];
            [scanner scanHexInt:&outVal];
            
            buffer[i+numBytePadding] = (UInt8) outVal;
            printf("buffer[%d]=0x%02x\n",i,buffer[i]);
        }
    }
    
    *byteMess = numByte;
    
    return buffer;
}


/**
 * Restituisce un vettore di UInt8 contenente il bignumber
 * @param   bn  Oggetto BIGNUM da splittare in un vettore di UInt8
 * @return      Puntatore ad un oggetto UInt8, è il primo elemento del vettore.
 */
UInt8* getUIntPayloadInt(int num)
{
    int ciao=0;
    
    BIGNUM *bn = BN_new();
    
    BN_set_word(bn, num);
    
    return getUIntPayload(bn, &ciao);
}


/**
 * Restituisce quanti byte ci vogliono per inviare num
 * @param    num Numero di cui bisogna calcolare il numero di byte necessari per inviarlo.
 * @return       Il numero di byte che servono per inviare num
 */
UInt8 quantiByte(UInt8 num)
{
    UInt8 result = 0;
    
    //BOOL fine = false;
    
    // num/256 + 1
    result = num/((int) pow(2,NUM_BIT_IN_BYTE))+1;
    
    /*while(!fine)
     {
     if(result%4 == 0)
     fine = true;
     else
     result += 1;
     }*/
    
    return result;
}


/**
 * Converte un char in int
 */
int convCharToInt(char elem)
{
    if(elem == '0')
        return 0;
    
    if(elem == '1')
        return 1;
    
    if(elem == '2')
        return 2;
    
    if(elem == '3')
        return 3;
    
    if(elem == '4')
        return 4;
    
    if(elem == '5')
        return 5;
    
    if(elem == '6')
        return 6;
    
    if(elem == '7')
        return 7;
    
    if(elem == '8')
        return 8;
    
    if(elem == '9')
        return 9;
    
    if(elem == 'a')
        return 10;
    
    if(elem == 'b')
        return 11;
    
    if(elem == 'c')
        return 12;
    
    if(elem == 'd')
        return 13;
    
    if(elem == 'e')
        return 14;
    
    if(elem == 'f')
        return 15;
    
    return -1;
}

/**
 * Genera un BIGNUM a partire da un num
 * @param num    numero intero che si vuole convertire in BIGNUM
 */
-(BIGNUM *)BN_create:(int)num
{
    BIGNUM *bn = BN_new();
    BN_set_word(bn, num);
    
    return bn;
}


/**
 * Converte un (unsigned char *) in un BIGNUM
 * @param num    (unsigend char *) da convertire in BIGNUM
 * @param lung   lunghezza dell'unsigned char *
 */
- (BIGNUM *)convHex2Dec:(unsigned char *)num lung:(int)lunghezza
{
    NSLog(@"STRINGA RICEVUTA: %s", num);
    
    int i;
    BIGNUM *sum = [self BN_create:0];
    
    BN_CTX *ctx = BN_CTX_new();
    
    for(i=0; i<lunghezza; i++)
    {
        int elem = convCharToInt(num[i]);
        
        if(elem != 0)
        {
            BIGNUM *base = [self BN_create:16];
            BIGNUM *esp = [self BN_create:lunghezza-1-i];
            
            BIGNUM *temp = BN_new();
            
            BN_exp(temp, base, esp, ctx);
            
            BN_mul_word(temp, elem);
            
            BN_add(sum, sum, temp);
            
            //sum = sum + elem * pow(16,lung-1-i);
        }
    }
    
    NSLog(@"NUMERO CONVERTITO: %@", BIGNUM2NSString(sum));
    
    return sum;
}


/**
 * Converte un BIGNUM in un NSData
 * @param bn BIGNUM da convertire
 */
static NSData* BIGNUM2NSData(const BIGNUM* bn)
{
    NSData* result = [[NSData alloc] init];
    
    printf("\nNUM BYTES: %d\n", BN_num_bytes(bn));
    
    void* buffer = malloc(BN_num_bytes(bn));
    if (buffer != NULL) {
        BN_bn2bin(bn, buffer);
        //buffer = BN_bn2hex(bn);
        //result = [NSData dataWithBytesNoCopy: buffer length: BN_num_bytes(bn) freeWhenDone: YES];
        
        result = [NSData dataWithBytes:buffer length:BN_num_bytes(bn)];
    }
    
    return result;
}


/**
 * Converte un BIGNUM in un oggetto NSString
 * @param    bn  bignumber da convertire
 * @return   Oggetto NSString ottenuto convertendo bn
 */
-(NSString *) BIGNUM2NSString:(const BIGNUM*) bn
{
    NSString* result = nil;
    
    const char* s = BN_bn2hex(bn);
    //NSLog(@"s = %s\n",s);
    if (s != nil) {
        result = [[NSString stringWithCString: s encoding: NSASCIIStringEncoding] lowercaseString];
        OPENSSL_free((void*) s);
    }
    
    return result;
}

static NSString* BIGNUM2NSString(const BIGNUM* bn)
{
    NSString* result = nil;
    
    const char* s = BN_bn2hex(bn);
    //NSLog(@"s = %s\n",s);
    if (s != nil) {
        result = [[NSString stringWithCString: s encoding: NSASCIIStringEncoding] lowercaseString];
        OPENSSL_free((void*) s);
    }
    
    return result;
}

/**
 * Converte un numero (da 0 a 15) da notazione decimale a esadecimale (es: 10 -> A)
 */
static inline char itoh(int i) {
    if (i > 9) return 'a' + (i - 10);
    return '0' + i;
}


/**
 * Converte un NSData in un NSString
 */
NSString * NSDataToHex(NSData *data)
{
    NSUInteger i, len;
    unsigned char *buf, *bytes;
    
    len = data.length;
    bytes = (unsigned char*)data.bytes;
    buf = malloc(len*2);
    
    for (i=0; i<len; i++) {
        buf[i*2] = itoh((bytes[i] >> 4) & 0xF);
        buf[i*2+1] = itoh(bytes[i] & 0xF);
    }
    
    return [[NSString alloc] initWithBytesNoCopy:buf
                                          length:len*2
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:YES];
}

- (NSData *)dataFromHexString:(NSString *)string
{
    string = [string lowercaseString];
    NSMutableData *data= [NSMutableData new];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i = 0;
    int length = string.length;
    while (i < length-1) {
        char c = [string characterAtIndex:i++];
        if (c < '0' || (c > '9' && c < 'a') || c > 'f')
            continue;
        byte_chars[0] = c;
        byte_chars[1] = [string characterAtIndex:i++];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
    }
    return data;
}

- (int)convHex2Dec:(NSString *)num numByte:(int)numByte
{
    
    //NSLog(@"CONV HEX2DEC: %@", num);
    
    int i;
    float sum = 0.0;
    for (i = 0; i < numByte * 2; i++)
    {
        if (convCharToInt([num substringWithRange:NSMakeRange(i,1)]) != 0)
        {
            // converto il carattere in numero e lo moltiplico per la corrispondente
            // potenza di 16 per trasformarlo in base 10
            
            NSString * temp = [num substringWithRange:NSMakeRange(i, 1)];
            
            const char *stringAsChar = [temp cStringUsingEncoding:[NSString defaultCStringEncoding]];
            
            sum = sum + convCharToInt(stringAsChar[0]) * pow(16, numByte * 2 - 1 - i);
            
            //NSLog(@"CONV HEX2DEC SUM: %f", sum);
            
        }
        
        //Serial.println("SUM: " + sum);
    }
    
    return (int) sum;
}

@end
