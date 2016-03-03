//
//  AppDelegate.m
//  SimpleControls
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#import "AppDelegate.h"

static NSString * NAME_FINISH_SCAN = @"FinishScanPeripherals";


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    // react to shortcut item selections
    //NSLog(@"A shortcut item was pressed. It was %@.", shortcutItem.localizedTitle);
    
    // elimina gli observer, quelli che servono li riaggiungo in seguito
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ([shortcutItem.type isEqualToString:@"startDH"])
    {
        // aggiunge l'observer che si occupa di avviare DH non appena la scansione BLE e' terminata
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFinishScan:) name:NAME_FINISH_SCAN object:nil];
    }
    
    // mostra la view principale
    [self launchViewController];
    
    // necessario per la corretta inizializzazione dell'oggetto ble
    [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(scanForPeripherals) userInfo:nil repeats:NO];
    
}

/**
* Carica la vista principale quando l'utente ha usato una shortcut 3D touch
*/
- (void)launchViewController
{
    // grab our storyboard
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    
    // and instantiate our navigation controller
    controller = [storyboard instantiateViewControllerWithIdentifier:@"MainView"];
    
    // make it the key window
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
}

/**
* Invoca il metodo per cercare dispositivi BLE nei dintorni
*/
- (void)scanForPeripherals
{
    [controller btnScanForPeripherals:nil];
}

/**
* Invoca i metodi per generare i parametri DH e avviare il calcolo della chiave
*/
- (void)runDiffieHellman
{
    [controller generateDHParams:nil];
    [controller startDHWithShortcut];
}

/**
* Gestisce la notifica che viene lanciata quando l'iphone termina con successo 
* la fase di ricerca di un dispositivo BLE
*/
- (void)handleFinishScan:(NSNotification*)note
{
    [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(runDiffieHellman) userInfo:nil repeats:NO];
}

@end
