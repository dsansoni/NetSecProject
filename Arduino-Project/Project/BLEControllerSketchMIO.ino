/*

Copyright (c) 2012, 2013 RedBearLab

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/
#include <time.h>
#include <Servo.h>
#include <SPI.h>
#include <boards.h>
#include <RBL_nRF8001.h>
#include <RBL_services.h>
#include "Boards.h"
#include "BigNumber.h"
#include "AES.h"
/*#include <AESLib.h>*/

//#include "random_bignumber.h"

#define PROTOCOL_MAJOR_VERSION   0 //
#define PROTOCOL_MINOR_VERSION   0 //
#define PROTOCOL_BUGFIX_VERSION  2 // bugfix

#define PIN_CAPABILITY_NONE      0x00
#define PIN_CAPABILITY_DIGITAL   0x01
#define PIN_CAPABILITY_ANALOG    0x02
#define PIN_CAPABILITY_PWM       0x04
#define PIN_CAPABILITY_SERVO     0x08
#define PIN_CAPABILITY_I2C       0x10

// pin modes
//#define INPUT                 0x00 // defined in wiring.h
//#define OUTPUT                0x01 // defined in wiring.h
#define ANALOG                  0x02 // analog pin in analogInput mode
#define PWM                     0x03 // digital pin in PWM output mode
#define SERVO                   0x04 // digital pin in Servo output mode

byte pin_mode[TOTAL_PINS];
byte pin_state[TOTAL_PINS];
byte pin_pwm[TOTAL_PINS];
byte pin_servo[TOTAL_PINS];

//Servo servos[MAX_SERVOS];

// Diffie Helman param
BigNumber p_prime;
BigNumber g_base;
BigNumber Sb;

// iPhone
BigNumber Ta;

// Arduino
BigNumber Tb;

// DH KEY
BigNumber dh_key;

// utili in fase di ricezione dei parametri
boolean ricevutoParametri;
boolean calcolatoChiave;

#define KEYLENGTH 128
#define NUM_BIT_IN_BYTE 8

byte key[KEYLENGTH];

/*byte plain[N_BLOCK];
byte cipher [N_BLOCK] ;
byte cipher2 [N_BLOCK] ;
byte decrypted [N_BLOCK] ;
byte decrypted2 [N_BLOCK] ;*/

byte *plain;
byte *cipher;
byte *cipherResponse;
byte *decrypted;
byte *decrypted2;

// oggetto sul quale invocare i metodi per usare AES
AES aes;

static byte buf_len = 0;

// setup iniziale
void setup()
{
  Serial.begin(57600);

  // seed per i random
  unsigned long seed = 0;
  for (int i = 0; i < 32; i++)
    seed = seed | ((analogRead(A0) & 0x01) << i);
  
  randomSeed(seed);

  Serial.println("");
  Serial.println("BLE Arduino Slave");

  // inizializzo la libreria per i big number


  // Init. and start BLE library.
  ble_begin();
}

// inizializza i parametri di diffie hellman
void init_param()
{
  ricevutoParametri = false;
  calcolatoChiave = false;

  p_prime = BigNumber(0);
  g_base = BigNumber(0);
  Sb = BigNumber(0);
  Ta = BigNumber(0);
  Tb = BigNumber(0);

  dh_key = BigNumber(0);
}

// Restituisce una stringa da stampare di un bigNumber
String toStringBignum(bc_num x)
{
  char *s = bc_num2str(x);

  String str = String(s);
  //Serial.print(s);
  free(s);
  return str;
}

byte queryDone = false;

int convCharToInt(char elem)
{
  if (elem == '0')
    return 0;

  if (elem == '1')
    return 1;

  if (elem == '2')
    return 2;

  if (elem == '3')
    return 3;

  if (elem == '4')
    return 4;

  if (elem == '5')
    return 5;

  if (elem == '6')
    return 6;

  if (elem == '7')
    return 7;

  if (elem == '8')
    return 8;

  if (elem == '9')
    return 9;

  if (elem == 'a')
    return 10;

  if (elem == 'b')
    return 11;

  if (elem == 'c')
    return 12;

  if (elem == 'd')
    return 13;

  if (elem == 'e')
    return 14;

  if (elem == 'f')
    return 15;
}

