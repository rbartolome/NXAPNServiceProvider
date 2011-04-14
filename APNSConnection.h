//
//  APNSConnection.h
//
//  Created by Raphael Bartolome on 12.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <openssl/crypto.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <netdb.h>
#include <unistd.h>

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


@interface APNSConnection : NSObject 
{
@private
    NSOperationQueue *notificationQueue;

    BOOL _sandbox;
    NSInteger _port;
    NSString *_host;
    NSString *_path;
    NSString *_certPath;
    NSString *_keyPath;
    NSString *_password;
    
    SSL_CTX         *_ssl_context;
    SSL             *_ssl;
    
    struct sockaddr_in   _server_addr;
    struct hostent      *_host_nfo;
    int                  _socket;    
}

- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                  sandbox:(BOOL)sanbox;


- (BOOL)connect;
- (BOOL)disconnect;
- (void)sendNotification:(NSString *)apn deviceToken:(NSString *)token;

@end