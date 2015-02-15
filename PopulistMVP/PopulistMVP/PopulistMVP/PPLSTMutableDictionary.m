//
//  PPLSTMutableDictionary.m
//  PopulistMVP
//
//  Created by Pontus Ahlqvist on 2/13/15.
//  Copyright (c) 2015 PontusAhlqvist. All rights reserved.
//

#import "PPLSTMutableDictionary.h"

@interface PPLSTMutableDictionary()
@property(strong, nonatomic) NSMutableDictionary *dictionary;
@property(strong, nonatomic) NSMutableArray *keysArray; //keeps track of the keys in the order they have been added to allow for a FIFO memory reduced data structure
@property(strong, nonatomic) NSMutableSet *keysSet;
@end

@implementation PPLSTMutableDictionary

int maxCapacity = 100; //TODO: setting this to 1 doesn't seem to free up any memory. Why? Is there something about JSQ going on here?

-(NSMutableDictionary *)dictionary{
    if(!_dictionary) _dictionary = [[NSMutableDictionary alloc] init];
    return _dictionary;
}

-(NSMutableArray *)keysArray{
    if(!_keysArray) _keysArray = [[NSMutableArray alloc] init];
    return _keysArray;
}
-(NSMutableSet *)keysSet{
    if(!_keysSet) _keysSet = [[NSMutableSet alloc] init];
    return _keysSet;
}

-(void)removeObjectForKey:(id)aKey{
    [self.dictionary removeObjectForKey:aKey];
}

-(id)objectForKey:(id)aKey{
    return [self.dictionary objectForKey:aKey];
}

-(NSUInteger)count{
    return [self.dictionary count];
}

-(NSArray *)allKeys{
    return [self.dictionary allKeys];
}

-(void) removeAllObjects{
    [self.dictionary removeAllObjects];
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key{
    return self.dictionary[key];
}

-(void)setObject:(id)object forKey:(id)aKey{
    [self prepareDictionaryForInsertWithKey:aKey];
    [self.dictionary setObject:object forKey:aKey];
}

- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)aKey{
    [self prepareDictionaryForInsertWithKey:aKey];
    [self.dictionary setObject:object forKeyedSubscript:aKey];
}

//this method checks to see if we're at our limit and if so which key we should remove (or if we even need to remove a key)
-(void) prepareDictionaryForInsertWithKey:(id)key{
    NSLog(@"PPLST prepareDictionaryForInsertWithKey:%@",key);
    NSLog(@"self.keysSet = %@", self.keysSet);
    NSLog(@"[self.keysArray count] = %lu. Max = %i", (long)[self.keysArray count], maxCapacity);
    if(![self.keysSet containsObject:key]){
        [self.keysSet addObject:key];
        [self.keysArray addObject:key];
        if([self.keysArray count] > maxCapacity){
            NSLog(@"before - counts: %lu, %lu, %lu", (long)[self count], (long)[self.keysSet count], (long)[self.keysArray count]);
            NSString *keyToRemove = self.keysArray[0];
            [self removeObjectForKey:keyToRemove];
            [self.keysArray removeObjectAtIndex:0];
            [self.keysSet removeObject:keyToRemove];
            NSLog(@"after - counts: %lu, %lu, %lu", (long)[self count], (long)[self.keysSet count], (long)[self.keysArray count]);
        }
    }
    NSLog(@"PPLST prepareDictionaryForInsertWithKey - done");
}

@end