char convInt2HexChar(int val)
{
  if (val >= 0 && val <= 9)
    return ('0' + val);
  else if (val > 9)
  {
    switch (val)
    {
      case 10:
        return 'a';
        break;

      case 11:
        return 'b';
        break;

      case 12:
        return 'c';
        break;

      case 13:
        return 'd';
        break;

      case 14:
        return 'e';
        break;

      case 15:
        return 'f';
        break;
    }
  }

  else
    Serial.println("ERRORE nella conversione DEC to HEX");
}

/* Riceve una stringa in esadecimale e la converte in int
 * @param num       stringa esadecimale
 * @param numByte   lunghezza in byte del numero esadecimale contenuto nella stringa
 * @return          intero corrispondente al numero esadecimale contenuto nella stringa
 */
int convHex2Dec(String num, int numByte = 1)
{
  int i;
  float sum = 0.0;
  for (i = 0; i < numByte * 2; i++)
  {
    if (convCharToInt(num.charAt(i)) != 0)
    {
      // converto il carattere in numero e lo moltiplico per la corrispondente
      // potenza di 16 per trasformarlo in base 10
      sum = sum + convCharToInt(num.charAt(i)) * pow(16, numByte * 2 - 1 - i);
    }

    //Serial.println("SUM: " + sum);
  }

  return (int) sum;
}


/* Riceve una stringa in esadecimale e la converte in BigNumber. Variante per i BigNumber
 * @param num       stringa esadecimale
 * @param numByte   lunghezza in byte del numero esadecimale contenuto nella stringa
 * @return          intero corrispondente al numero esadecimale contenuto nella stringa
 */
BigNumber convHex2DecBN(String num, int numByte = 1)
{
  int i;
  BigNumber sum_bn = BigNumber(0);
  for (i = 0; i < numByte * 2; i++)
  {
    // converto il carattere in numero e lo moltiplico per la corrispondente
    // potenza di 16 per trasformarlo in base 10
    sum_bn = sum_bn + BigNumber(convCharToInt(num.charAt(i))) * BigNumber(16).pow(numByte * 2 - 1 - i);
  }

  return sum_bn;
}


/**
 * Converte un numero decimale in una stringa esadecimale
 * @param bn    BigNumber da convertire in stringa esadecimale
 * @return      Stringa contenente il BigNumber convertito il esadecimale
 */
String convDec2Hex(int num)
{
  //BigNumber base = BigNumber(16);

  //BigNumber temp = BigNumber(bn);
  int temp = num;
  int base = 16;
  int quoziente = 1;
  int resto;

  String result = String("");

  // valore a caso maggiore di 0 per entrare nel while
  //BigNumber quoziente = BigNumber(1);

  while (quoziente > 0)
  {
    quoziente = temp / base;

    resto = temp % base; //String((temp % base).toString()).toInt();

    result = String(convInt2HexChar(resto)) + result;

    temp = quoziente;

  }

  if(result.length()%2)
    result = "0" + result;

  return result;
}

/**
 * Converte un numero decimale in una stringa esadecimale
 * @param bn    BigNumber da convertire in stringa esadecimale
 * @return      Stringa contenente il BigNumber convertito il esadecimale
 */
String convDec2HexBN(BigNumber bn)
{
  BigNumber base = BigNumber(16);

  BigNumber temp = BigNumber(bn);
  int resto;

  String result = String("");

  // valore a caso maggiore di 0 per entrare nel while
  BigNumber quoziente = BigNumber(1);

  while (quoziente > 0)
  {
    quoziente = temp / base;

    resto = String((temp % base).toString()).toInt();

    result = String(convInt2HexChar(resto)) + result;

    temp = quoziente;

  }

  if(result.length()%2)
    result = "0" + result;

  return result;
}


