# Network Security Project
### Università degli Studi di Brescia - AA 2015-2016


Running a Diffie-Hellman exchange for setup of an ephemeral key between iPhone and Arduino Due in order to achieve a ciphered connection using AES. 
The packets are exchanged via RedbearLab BLE Shield 2.1 using bluetooth low energy communication.

####Requirements
- Apple Xcode IDE v7.2
- Arduino IDE v1.6.7
- Apple device running iOS 9 or later (tested on iPhone 6)
- Arduino/Genuino Due
- RedbearLab BLE Shield v2.1

####How to Install
- Download GIT repo
- Unzip
- Move Arduino Libraries into your Arduino workspace library folder (default is ~/Documents/Arduino/libraries)
- Move Arduino Project into Arduino workspace (default is ~/Documents/Arduino/)
- Build and Upload it onto your Arduino. (Check that Serial Monitor baud is set to 57600)
- Open Xcode project
- Check that there is iPhone as Target of you build. If not, go to Product > Scheme > Edit Scheme.
  Choose the "Run" tab on the left and set the "Executable" dropdown field to "ArduinoBLE.app"
- Build the project 
- Run it on your iDevice (If a popup concerning security shows up, then you have to go to Settings > Generals > Profiles and 
  authorize it).

<hr>
*Authors: Davide Sansoni, Emanuele Trivella* <br>
*License: http://creativecommons.org/licenses/by-nc/4.0/* <br>
*Further informations (in Italian) can be found inside the relation of the project.*
