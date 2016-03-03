//
//  TableViewController.m
//  SimpleControls
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#import "TableViewController.h"

#import "BLE.h"

#import <CommonCrypto/CommonCryptor.h>
#import "NSData+AES.h"
#import "NSData+Conversion.h"

#define CONST_P_PRIME 23
#define CONST_G_BASE 5

#define PRIME_LENGTH 128
#define NUM_BIT_IN_BYTE 8
#define NUM_PKT_HEADER 2

#define MAX_PLAIN_CHAR 15

#define DELTA_Y_KEYBOARD 120

#define KEY_LENGTH_BYTE PRIME_LENGTH/NUM_BIT_IN_BYTE

static const char rnd_seed[] = "questa e una frase per inizializzare il PNRG";

static NSString * NAME_FINISH_SCAN = @"FinishScanPeripherals";


@interface TableViewController ()

@end

@implementation TableViewController

@synthesize ble;


/**
* Inizializza i parametri di DH a zero
*/
- (void)initParam
{
    NSLog(@"INIZIALIZZO I PARAMETRI DH");
    
    p_prime = BN_new();
    g_base = BN_new();
    Sa = BN_new();
    Ta = BN_new();
    Tb = BN_new();
    DH_key = BN_new();
    
    BN_zero(g_base);
    
    BN_set_word(g_base, DH_GENERATOR_5);
    
    RAND_seed(rnd_seed, sizeof(rnd_seed));
    
}


/**
* Serve a rendere la status bar chiara
*/
- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}