/**
 * Legge numByte dalla seriale e li mette in una stringa (in formato hex)
 * @param numByte   Numero di byte che devo leggere
 * @return          Stringa contenente i byte letti in formato hex
 */
String mergeHexString(int numByte = 1)
{
  String result = String("");

  int i;
  for (i = 0; i < numByte; i++)
  {
    String elem = String(ble_read(), HEX);

    // aggiunge uno "0" in testa se necessario
    if (elem.length() < 2)
      elem = "0" + elem;

    result = result + elem;
  }

  return result;
}


/**
 * Legge una byte dalla seriale
 * @return  Stringa contenente il byte letto in formato hex
 */
String ble_read_hex()
{
  String result = String(ble_read(), HEX);

  if (result.length() < 2)
    result = "0" + result;

  return result;
}


/**
 * Invia una stringa tramite BLE
 * @param daInviare Stringa da inviare
 */
void sendPkt(String daInviare)
{
  int i;
  for (i = 0; i < daInviare.length(); i++)
  {
    unsigned char elem = daInviare.charAt(i);

    ble_write(elem);
  }
}


// ------------------------ LOOP --------------------------

void loop()
{
  int NUM_BYTE = 6;

  while (ble_available())
  {

    Serial.println("BLE AVAILABLE");
    // PACCHETTO DATI:
    //
    // +--------+--------+---------------------+---------------------------------------------------+
    // |   CMD  |   LML  |      MSG Length     |                 Message (PAYLOAD)                 |
    // +--------+--------+---------------------+---------------------------------------------------+
    //   1byte    1byte          <LML> byte                        <MSG Length> byte


    // contiene il comando da eseguire
    String CMD = ble_read_hex();

    //Serial.println("COMANDO: " + CMD);

    // length of MSG length field
    String LML = ble_read_hex(); 

    //Serial.println("LML: " + LML);

    // contiene la lunghezza del campo MSG_L
    int length_MSG_L = convHex2Dec(LML);
    String MSG_L = mergeHexString(length_MSG_L);

    //Serial.println("MSG_L: " + MSG_L);

    // contiene la lunghezza del campo PAYLOAD
    int length_PAYLOAD = convHex2Dec(MSG_L, length_MSG_L);
    String PAYLOAD = mergeHexString(length_PAYLOAD);

    //Serial.println("PAYLOAD: " + PAYLOAD);

    char carComando = convHex2Dec(CMD);

    Serial.println("[DEBUG] cmd: " + String(carComando) + " LML: " + LML + " MSG_L: " + length_PAYLOAD + " PAYLOAD: " + PAYLOAD);

    byte *cipherMSG;
    String chiaveHEX;
    String result;
    int i = 0;
    int count = 0;

    String plainSTR = "text to encrypt";
    byte *plainSTRByte;

    unsigned char temp;

    String response = "risposta ok";
    byte responseByte [response.length()];
    String cipherResponseSTR = "";

    //char response[] = ;

    switch (carComando)
    {
      case 'I':
        init_param();
        Serial.println("Parametri inizializzati");

        break;

      case 'P':
        //p_prime=convHex2Dec(PAYLOAD);
        p_prime = convHex2DecBN(PAYLOAD, length_PAYLOAD);
        Serial.println("Ho ricevuto p_prime: \ndec: " + String(p_prime.toString()));
        Serial.println("hex: " + PAYLOAD);
        break;

      case 'G':
        g_base = convHex2DecBN(PAYLOAD, length_PAYLOAD);
        Serial.println("Ho ricevuto g_base: \ndec: " + String(g_base.toString()));
        Serial.println("hex: " + PAYLOAD);
        break;

      case 'T':
        Ta = convHex2DecBN(PAYLOAD, length_PAYLOAD);
        Serial.println("Ho ricevuto Ta: \ndec" + String(Ta.toString()));
        Serial.println("hex: " + PAYLOAD);
        break;

      case 'M':
        
        // memorizzo il messaggio cipher in un array di byte da usare con AES per arduino
        //cipherMSG = (byte*)malloc(sizeof(byte) * length_PAYLOAD);

        //plain = (byte*)malloc(sizeof(byte) * length_PAYLOAD);

        cipher = (byte*)malloc(sizeof(byte) * length_PAYLOAD);
        cipherResponse = (byte*)malloc(sizeof(byte) * length_PAYLOAD);
        
        decrypted = (byte*)malloc(sizeof(byte) * length_PAYLOAD);
        decrypted2 = (byte*)malloc(sizeof(byte) * length_PAYLOAD);

        Serial.print("\nCipher: ");

        count=0;
        for (i = 0; i < length_PAYLOAD*2; i = i + 2)
        {
          unsigned char sum = (unsigned char) convHex2Dec(PAYLOAD.substring(i, i + 2)); //car1+car2;
          cipher[count] = sum;
          Serial.print(cipher[count],HEX);
          count++;
        }

        chiaveHEX = convDec2HexBN(dh_key);

        // memorizzo la chiave DH in un array di byte da usare con AES per arduino
        //key = (byte*)malloc(sizeof(byte) * (chiaveHEX.length() / 2));

        Serial.print("\nDH key: ");

        count=0;
        for (i = 0; i < chiaveHEX.length(); i = i + 2)
        {
          unsigned char sum = (unsigned char) convHex2Dec(chiaveHEX.substring(i, i + 2)); //car1+car2;

          key[count] = (byte) sum;
          Serial.print(key[count],HEX);

          count++;
        }

        Serial.println("\n");

        // setto la chiave di AES
        if (aes.set_key (key, KEYLENGTH) !=0)
          Serial.println(F("Failed to set key"));

        // inizializzo il cipher e il decrypted
        for (int i = 0; i < N_BLOCK; i++) 
        {
          cipherResponse[i] = 0;
          decrypted[i] = 0;
          decrypted2[i] = 0;
        }
        
        // Show encrypted message
        Serial.print(F("encrypted: "));
        for (int i = 0; i < N_BLOCK; i++) 
        {
          Serial.print(cipher[i], HEX);
          Serial.print(F(" "));
        }

        Serial.print("\n");

        // decifro quello che ho ricevuto
        if (aes.decrypt(cipher, decrypted) == 0) 
        {
          /*Serial.println(F("\ndecrypted binary: "));
          for (int i = 0; i < N_BLOCK; i++) 
          {
            Serial.print(decrypted[i], HEX);
            Serial.print(F(" "));
          }
          Serial.println(F(""));*/
          Serial.print(F("decrypted: "));
          for (int i = 0; i < N_BLOCK; i++) 
          {
            Serial.print((char) decrypted[i]);
          }
          Serial.println(F(""));

          Serial.print("\n");
          
        } 
        else 
        {
          Serial.println(F("Failed to decrypt"));
        }


        Serial.print("Response text: ");
        // inserisco la risposta nell'array di byte
        for (int i = 0; i < response.length(); i++) 
        {
          responseByte[i] = response.charAt(i);
          Serial.print(responseByte[i]);
        }
        Serial.println(F(""));
        

        // cifro la risposta da mandare all'iphone
        if (aes.encrypt(responseByte, cipherResponse) == 0) 
        {
          Serial.println(F("\ncipherResponse: "));
          for (int i = 0; i < length_PAYLOAD; i++) 
          {
            Serial.print(cipherResponse[i], HEX);
            Serial.print(F(" "));
          }
          Serial.println(F(""));
        } 
        else 
        {
          Serial.println(F("Failed to encrypt"));
        }

        // trasformo il vettore di byte in una stringa da mandare all'iphone
        cipherResponseSTR = "R";

        for(i=0; i<length_PAYLOAD; i++)
        {
          //String temp = String(cipherResponse[i], HEX);
          
          cipherResponseSTR = cipherResponseSTR + convDec2Hex(cipherResponse[i]);
        }

        Serial.println("\nCipher da mandare all'iphone: " + cipherResponseSTR);

        sendPkt(cipherResponseSTR);

       // decifro quello che ho cifrato io
        /*if (aes.decrypt(cipherResponse, decrypted2) == 0) 
        {
          Serial.println(F("\ndecrypted2 binary: "));
          for (int i = 0; i < N_BLOCK; i++) 
          {
            Serial.print(decrypted2[i], HEX);
            Serial.print(F(" "));
          }
          Serial.println(F(""));
          Serial.println(F("decrypted2 char: "));
          for (int i = 0; i < N_BLOCK; i++) 
          {
            Serial.print((char) decrypted2[i]);
          }
          Serial.println(F(""));
          
        } 
        else 
        {
          Serial.println(F("Failed to decrypt"));
        }*/

        break;

      default:
        break;
        
    } // end cmd switch

    // controllo se ho ricevuto tutti i parametri di DH
    if (!ricevutoParametri)
    {
      if (p_prime > 0 && g_base > 0 && Ta > 0)
        ricevutoParametri = true;
    }


    if (ricevutoParametri)
    {
      if (!calcolatoChiave)
      {
        //Sb = random(1,p_prime-1);

        char *bignum = p_prime.toString();
        char *randomBignum = NULL; //+1 for '\0'
        randomBignum = randomCharArray(bignum);

        Sb = BigNumber(randomBignum);

        // converto i parametri in BigNumber
        /*BigNumber bn_g_base = BigNumber(g_base);
        BigNumber bn_p_prime = BigNumber(p_prime);
        BigNumber bn_Sb_exp = BigNumber(secretNumber);
        BigNumber bn_Ta = BigNumber(Ta);*/

        // powMod(exp, mod)
        BigNumber Tb = g_base.powMod(Sb, p_prime);

        String Tb_str = String(Tb.toString());

        sendPkt("T" + convDec2HexBN(Tb));

        Serial.println("Mando Tb all'iPhone: " + convDec2HexBN(Tb));

        //ble_write(Tb_str);

        //Tb = String(Tb.toString()).toInt();

        // K = Ta^Sb modp

        dh_key = Ta.powMod(Sb, p_prime);

        Serial.println("\nDIFFIE-HELLMAN PARAMETERS\n");

        Serial.println("g: dec -> " + String(g_base.toString()) + "\n   hex -> " + convDec2HexBN(g_base) + "\n");
        Serial.println("p: dec -> " + String(p_prime.toString()) + "\n   hex -> " + convDec2HexBN(p_prime) + "\n");
        Serial.println("Sb: dec -> " + String(Sb.toString()) + "\n    hex -> " + convDec2HexBN(Sb) + "\n");
        Serial.println("Tb: dec -> " + String(Tb.toString()) + "\n    hex -> " + convDec2HexBN(Tb) + "\n");
        Serial.println("DH KEY: dec -> " + String(dh_key.toString()) + "\n        hex -> " + convDec2HexBN(dh_key) + "\n");

        calcolatoChiave = true;

      }
    }

    // send out any outstanding data
    ble_do_events();
    buf_len = 0;

    return; // only do this task in this loop
  }


  // eseguo il seguente codice se non ci sono dati 
  // disponibili nel buffer di lettura BLE

  // process text data
  if (Serial.available())
  {
    byte d = 'Z';
    ble_write(d);

    delay(5);
    while (Serial.available())
    {
      d = Serial.read();
      ble_write(d);
    }

    ble_do_events();
    buf_len = 0;

    return;
  }

  // No input data, no commands, process analog data
  if (!ble_connected())
    queryDone = false; // reset query state

  if (queryDone) // only report data after the query state
  {
    byte input_data_pending = reportDigitalInput();
    if (input_data_pending)
    {
      ble_do_events();
      buf_len = 0;

      return; // only do this task in this loop
    }

    reportPinAnalogData();

    ble_do_events();
    buf_len = 0;

    return;
  }

  ble_do_events();
  buf_len = 0;
  
} // end loop


