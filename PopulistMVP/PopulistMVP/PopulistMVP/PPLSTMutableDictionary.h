//
//  PPLSTMutableDictionary.h
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/13/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

//This Mutable Array has a max limit. After this is reached, it dequeues the oldest elements

#import <Foundation/Foundation.h>

@interface PPLSTMutableDictionary : NSObject

- (void) setObject:(id)object forKey:(id)aKey;
- (void) removeObjectForKey:(id)aKey;
- (id) objectForKey:(id)aKey;
- (NSUInteger) count;
- (void) removeAllObjects;
- (NSArray*) allKeys;
- (id)objectForKeyedSubscript:(id <NSCopying>)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;

@end
