//
//  NXAPNService.h
//
//  Created by Raphael Bartolome on 12.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>


/* Development Connection Infos */
#define APPLE_SANDBOX_HOST          "gateway.sandbox.push.apple.com"
#define APPLE_SANDBOX_PORT          2195

#define APPLE_SANDBOX_FEEDBACK_HOST "feedback.sandbox.push.apple.com"
#define APPLE_SANDBOX_FEEDBACK_PORT 2196

/* Release Connection Infos */
#define APPLE_HOST          		"gateway.push.apple.com"
#define APPLE_PORT         			 2195

#define APPLE_FEEDBACK_HOST 		"feedback.push.apple.com"
#define APPLE_FEEDBACK_PORT 		2196


#define DEVICE_BINARY_SIZE  		32
#define MAX_PAYLOAD_SIZE     		256


@interface NXAPNServiceProvider : NSObject 


- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                  sandbox:(BOOL)sanbox;

- (BOOL)open;
- (BOOL)close;
- (BOOL)pushNotification:(NSString *)apn deviceToken:(NSString *)token;
- (BOOL)pushTextMessage:(NSString *)text deviceToken:(NSString *)token;

@end

@interface NXAPNNotification : NSObject

@property(nonatomic, strong) NSString *alertMessage;
@property(atomic) NSInteger badgeCount;
@property(nonatomic, strong) NSString *soundFile;
@property(nonatomic, strong) NSString *acme1;
@property(atomic) NSInteger acme2;

+ (NXAPNNotification *)notificationWithMessage: (NSString *)message;

- (void)setAlertMessageWithBody: (NSString *)body 
                   actionLocKey: (NSString *)actionKey
                         locKey: (NSString *)locKey
                locKeyArguments: (NSString *)locKeyArgs
                    launchImage: (NSString *)launchImage;

- (NSString *)serialized;

@end