// restituisce un array di char casuali
char *randomCharArray(char *strMaxNumber)
{
  //int randomCharArrayLength = (rand()%strlen(strMaxNumber))+2; //+2 = +1 (to get length 1..strlen(s)) + 1(for '\0')
  int randomCharArrayLength = random(1, strlen(strMaxNumber) + 1) + 1;
  // 1 means that both s and r have same digit in the same position (starting from left).
  // This means we cannot generate random digit from 0 to 9, we have to generate from 0 to s[i]
  int critical = ((randomCharArrayLength - 1) == strlen(strMaxNumber)) ? 1 : 0; //If same lenght, then there's of course critical on first digit (from left)

  //String that contains randomNumber generated
  char *r = (char*)malloc(randomCharArrayLength * (sizeof(char)));

  printf("\n----------- [DEBUG] randomCharArray() ----------\n");
  printf("\tLength s:  %lu\n", strlen(strMaxNumber));
  printf("\tLength r:  %d\n", randomCharArrayLength - 1);
  printf("\tCritical:  %d\n", critical);

  //for (int i = 0; i < strlen(strMaxNumber); i++)
  for (int i = 0; i < randomCharArrayLength - 1; i++)
  {
    int lm = strMaxNumber[i] - '0';
    if (critical)
    {
      //r[i] = (rand()%(lm+1)) + '0';
      r[i] = random(0, lm + 1) + '0';
      critical = (r[i] == strMaxNumber[i]) ? 1 : 0;
    }
    else
    {
      //r[i] = (rand()%10) + '0';
      r[i] = random(0, 10) + '0';
    }
  }
  r[randomCharArrayLength - 1] = '\0';

  printf("\tRandom Number: %s\n", r);
  printf("---------------------------------------------------\n\n");

  if (atoi(r) == 0) //If we get 0 as random number we try again
  {
    printf("[ATTENTION] Random generated number is zero -> Computing Again!\n");
    free(r);    //The number we generated is useless since it is 0, so we delete the memory allocated
    return randomCharArray(strMaxNumber);   //Compute another random number
  }

  return r;
}