/**
* Viene chiamata quando la view è stata caricata
*/
- (void)viewDidLoad
{    
    [super viewDidLoad];
    
    // imposta la statusbar chiara
    [self setNeedsStatusBarAppearanceUpdate];
    
    // imposta lo sfondo nero alla view
    [self.view setBackgroundColor:[UIColor blackColor]];
    
    // colore del logo di Arduino
    UIColor *arduinoColor = [UIColor colorWithRed:20.0/255.0 green:135.0/255.0 blue:140.0/255.0 alpha:1.0];
    UIColor *arduinoColorSelected = [UIColor colorWithRed:20.0/255.0 green:135.0/255.0 blue:140.0/255.0 alpha:0.5];
    
    
    // alloco la label "RSSI"
    UILabel *RSSI = [[UILabel alloc] initWithFrame:CGRectMake(10, 35, 55, 20)];
    RSSI.textColor = arduinoColor;
    RSSI.font = [UIFont fontWithName:@"arial" size:20];
    
    RSSI.text = @"RSSI:";
    
    [self.view addSubview:RSSI];
    
    
    // alloco la Label del SNR
    lblRSSI = [[UILabel alloc] initWithFrame:CGRectMake(70, 35, 30, 20)];
    lblRSSI.textColor = [UIColor whiteColor];
    lblRSSI.font = [UIFont fontWithName:@"arial" size:20];
    
    lblRSSI.text = @"---";
    
    [self.view addSubview:lblRSSI];
    
    
    // alloco la rotellina
    indConnecting = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indConnecting.frame = CGRectMake(140, 485, 45, 45);
    indConnecting.color = arduinoColor;
    indConnecting.hidesWhenStopped = YES;
    
    [self.view addSubview:indConnecting];
    
    
    // parametri per costruire i bottoni dell'interfaccia
    int btnWidth = 145;
    int btnHeight = 145;
    int btnTitleSize = 24;
    float btnBorderSize = 2.0;
    float btnBorderRadius = 2.0;
    NSString *btnFont = @"arial";
    
    int xLeft = 10;
    int yUp = 70;
    
    int xRight = xLeft + btnWidth + xLeft;
    int yDown = yUp + btnHeight + 10;
    
    // genero il bottone "Connect"
    btnConnect = [self createButton:@"Connect to Arduino"
                              frame:CGRectMake(xLeft, yUp, btnWidth, btnHeight)
                               font:btnFont
                               size:btnTitleSize
                        colorNormal:arduinoColor
                      colorSelected:arduinoColorSelected
                        borderColor:arduinoColor
                         borderSize:btnBorderSize
                       borderRadius:btnBorderRadius];
    
    // genero il bottone "Generate Params"
    secPrimeButton = [self createButton:@"Generate Params"
                                  frame:CGRectMake(xRight, yUp, btnWidth, btnHeight)
                                   font:btnFont
                                   size:btnTitleSize
                            colorNormal:arduinoColor
                          colorSelected:arduinoColorSelected
                            borderColor:arduinoColor
                             borderSize:btnBorderSize
                           borderRadius:btnBorderRadius];
    
    // genero il bottone "Start DH"
    dhButton = [self createButton:@"Start Diffie Hellman"
                            frame:CGRectMake(xLeft, yDown, btnWidth, btnHeight)
                             font:btnFont
                            size:btnTitleSize
                      colorNormal:arduinoColor
                    colorSelected:arduinoColorSelected
                      borderColor:arduinoColor
                       borderSize:btnBorderSize
                     borderRadius:btnBorderRadius];
    
    // genero il bottone "Send Cipher"
    sendCipherButton= [self createButton:@"Send Ciphertext"
                                   frame:CGRectMake(xRight, yDown, btnWidth, btnHeight)
                                    font:btnFont
                                    size:btnTitleSize
                             colorNormal:arduinoColor
                           colorSelected:arduinoColorSelected
                             borderColor:arduinoColor
                              borderSize:btnBorderSize
                            borderRadius:btnBorderRadius];
    
    // aggiungo i bottoni alla view
    [self.view addSubview:btnConnect];
    [self.view addSubview:secPrimeButton];
    [self.view addSubview:dhButton];
    [self.view addSubview:sendCipherButton];
    
    
    // aggiungo le azioni al click del bottone
    [btnConnect addTarget:self action:@selector(btnScanForPeripherals:) forControlEvents:UIControlEventTouchUpInside];
    [secPrimeButton addTarget:self action:@selector(generateDHParams:) forControlEvents:UIControlEventTouchUpInside];
    [dhButton addTarget:self action:@selector(startDH:) forControlEvents:UIControlEventTouchUpInside];
    [sendCipherButton addTarget:self action:@selector(sendCipher:) forControlEvents:UIControlEventTouchUpInside];
    
    // disabilito tutti i bottoni tranne "Connect to Arduino"
    [self disableButton:secPrimeButton];
    [self disableButton:dhButton];
    [self disableButton:sendCipherButton];
    
    
    // alloco il campo di testo
    plainText = [[UITextField alloc] initWithFrame:CGRectMake(xLeft,
                                                              yDown + btnHeight + 20,
                                                              self.view.frame.size.width - 2*xLeft,
                                                              25)];
    plainText.borderStyle = UITextBorderStyleRoundedRect;
    plainText.font = [UIFont fontWithName:@"arial" size:20];
    plainText.placeholder = @"Insert plain text";
    plainText.autocapitalizationType = UITextAutocorrectionTypeNo;
    plainText.keyboardType = UIKeyboardTypeDefault;
    [plainText setReturnKeyType:UIReturnKeyDone];
    plainText.delegate = self;
    
    [self.view addSubview:plainText];
    
    
    // alloco la label per la risposta dell'arduino
    UILabel *rispArduino = [[UILabel alloc] initWithFrame:CGRectMake(xLeft,
                                                                     plainText.frame.origin.y + plainText.frame.size.height + 15,
                                                                     80,
                                                                     25)];
    
    rispArduino.textColor = arduinoColor;
    rispArduino.font = [UIFont fontWithName:@"arial" size:20];
    rispArduino.text = @"Arduino:";
    
    [self.view addSubview:rispArduino];

    
    arduinoPlainText = [[UILabel alloc] initWithFrame:CGRectMake(rispArduino.frame.origin.x + rispArduino.frame.size.width,
                                                                 rispArduino.frame.origin.y,
                                                                 100,
                                                                 25)];
    
    arduinoPlainText.textColor = [UIColor whiteColor];
    arduinoPlainText.font = [UIFont fontWithName:@"arial" size:20];
    arduinoPlainText.text = @"";
    
    [self.view addSubview:arduinoPlainText];
    
    
    srand(time(NULL));
    
    // inizializzo i parametri di DH
    [self initParam];
    
    NSLog(@"ALLOCO L'OGGETTO BLE");
    
    // instauro la connessione con Arduino
    ble = [[BLE alloc] init];
    [ble controlSetup];
    ble.delegate = self;
    
    //[NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(btnScanForPeripherals:) userInfo:nil repeats:NO];
    
    //[self btnScanForPeripherals:nil];
}

