//
//  AppDelegate.h
//  SimpleControl
//
//  Copyright Davide Sansoni, Emanuele Trivella (c)
//

#import <UIKit/UIKit.h>
#import "TableViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    TableViewController *controller;
}

@property (strong, nonatomic) UIWindow *window;

@end