char *getStrNumberWithoutLeadingZeros(char *strNumber)
{
  int posOfLastLeadingZero = getLastLeadingZeroPosition(strNumber);
  int lengthPurgedString = (strlen(strNumber) - posOfLastLeadingZero);
  char *purgedString;
  int i;

  if (posOfLastLeadingZero == -1) //It means that the first char of strNumber is !=0 -> no leading zero to remove
    return strNumber;

  purgedString = (char*)malloc(lengthPurgedString * (sizeof(char)));

  for (i = 0; i < lengthPurgedString - 1; i++)
    purgedString[i] = strNumber[i + posOfLastLeadingZero + 1];

  printf("\n---- [DEBUG] getStrNumberWithoutLeadingZeros() ----\n");
  printf("\tLength STR Random Bignum (NOT PURGED): %lu\n", strlen(strNumber));
  printf("\tLast Leading Zero Position: %d\n", posOfLastLeadingZero);
  printf("\tLength of Purged String: %d\n", lengthPurgedString - 1);
  printf("---------------------------------------------------\n\n");


  purgedString[lengthPurgedString - 1] = '\0';
  return purgedString;
}

int getLastLeadingZeroPosition(char *strNumber)
{
  int posFound = -1;
  int i = 0;

  if (strNumber[0] != '0') //If first digit is not zero, it means there's no leading zeros to remove
    return posFound;
  else
    posFound = 0;

  for (i = 1; i < strlen(strNumber); i++)
  {
    if (strNumber[i] == '0' && strNumber[i - 1] == '0')
      posFound = i;
    else
      return posFound;    //Series of leading zeros has been interrupted -> we do not want to check further!
  }

  //Should exit here only if strNumber is all 0
  return posFound;
}






