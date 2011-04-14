//
//  APNSNotification.h
//
//  Created by Raphael Bartolome on 14.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSONKit.h"

@interface APNSNotification : NSObject
{
@private
    NSString *_aps;
    NSString *_token;
    NSMutableDictionary *_payload;
}

+ (id)notificationWithDeviceToken:(NSString *)token;
+ (id)notificationWithDeviceToken:(NSString *)token json:(NSString *)aps;

- (NSString *)deviceToken;
- (NSString *)notification;

- (void)setCustom:(id)value forKey:(NSString *)key;
- (void)setAlertBody:(NSString *)body 
           actionKey:(NSString *)actionKey 
                 key:(NSString *)key 
                args:(NSArray *)args 
         launchImage:(NSString *)launchImage;
- (void)setAlert:(NSString *)msg;
- (void)setBadge:(NSInteger)count;
- (void)setSound:(NSString *)sound;
- (void)setAcme1:(id)acme;
- (void)setAcme2:(id)acme;

@end
