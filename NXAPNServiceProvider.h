//
//  NXAPNServiceProvider.h
//
//  Created by Raphael Bartolome on 12.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NXAPNSNotification;

typedef void (^NXAPNSProviderCleanup)();
typedef void (^NXAPNSFeedbackDropToken)(NSTimeInterval timeIntervalSince1970, NSString *deviceToken);

@interface NXAPNServiceProvider : NSObject 

+ (NSString *)deviceTokenToString: (NSData *)deviceToken;

- (id)initWithCertificate: (NSString *)certPath 
           keyPEMFilePath: (NSString *)keyPath 
                 password: (NSString *)password
                  sandbox: (BOOL)sanbox;

- (BOOL)open;
- (BOOL)close: (NXAPNSProviderCleanup)block;
- (BOOL)pushNotification: (NXAPNSNotification *)apn deviceToken: (NSString *)token;
- (BOOL)pushTextMessage: (NSString *)text deviceToken: (NSString *)token;

- (void)checkServiceFeedback: (NXAPNSFeedbackDropToken)block;

@end



@interface NXAPNSNotification : NSObject

@property(nonatomic, strong) NSString *alertMessage;
@property(atomic) NSInteger badgeCount;
@property(nonatomic, strong) NSString *soundFile;
@property(nonatomic, strong) NSString *acme1;
@property(atomic) NSInteger acme2;

+ (NXAPNSNotification *)notificationWithMessage: (NSString *)message;

- (void)setAlertMessageWithBody: (NSString *)body 
                   actionLocKey: (NSString *)actionKey
                         locKey: (NSString *)locKey
                locKeyArguments: (NSString *)locKeyArgs
                    launchImage: (NSString *)launchImage;

- (NSString *)serialized;

@end