// ------------------- NON TOCCARE!! --------------------


void ble_write_string(byte *bytes, uint8_t len)
{
  if (buf_len + len > 20)
  {
    for (int j = 0; j < 15000; j++)
      ble_do_events();

    buf_len = 0;
  }

  for (int j = 0; j < len; j++)
  {
    ble_write(bytes[j]);
    buf_len++;
  }

  if (buf_len == 20)
  {
    for (int j = 0; j < 15000; j++)
      ble_do_events();

    buf_len = 0;
  }
}

byte reportDigitalInput()
{
  if (!ble_connected())
    return 0;

  static byte pin = 0;
  byte report = 0;

  if (!IS_PIN_DIGITAL(pin))
  {
    pin++;
    if (pin >= TOTAL_PINS)
      pin = 0;
    return 0;
  }

  if (pin_mode[pin] == INPUT)
  {
    byte current_state = digitalRead(pin);

    if (pin_state[pin] != current_state)
    {
      pin_state[pin] = current_state;
      byte buf[] = {'G', pin, INPUT, current_state};
      ble_write_string(buf, 4);

      report = 1;
    }
  }

  pin++;
  if (pin >= TOTAL_PINS)
    pin = 0;

  return report;
}

void reportPinCapability(byte pin)
{
  byte buf[] = {'P', pin, 0x00};
  byte pin_cap = 0;

  if (IS_PIN_DIGITAL(pin))
    pin_cap |= PIN_CAPABILITY_DIGITAL;

  if (IS_PIN_ANALOG(pin))
    pin_cap |= PIN_CAPABILITY_ANALOG;

  if (IS_PIN_PWM(pin))
    pin_cap |= PIN_CAPABILITY_PWM;

  if (IS_PIN_SERVO(pin))
    pin_cap |= PIN_CAPABILITY_SERVO;

  buf[2] = pin_cap;
  ble_write_string(buf, 3);
}

