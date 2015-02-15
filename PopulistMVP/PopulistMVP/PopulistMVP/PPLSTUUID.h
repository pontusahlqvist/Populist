//
//  PPLSTUUID.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/15/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PPLSTUUID : NSObject

/**
 * Retrieve UUID from keychain, if one does not exist, generate one and store it in the keychain.
 * UUIDs stored in the keychain will perisist across application installs
 * but not across device restores.
 */
+ (NSString *)UUID;
/**
 * Remove stored UUID from keychain
 */
+ (void)reset;
/**
 * Getter/setter for access group used for reading/writing from keychain.
 * Useful for shared keychain access across applications with the
 * same bundle seed (requires properly configured provisioning and entitlements)
 */
+ (NSString *)accessGroup;
+ (void)setAccessGroup:(NSString *)accessGroup;

@end