-(void)disableButton:(UIButton *)btn
{
    btn.enabled = NO;
    [btn setAlpha:0.5];
}

-(void)enableButton:(UIButton *)btn
{
    btn.enabled = YES;
    [btn setAlpha:1.0];
}

/**
 * Restituisce un UIButton allocato con i parametri posti in ingresso
 */
-(UIButton *)createButton:(NSString *)title frame:(CGRect)rect font:(NSString *)fontName size:(int)fontSize colorNormal:(UIColor *)colorNormal colorSelected:(UIColor *)colorSelected borderColor:(UIColor *)borderColor borderSize:(CGFloat)borderSize borderRadius:(CGFloat)borderRadius
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    //[btnConnect.layer setFrame:buttonFrame];
    
    btn.frame = rect;//CGRectMake(0, 50, 160, 160);
    
    [btn.layer setBorderWidth:borderSize];
    
    [btn.layer setBorderColor:[borderColor CGColor]];
    
    [btn.layer setCornerRadius:borderRadius];
    
    //button.tag = event.eventId;
    [btn setTitle:title forState: UIControlStateNormal];
    btn.titleLabel.font=[UIFont fontWithName:fontName size:fontSize];
    //[btnConnect addTarget:self action:@selector(btnSelected:) forControlEvents:UIControlEventTouchUpInside];
    
    [btn setTitleColor:colorNormal forState:UIControlStateNormal];
    [btn setTitleColor:colorSelected forState:UIControlStateHighlighted];
    [btn setTitleColor:colorSelected forState:UIControlStateSelected];
    
    btn.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    return btn;
}

/*
* Viene invocata quando l'utente clicca su bottone "GenerateParams"
* Assegna un valore a tutti i parametri necessari per DH (p, g, Sa, Ta)
*/
- (IBAction)generateDHParams:(id)sender
{
    [indConnecting startAnimating];
    
    [self initParam];
    
    BN_generate_prime_ex(p_prime, PRIME_LENGTH, 1, NULL, NULL, NULL);
    
    NSString* str_p_prime = [self BIGNUM2NSString:p_prime];
    NSString* str_g_base = [self BIGNUM2NSString:g_base];
    
    /*NSString* str_p_prime = BIGNUM2NSString(p_prime);
    NSString* str_g_base = BIGNUM2NSString(g_base);*/
    
    // copia di p_prime
    BIGNUM *max = BN_dup(p_prime);
    
    BN_sub_word(max, 1);
    
    BN_rand_range(Sa, max);
    
    BN_add_word(Sa, 1);
    
    NSString* str_Sa = [self BIGNUM2NSString:Sa];
    
    //NSString* str_Sa = BIGNUM2NSString(Sa);
    
    BN_CTX *ctx = BN_CTX_new();
    
    BN_mod_exp(Ta, g_base, Sa, p_prime, ctx);
    
    NSString* str_Ta = [self BIGNUM2NSString:Ta];
    
    printf("\n\n");
    NSLog(@"PARAMETRI DH GENERATI");
    NSLog(@"g_base: %@", str_g_base);
    NSLog(@"p_prime: %@", str_p_prime);
    NSLog(@"Sa: %@", str_Sa);
    NSLog(@"Ta: %@", str_Ta);
    
    [indConnecting stopAnimating];
    
    // abilito il bottone per avviare DH
    [self disableButton:secPrimeButton];
    [self enableButton:dhButton];
    /*secPrimeButton.enabled = NO;
    dhButton.enabled = YES;*/
    
}