void reportPinServoData(byte pin)
{
  //  if (IS_PIN_SERVO(pin))
  //    servos[PIN_TO_SERVO(pin)].write(value);
  //  pin_servo[pin] = value;

  byte value = pin_servo[pin];
  byte mode = pin_mode[pin];
  byte buf[] = {'G', pin, mode, value};
  ble_write_string(buf, 4);
}

byte reportPinAnalogData()
{
  if (!ble_connected())
    return 0;

  static byte pin = 0;
  byte report = 0;

  if (!IS_PIN_DIGITAL(pin))
  {
    pin++;
    if (pin >= TOTAL_PINS)
      pin = 0;
    return 0;
  }

  if (pin_mode[pin] == ANALOG)
  {
    uint16_t value = analogRead(pin);
    byte value_lo = value;
    byte value_hi = value >> 8;

    byte mode = pin_mode[pin];
    mode = (value_hi << 4) | mode;

    byte buf[] = {'G', pin, mode, value_lo};
    ble_write_string(buf, 4);
  }

  pin++;
  if (pin >= TOTAL_PINS)
    pin = 0;

  return report;
}

void reportPinDigitalData(byte pin)
{
  byte state = digitalRead(pin);
  byte mode = pin_mode[pin];
  byte buf[] = {'G', pin, mode, state};
  ble_write_string(buf, 4);
}

void reportPinPWMData(byte pin)
{
  byte value = pin_pwm[pin];
  byte mode = pin_mode[pin];
  byte buf[] = {'G', pin, mode, value};
  ble_write_string(buf, 4);
}

void sendCustomData(uint8_t *buf, uint8_t len)
{
  uint8_t data[20] = "Z";
  memcpy(&data[1], buf, len);
  ble_write_string(data, len + 1);
}

