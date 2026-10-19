//
//  JapaneseSettingsDataSource.h
//  jFlash
//
//  Created by Mark Makdad on 8/21/11.
//  Copyright 2011 Long Weekend LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SettingsViewController.h"

@interface JapaneseSettingsDataSource : NSObject <LWESettingsDataSource>

@property (retain) NSDictionary *settingsHash;
@property (retain) NSDictionary *settingsOrder;

@end