/*
* Viene chiamato quando l'utente utilizza una shortcut 3D Touch per avviare DH
*/
- (void)startDHWithShortcut
{
    // mostra la tastiera
    [plainText becomeFirstResponder];
    
    [self startDH:nil];
}


/**
* Avvia la connessione DH con l'Arduino
*/
- (IBAction)startDH:(id)sender
{
    printf("\n\n");
    NSLog(@"INVIO I PER INIZIALIZZARE L'ARDUINO");
    
    [self sendPkt:0x49 bignumber:BN_value_one()];
    
    printf("\n\n");
    NSLog(@"INVIO P\n");
    
    [self sendPkt:0x50 bignumber:p_prime]; //0x50
    
    printf("\n\n");
    NSLog(@"INVIO G\n");
    
    [self sendPkt:0x47 bignumber:g_base]; //0x47
    
    printf("\n\n");
    NSLog(@"INVIO T\n");
    
    [self sendPkt:0x54 bignumber:Ta];//0x54
    
    printf("\n\n");
    NSLog(@"TERMINE INVIO DATI IPHONE -> ARDUINO\n");
    
    // abilito il bottone per inviare il cipher
    [self disableButton:dhButton];
    [self enableButton:sendCipherButton];
    /*sendCipherButton.enabled = YES;
    dhButton.enabled = NO;*/
}


/**
 * Calcola la chiave Diffie Hellman e la assegna alla variabile globale
 * @param data      char * contenente Tb (BIGNUM) inviato dall'arduino
 * @param length    lunghezza del parametro data
 */
-(void)calcolaDH_key:(unsigned char *)data length:(int)length
{
    printf("\n\n");
    NSLog(@"CALCOLO CHIAVE DH\n");
    
    BIGNUM *num = [self convHex2Dec:data lung:length];
    
    NSLog(@"Dato convertito in BIGNUM: %@", BIGNUM2NSString(num));
    
    Tb = num;
    
    //BIGNUM *k = BN_new();
    
    BN_CTX *ctx = BN_CTX_new();
    
    BN_mod_exp(DH_key, Tb, Sa, p_prime, ctx);
    
    NSLog(@"-> DH KEY: %@", BIGNUM2NSString(DH_key));
    
    // genero la chiave e la memorizzo in un NSData per poterla utilizzare con i metodi della libreria AES
    NSData *keyHexData = [[self BIGNUM2NSString:DH_key] dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char keyBytes[KEY_LENGTH_BYTE];
    unsigned char *hex = (uint8_t *)keyHexData.bytes;
    
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i=0; i<KEY_LENGTH_BYTE; i++) {
        byte_chars[0] = hex[i*2];
        byte_chars[1] = hex[(i*2)+1];
        keyBytes[i] = strtol(byte_chars, NULL, KEY_LENGTH_BYTE);
    }
    
    // chiave DH
    keyData = [NSData dataWithBytes:keyBytes length:KEY_LENGTH_BYTE];
    
}


/**
 * Restituisce una stringa con il comando anteposto, pronta per essere inviata
 * @param msg   NSString contenete il messaggio da inviare
 * @param cmd   Comando da anteporre alla stringa in ingresso
 * @return      NSString contenente il comando concatenato al messaggio
 */
-(NSString *)preparePlainText:(NSString *)msg comando:(unsigned char)cmd
{
    NSString* strCMD = [NSString stringWithFormat:@"%c" , cmd];
    
    return [NSString stringWithFormat:@"%@%@", strCMD, msg];
}

