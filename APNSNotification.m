//
//  APNSNotification.m
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import "APNSNotification.h"


@implementation APNSNotification

- (void)setAPSAsJSON:(NSString *)json;
{
    [_aps release];
    _aps = [json copy];
}

- (id)initWithDeviceToken:(NSString *)token;
{
    if((self = [super init]))
    {
        _payload = [[NSMutableDictionary alloc] initWithCapacity:0];
        _token = [token copy];
    }
    return self;
}

+ (id)notificationWithDeviceToken:(NSString *)token;
{
    APNSNotification *notification = [[APNSNotification alloc] initWithDeviceToken:token];
    return [notification autorelease];
}

+ (id)notificationWithDeviceToken:(NSString *)token json:(NSString *)aps;
{
    APNSNotification *notification = [[APNSNotification alloc] initWithDeviceToken:token];
    [notification setAPSAsJSON:aps];
    return [notification autorelease];
}

- (NSString *)deviceToken;
{
    return _token;
}

- (NSString *)notification;
{
    if(!_aps)
        [self setAPSAsJSON:[[NSDictionary dictionaryWithObject:_payload forKey:@"aps"] JSONString]];
    
    return _aps;
}

- (void)setCustom:(id)value forKey:(NSString *)key;
{
    [_payload setObject:value forKey:key];
}

- (void)setAlertBody:(NSString *)body 
           actionKey:(NSString *)actionKey 
                 key:(NSString *)key 
                args:(NSArray *)args 
         launchImage:(NSString *)launchImage;
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    
    if(body)
        [dict setObject:body forKey:@"body"];
    
    if(actionKey)
        [dict setObject:actionKey forKey:@"action-loc-key"];
    else
        [dict setObject:[NSNull null] forKey:@"action-loc-key"];
    
    if(key)
        [dict setObject:key forKey:@"loc-key"];
    
    if(args)
        [dict setObject:args forKey:@"loc-args"];
    
    if(launchImage)
        [dict setObject:launchImage forKey:@"launch-image"];
    
    [self setCustom:dict forKey:@"alert"];
}

- (void)setAlert:(NSString *)msg;
{
    [self setCustom:msg forKey:@"alert"];
}

- (void)setBadge:(NSInteger)count;
{
    [self setCustom:[NSNumber numberWithInteger:count] forKey:@"badge"];    
}

- (void)setSound:(NSString *)sound;
{
    [self setCustom:sound forKey:@"sound"];
}

- (void)setAcme1:(id)acme;
{
    [self setCustom:acme forKey:@"acme1"];
}

- (void)setAcme2:(id)acme;
{
    [self setCustom:acme forKey:@"acme2"];
}


- (void)dealloc
{
    [_aps release];
    [_token release];
    [_payload release];
    
    [super dealloc];
}
@end

