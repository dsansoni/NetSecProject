//
//  TableViewController.h
//  SimpleControl
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// Bluetooth
#import "BLE.h"

// OpenSSL
#import "openssl/bn.h"
#import "openssl/dh.h"
#import "stdlib.h"


@interface TableViewController : UIViewController <BLEDelegate, UITextFieldDelegate>
{
    // SNR
    UILabel *lblRSSI;
    
    // bottone di connessione
    UIButton *btnConnect;
    
    // Bottone per generare i parametri necessari per lo scambio di DH
    UIButton *secPrimeButton;
    
    // bottone per eseguire DH
    UIButton *dhButton;
    
    // Bottone che invia un testo cifrato all'arduino 
    UIButton *sendCipherButton;
    
    // rotella di caricamento
    UIActivityIndicatorView *indConnecting;
    
    // campo di testo per inserire plain text
    UITextField *plainText;
    
    // label contenente il messaggio dell'arduino
    UILabel *arduinoPlainText;
    
    //NSString *plainTextString;
    
    // numero primo
    BIGNUM *p_prime;
    
    // generatore di Zp*
    BIGNUM *g_base;
    
    // numero segreto di A (numero casuale 1<=Sa<=(p-1))
    BIGNUM *Sa;
    
    // Ta = (g^Sa) modp
    BIGNUM *Ta;
    
    // mandato da B (Arduino) = (g^Sb) modp
    BIGNUM *Tb;
    
    // chiave Diffie Hellman
    BIGNUM *DH_key;
    
    // NSData contenente la chiave DH (da usare con i metodi di cifratura)
    NSData *keyData;
    
}

// oggetto BLE shield per comunicare con l'Arduino tramite Bluetooth
@property (strong, nonatomic) BLE *ble;

- (void)connectWithShortcut;
- (IBAction)btnScanForPeripherals:(id)sender;
- (IBAction)generateDHParams:(id)sender;
- (IBAction)startDH:(id)sender;
- (void)startDHWithShortcut;

@end