/**
 * Invia il cipher del testo in chiaro dall'iphone all'arduino
 */
-(IBAction)sendCipher:(id)sender
{
    printf("\n\n");
    NSLog(@"SEND CIPHER\n");
    
    // initialization vector per cbc
    //NSData *ivData = [NSData dataWithBytes:(char []){0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} length:16];
    //NSLog(@"ivData:     %@", ivData);
    
    NSString *secret = @"";
    
    // controllo che sia stato inserito del testo nel text field
    if([plainText.text length] > 0)
        secret = plainText.text;
    else
        secret = @"plain text";
    
    // genero il testo cifrato
    NSData *cipher = [[secret dataUsingEncoding:NSUTF8StringEncoding] AES128EncryptedDataWithKey:keyData iv:nil];
    NSLog(@"-> CIPHER DATA: %@", cipher);
    
    // decifro il testo cifrato per controprova
    NSData *plain = [cipher AES128DecryptedDataWithKey:keyData iv:nil];
    NSLog(@"-> PLAIN DATA: %@", plain);
    
    // invio il pacchetto cifrato all'arduino
    [self sendPkt:'M' stringa:cipher];
}


/**
 * Restituisce un NSData contentente i byte del char * in ingresso
 * @param data  unsigned char * contenete il messaggio cifrato
 * @return      NSData contenente il messaggio cifrato
 */
-(NSData *)arrayCharToNSData:(unsigned char *)data
{
    NSString *arduinoCipherSTR = [[NSString alloc] initWithCString:(const char *)data encoding:NSUTF8StringEncoding];
    
    NSLog(@"-> CIPHER DATA STR: %@", arduinoCipherSTR);
    
    NSData *arduinoCipher = [arduinoCipherSTR dataUsingEncoding:NSUTF8StringEncoding];
    
    NSLog(@"-> CIPHER DATA: %@", arduinoCipher);
    
    // la lunghezza dell'array di byte e' uguale a quella di cipher che e' uguale a quella della chiave
    unsigned char dataBytes[KEY_LENGTH_BYTE];
    unsigned char *hex = (uint8_t *)arduinoCipher.bytes;
    
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i=0; i<KEY_LENGTH_BYTE; i++) {
        byte_chars[0] = hex[i*2];
        byte_chars[1] = hex[(i*2)+1];
        dataBytes[i] = strtol(byte_chars, NULL, KEY_LENGTH_BYTE);
    }
    
    arduinoCipher = [NSData dataWithBytes:dataBytes length:KEY_LENGTH_BYTE];
    
    return arduinoCipher;
}

/**
* Viene chiamato quando l'iphone sta ricevendo dati tramite bluetooth
* @param data       unsigned char * contenente i dati in ingresso
* @param length     lunghezza del parametro data
*/
-(void) bleDidReceiveData:(unsigned char *)data length:(int)length
{
    printf("\n\n");
    NSLog(@"HO RICEVUTO IL DATO DALL'ARDUINO\n");
    
    NSLog(@"Lunghezza del dato: %d", length);
    
    NSLog(@"-> Dato ricevuto: %s", data);
    
    // servono quando arduino risponde con un messaggio cifrato
    NSData *arduinoCipher = nil;
    //NSString *arduinoCipherSTR = @"";
    NSData *arduinoPlain = nil;
    
    // comando del messaggio (e' il primo carattere)
    unsigned char cmd = data[0];
    
    data++; // elimino il primo carattere che è il comando
    
    switch(cmd)
    {
        // l'Arduino ha inviato Tb
        case 'T':
            
            // passo length-1 perchè ho tolto un carattere
            [self calcolaDH_key:data length:length-1];
            
            break;
           
        // l'Arduino ha inviato una risposta cifrata
        case 'R':
            
            // DA SISTEMARE!!
            /*arduinoCipherSTR = [[NSString alloc] initWithCString:(const char *)data encoding:NSUTF8StringEncoding];
            
            NSLog(@"-> CIPHER DATA STR: %@", arduinoCipherSTR);
            
            arduinoCipher = [arduinoCipherSTR dataUsingEncoding:NSUTF8StringEncoding];
            
            NSLog(@"-> CIPHER DATA: %@", arduinoCipher);
            
            unsigned char dataBytes[KEY_LENGTH_BYTE];
            unsigned char *hex = (uint8_t *)arduinoCipher.bytes;
            
            char byte_chars[3] = {'\0','\0','\0'};
            for (int i=0; i<KEY_LENGTH_BYTE; i++) {
                byte_chars[0] = hex[i*2];
                byte_chars[1] = hex[(i*2)+1];
                dataBytes[i] = strtol(byte_chars, NULL, KEY_LENGTH_BYTE);
            }

            arduinoCipher = [NSData dataWithBytes:dataBytes length:KEY_LENGTH_BYTE];*/
            
            arduinoCipher = [self arrayCharToNSData:data];
            
            arduinoPlain = [arduinoCipher AES128DecryptedDataWithKey:keyData iv:nil];
            
            NSLog(@"-> PLAIN DATA: %@", arduinoPlain);
            
            NSLog(@"-> PLAIN TEXT: %@", [[NSString alloc] initWithData:arduinoPlain encoding:NSUTF8StringEncoding]);
            
            arduinoPlainText.text = [[NSString alloc] initWithData:arduinoPlain encoding:NSUTF8StringEncoding];
            
            break;
            
        default:
            
            NSLog(@"Comando sconosciuto: %c", cmd);
            
            break;
    }
}


/**
* Manda un pacchetto contenente il comando e un big number come payload
* @param cmd    comando da eseguire
* @param bn     BIGNUM da inviare come payload
*/
-(void)sendPkt:(UInt8)cmd bignumber:(const BIGNUM *)bn
{
    //printf("\n\n");
    //NSLog(@"SEND PACKET\n");
    
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
    
    NSLog(@"LUNGHEZZA PACCHETTO: %lu", (sizeof(buf_pkt)/sizeof(UInt8)));
    
    for(i=0; i<NUM_PKT_HEADER + numByteLengthPayload + numBytePayload; i++)
    {
        printf("%x", buf_pkt[i]);
    }
    
    printf("\n");
    
    // invio il pacchetto
    NSData *data = [[NSData alloc] initWithBytes:buf_pkt length:(sizeof(buf_pkt)/sizeof(UInt8))];
    [ble write:data];
}


/**
 * Manda un pacchetto contenente il comando e un NSData come payload
 * @param cmd    comando da eseguire
 * @param bn     NSData da inviare come payload
 */
-(void)sendPkt:(UInt8)cmd stringa:(NSData *)msg
{
    printf("\n\n");
    NSLog(@"SEND PACKET\n");
    
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
        //printf("buffer[%d]=0x%02x\n",i,buffer[i]);
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
    [ble write:data];
    
    //printf("NSData originale %s\n", [[msg description] UTF8String]);
}


/**
 * Restituisce un vettore di UInt8 contenente il bignumber
 * @param bn    Oggetto BIGNUM da splittare in un vettore di UInt8
 * @return      Puntatore ad un oggetto UInt8, è il primo elemento del vettore.
 */
UInt8* getUIntPayload(const BIGNUM* bn, int* byteMess)
{
    int numByte = (int) ceil(((double)BN_num_bits(bn))/NUM_BIT_IN_BYTE);
    
    //NSLog(@"numByte: %d", numByte);
    
    UInt8* buffer = malloc(numByte * sizeof(UInt8));
    
    //NSLog(@"sizeof(buffer): %lu", sizeof(*buffer));
    //NSLog(@"BN_num_bytes(bn): %d", BN_num_bytes(bn));

    // NB non si può usare sizeof con le malloc,
    // bisogna sistemare la lunghezza del payload nel caso in cui la lunghezza del numero primo sia > 32
    
    int numBytePadding = (BN_num_bytes(bn)/sizeof(UInt8)) - numByte;
    
    //NSLog(@"numBytePadding: %d/%d - %d", BN_num_bytes(bn), sizeof(UInt8), numByte);
    
    //NSLog(@"numBytePadding: %d", numBytePadding);
    
    if (buffer != NULL)
    {
        //NSString* str = [self BIGNUM2NSString:bn];
        
        NSString* str = BIGNUM2NSString(bn);
        
        //NSLog(@"BNstr: %@", str);
        
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
            //printf("buffer[%d]=0x%02x\n",i,buffer[i]);
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
    int temp=0;
    
    BIGNUM *bn = BN_new();
    
    BN_set_word(bn, num);
    
    return getUIntPayload(bn, &temp);
}


/** 
* Restituisce quanti byte ci vogliono per inviare num
* @param num    Numero di cui bisogna calcolare il numero di byte necessari per inviarlo.
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
* Genera un BIGNUM a partire da un num
* @param num    numero intero che si vuole convertire in BIGNUM
* @return       BIGNUM contenente l'intero passato in ingresso
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
* @return       BIGNUM contenente il numero passato in ingresso
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
    
    //NSLog(@"NUMERO CONVERTITO: %@", BIGNUM2NSString(sum));
    
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


/**
 * Converte un BIGNUM in un oggetto NSString
 * @param    bn  bignumber da convertire
 * @return   Oggetto NSString ottenuto convertendo bn
 */
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
 * Converte un char in int
 * @param elem   char da convertire in int
 * @return       int da 0 a 15 che rappresenta elem
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
* Converte un numero (da 0 a 15) da notazione decimale a esadecimale (es: 10 -> A)
*/
static inline char itoh(int i) {
    if (i > 9) return 'a' + (i - 10);
    return '0' + i;
}


/**
* Converte un NSData in un NSString esadecimale
* @param data   NSData da convertire in stringa esadecimale
* @return       NSString contenete data rappresentato in esadecimale
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


/**
 * Converte un NSString esadecimale in un NSData
 * @param string    NSString contenente dati in esadecimale
 * @return          NSData contenete la stringa in ingresso
 */
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


/**
 * Converte un numero esadecimale contenuto in una stringa in un numero intero decimale
 * @param num       NSString che contiene il numero esadecimale da convertire
 * @param numByte   Numero di byte occupato dal numero esadecimale in ingresso (ogni 2 cifre => 1 byte)
 * @return          Numero intero che rappresenta il numero esadecimale in ingresso
 */
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


// ----------------------- DELEGATE METHODS -----------------------
// ----------------------------------------------------------------

/**
 * Utile a far scomparire la tastiera quando viene cliccato il bottone FINE
 */
-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    
    [textField resignFirstResponder];
    return YES;
}


/**
 * Viene chiamato quando l'utente inizia a scrivere nel text field
 */
-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    //NSLog(@"Did Begin Editing");
    
    //NSLog(@"Animation");
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    self.view.frame = CGRectMake(self.view.frame.origin.x,
                                 self.view.frame.origin.y-DELTA_Y_KEYBOARD,
                                 self.view.frame.size.width,
                                 self.view.frame.size.height);
    
    [UIView commitAnimations];
}


/**
 * Viene chiamato quando l'utente finisce di scrivere nel text field
 */
-(void)textFieldDidEndEditing:(UITextField *)textField
{
    //NSLog(@"Did End Editing");
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    self.view.frame = CGRectMake(self.view.frame.origin.x,
                                 self.view.frame.origin.y+DELTA_Y_KEYBOARD,
                                 self.view.frame.size.width,
                                 self.view.frame.size.height);
    
    [UIView commitAnimations];
}


/**
 * Controlla che la l'utente inserisca un numero massimo di caratteri nella Text field
 */
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger oldInteger = [textField.text length];
    NSUInteger replacementLength = [string length];
    NSUInteger rangeLength = range.length;
    
    NSUInteger newLength = oldInteger - rangeLength + replacementLength;
    
    BOOL returnKey = [string rangeOfString:@"\n"].location != NSNotFound;
    
    return newLength <= MAX_PLAIN_CHAR || returnKey;
}


// ----------------------- BLE METHODS -----------------------
// -----------------------------------------------------------

#pragma mark - BLE delegate

NSTimer *rssiTimer;

// When disconnected, this will be called
- (void)bleDidDisconnect
{
    NSLog(@"->Disconnected");
    
    [btnConnect setTitle:@"Connect to Arduino" forState:UIControlStateNormal];
    [indConnecting stopAnimating];
    
    // disabilito tutti i bottoni tranne "Connect"
    /*secPrimeButton.enabled = NO;
    dhButton.enabled = NO;
    sendCipherButton.enabled = NO;*/
    
    [self disableButton:secPrimeButton];
    [self disableButton:dhButton];
    [self disableButton:sendCipherButton];
    
    lblRSSI.text = @"---";
    
    [rssiTimer invalidate];
}

// When RSSI is changed, this will be called
-(void) bleDidUpdateRSSI:(NSNumber *) rssi
{
    lblRSSI.text = rssi.stringValue;
}

-(void) readRSSITimer:(NSTimer *)timer
{
    [ble readRSSI];
}

// When connected, this will be called
-(void) bleDidConnect
{
    NSLog(@"-> Connected");
    
    [indConnecting stopAnimating];
    
    // abilito il bottone per generare i parametri di DH
    //secPrimeButton.enabled = YES;
    [self enableButton:secPrimeButton];
    
    // send reset
    /*
     UInt8 buf[] = {0x04, 0x00, 0x00};
     NSData *data = [[NSData alloc] initWithBytes:buf length:3];
     [ble write:data]; NON LO MANDO PERCHE FA SALTARE TUTTO!!!
     */
    
    // Schedule to read RSSI every 1 sec.
    rssiTimer = [NSTimer scheduledTimerWithTimeInterval:(float)1.0 target:self selector:@selector(readRSSITimer:) userInfo:nil repeats:YES];
}


#pragma mark - Actions

// Connect button will call to this
//- (IBAction)btnScanForPeripherals:(id)sender
- (IBAction)btnScanForPeripherals:(id)sender
{
    NSLog(@"SCAN FOR PERIPHERALS");
    
    if (ble.activePeripheral)
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            [btnConnect setTitle:@"Connect to Arduino" forState:UIControlStateNormal];
            
            return;
        }
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
    [btnConnect setEnabled:false];
    [ble findBLEPeripherals:2];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
    [indConnecting startAnimating];
}

/**
* Chiamato quando l'utente utilizza 3D Touch
*/
-(void)connectWithShortcut
{
    NSLog(@"SCAN FOR PERIPHERALS WITH 3D TOUCH");
    
    if (ble.activePeripheral)
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            [btnConnect setTitle:@"Connect to Arduino" forState:UIControlStateNormal];
            
            return;
        }
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
    [btnConnect setEnabled:false];
    [ble findBLEPeripherals:2];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
    [indConnecting startAnimating];
}

-(void) connectionTimer:(NSTimer *)timer
{
    [btnConnect setEnabled:true];
    [btnConnect setTitle:@"Disconnect from Arduino" forState:UIControlStateNormal];
    
    if (ble.peripherals.count > 0)
    {
        [ble connectPeripheral:[ble.peripherals objectAtIndex:0]];
        
        // notifica che la scansione e' terminata
        [self notify:NAME_FINISH_SCAN];
    }
    else
    {
        [btnConnect setTitle:@"Connect to Arduino" forState:UIControlStateNormal];
        [indConnecting stopAnimating];
    }
    
}

- (void)notify:(NSString *)name
{
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end