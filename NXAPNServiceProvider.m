//
//  NXAPNService.m
//
//  Created by Raphael Bartolome on 12.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import "NXAPNServiceProvider.h"

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


@implementation NXAPNSNotification

@synthesize alertMessage;
@synthesize badgeCount;
@synthesize soundFile;
@synthesize acme1;
@synthesize acme2;

+ (NXAPNSNotification *)notificationWithMessage: (NSString *)message;
{
    NXAPNSNotification *nof = [NXAPNSNotification new];
    [nof setAlertMessage: message];
    
    return nof;
}

- (void)setAlertMessage:(NSString *)alertMsg;
{
    alertMessage = [[NSString stringWithFormat:@"\"%@\"", alertMsg] copy];
}

- (void)setAlertMessageWithBody: (NSString *)body 
                   actionLocKey: (NSString *)actionKey
                         locKey: (NSString *)locKey
                locKeyArguments: (NSString *)locKeyArgs
                    launchImage: (NSString *)launchImage;
{    
    alertMessage = [[NSString stringWithFormat: @"{\"body\" : \"%@\", \"action-loc-key\" : \"%@\", \"loc-key\" : \"%@\", \"loc-args\" : \"%@\", \"launch-image\" : \"%@\"}", body, actionKey, locKey, locKeyArgs, launchImage] copy];
}

- (NSString *)serialized;
{
    return [NSString stringWithFormat: @"{ \"aps\": {  \"alert\" : %@, \"badge\" : %i,  \"sound\" : \"%@\"}, \"acme1\" : \"%@\", \"acme2\" : %i }", alertMessage ? alertMessage : @"You got a new Message", badgeCount ? badgeCount : 0, soundFile ? soundFile : @"", acme1 ? acme1 : @"", acme2 ? acme2 : 42];
}

@end


@interface NXAPNSConnection : NSObject
{
    SSL_CTX         *_ssl_context;
    SSL             *_ssl;
    
    struct sockaddr_in   _server_addr;
    struct hostent      *_host_nfo;
    int                  _socket;
}

- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                     port: (int)port
                      url: (const char *)url;

- (SSL *)ssl;
- (void)safeClose;

@end



@implementation NXAPNServiceProvider
{
@private
    dispatch_queue_t _gatewayQueue;
    dispatch_queue_t _feedbackQueue;
    
    BOOL _sandbox;
    NSInteger _port;
    NSString *_host;
    NSString *_path;
    NSString *_certPath;
    NSString *_keyPath;
    NSString *_password;
    
    NXAPNSConnection *_gatewayConnection;
    NXAPNSConnection *_feedbackConnection;

    NXAPNSFeedbackDropToken _feedbackBlock;
    
    BOOL _closed;
}

+ (NSString *)deviceTokenToString: (NSData *)deviceToken;
{
    NSString *tmpToken = [NSString stringWithFormat:@"%@", deviceToken];
    NSUInteger loc_begin = [tmpToken rangeOfString: @"<"].location+1;
    NSUInteger loc_end = [tmpToken rangeOfString: @">"].location-1;
    return [tmpToken substringWithRange: NSMakeRange(loc_begin, loc_end)];
}

- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                  sandbox:(BOOL)sanbox;
{
    if((self = [super init]))
    {
        _closed = NO;
        _gatewayQueue = dispatch_queue_create("com.nexttap.NXAPNSGatewayQueue", DISPATCH_QUEUE_SERIAL);
        _feedbackQueue = dispatch_queue_create("com.nexttap.NXAPNSFeedbackQueue", DISPATCH_QUEUE_SERIAL);
        
        _certPath = [certPath copy];
        _keyPath = [keyPath copy];
        _path = [[keyPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"/%@",[_keyPath lastPathComponent]] 
													withString:@""] copy];
        _password = [password copy];
        _sandbox = sanbox;
    }
    
    return self;
}

- (void)dealloc;
{
    [self close:^{
    }];
    
    dispatch_sync(_gatewayQueue, ^{
        
    });

    dispatch_release(_gatewayQueue);
    dispatch_release(_feedbackQueue);
}

- (NSString *)password;
{
    return _password;
}


#pragma mark - APNS Feedback
- (void)checkServiceFeedback: (NXAPNSFeedbackDropToken)block;
{
    _feedbackBlock = [block copy];
    
    if(!_feedbackConnection)
        _feedbackConnection = [[NXAPNSConnection alloc] initWithCertificate: _certPath 
                                                            keyPEMFilePath: _keyPath 
                                                                  password: _password 
                                                                      port: _sandbox ? APPLE_SANDBOX_FEEDBACK_PORT : APPLE_FEEDBACK_PORT 
                                                                       url: _sandbox ? APPLE_SANDBOX_FEEDBACK_HOST : APPLE_FEEDBACK_HOST];
    
    dispatch_async(_feedbackQueue, ^{
        
        char feedback[39];
        NSMutableData *feedbackData = [NSMutableData new];

        if(SSL_pending([_feedbackConnection ssl]) <= 0)
           NSLog(@"APNS Server has no pending data");
        
        while (SSL_pending([_feedbackConnection ssl]) > 0)
        {
            int bytesLength = SSL_read([_feedbackConnection ssl], feedback, 39);
            [feedbackData appendBytes: feedback length: bytesLength];
            
            while ([feedbackData length] > 38)
            {
                NSData *deviceToken = [NSData dataWithBytes: [feedbackData bytes] + 6 length: 32];                
                _feedbackBlock(0, [NXAPNServiceProvider deviceTokenToString: deviceToken]);
                
                [feedbackData replaceBytesInRange: NSMakeRange(0, 38) withBytes: "" length: 0];
            }
        }
    });
}

#pragma mark - APNS Gateway
- (BOOL)open;
{
    if(!_gatewayConnection)
        _gatewayConnection = [[NXAPNSConnection alloc] initWithCertificate: _certPath 
                                                           keyPEMFilePath: _keyPath 
                                                                 password: _password 
                                                                     port: _sandbox ? APPLE_SANDBOX_PORT : APPLE_PORT 
                                                                      url: _sandbox ? APPLE_SANDBOX_HOST : APPLE_HOST];
    
    if(_gatewayConnection)
        return YES;


    return NO;
}

- (BOOL)close: (NXAPNSProviderCleanup)block;
{
    NXAPNSProviderCleanup _block = [block copy];
    _closed = YES;

    dispatch_async(_gatewayQueue, ^{
        
        if(_gatewayConnection)
        {
            [_gatewayConnection safeClose];
            _gatewayConnection = nil;
        }
        
        if(_feedbackConnection)
        {
            [_feedbackConnection safeClose];
            _feedbackConnection = nil;
        }
        
        _block();
    });

    
    return YES;
}

- (BOOL)pushTextMessage:(NSString *)text deviceToken:(NSString *)token;
{
    NXAPNSNotification *nof = [NXAPNSNotification notificationWithMessage: text];
    
    return [self pushNotification: nof 
                      deviceToken: token];
}

- (BOOL)pushNotification:(NXAPNSNotification *)apno deviceToken:(NSString *)token;
{
    __block NSString *apn = [apno serialized];

    if(_closed)
        return NO;
    
    if(!_gatewayConnection)
        [self open];
        
    dispatch_async(_gatewayQueue, ^{

        NSMutableData *deviceToken = [NSMutableData data];
        unsigned value;
        NSScanner *scanner = [NSScanner scannerWithString:token];
        while(![scanner isAtEnd]) 
        {
            [scanner scanHexInt:&value];
            value = htonl(value);
            [deviceToken appendBytes:&value length:sizeof(value)];
        }
        
        char *deviceTokenBinary = (char *)[deviceToken bytes];
        char *payloadBinary = (char *)[apn UTF8String];
        size_t payloadLength = strlen(payloadBinary);
        
        uint8_t command = 0;
        char message[293];
        char *pointer = message;
        uint16_t networkTokenLength = htons(32);
        uint16_t networkPayloadLength = htons(payloadLength);
        
        memcpy(pointer, &command, sizeof(uint8_t));
        pointer += sizeof(uint8_t);
        memcpy(pointer, &networkTokenLength, sizeof(uint16_t));
        pointer += sizeof(uint16_t);
        memcpy(pointer, deviceTokenBinary, 32);
        pointer += 32;
        memcpy(pointer, &networkPayloadLength, sizeof(uint16_t));
        pointer += sizeof(uint16_t);
        memcpy(pointer, payloadBinary, payloadLength);
        pointer += payloadLength;
        
        if (SSL_write([_gatewayConnection ssl], &message, (int)(pointer - message)) <= 0)
        {
            NSLog(@"Unable to push notification");
        } 
    });
    
    return YES;
}


@end


@implementation NXAPNSConnection

- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                     port: (int)port
                      url: (const char *)url
{
    if((self = [super init]))
    {
        int err;
        
        /* init SSL */
        SSL_library_init();
        SSL_load_error_strings();
        
        /* Create an SSL context*/
        _ssl_context = SSL_CTX_new(SSLv3_method());                        
        if(!_ssl_context)
        {
            NSLog(@"Create SSL Context failed");
            return nil;
        }
        
        /* Load the CA from Path */
        if(SSL_CTX_load_verify_locations(_ssl_context, NULL, [[keyPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"/%@", [keyPath lastPathComponent]] 
                                                                                                 withString:@""] UTF8String]) <= 0)
        {
            /* Handle failed load here */
            NSLog(@"Failed to set CA location");
            ERR_print_errors_fp(stderr);
            return nil;
        }
        
        /* Load the client certificate into the SSL context */
        if (SSL_CTX_use_certificate_file(_ssl_context, [certPath UTF8String], SSL_FILETYPE_PEM) <= 0) {
            NSLog(@"Using Certificate File failed");
            ERR_print_errors_fp(stderr);
            return nil;
        }
        
        SSL_CTX_set_default_passwd_cb_userdata(_ssl_context, (void *)[password UTF8String]);
        
        /* Load the private-key corresponding to the client certificate */
        if (SSL_CTX_use_PrivateKey_file(_ssl_context, [keyPath UTF8String], SSL_FILETYPE_PEM) <= 0) {
            NSLog(@"Using Private Key failed");
            ERR_print_errors_fp(stderr);
            return nil;
        }
        
        /* Check if the client certificate and private-key matches */
        if (!SSL_CTX_check_private_key(_ssl_context)) {
            NSLog(@"Private key does not match");
            return nil;
        }
        
        /* Set up a TCP socket */
        _socket = socket (PF_INET, SOCK_STREAM, IPPROTO_TCP);       
        if(_socket == -1)
        {
            NSLog(@"Get Socket failed");
            return nil;
        }
        
        
        memset(&_server_addr, '\0', sizeof(_server_addr));
        _server_addr.sin_family      = AF_INET;
        _server_addr.sin_port        = htons(port);
        _host_nfo = gethostbyname(url);
        
        if(_host_nfo)
        {
            struct in_addr *address = (struct in_addr*)_host_nfo->h_addr_list[0];
            _server_addr.sin_addr.s_addr = inet_addr(inet_ntoa(*address));
        }
        else
        {
            NSLog(@"Could not resolve hostname %@", url);
        }
        
        err = connect(_socket, (struct sockaddr*) &_server_addr, sizeof(_server_addr)); 
        if(err == -1)
        {
            NSLog(@"Could not connect");
            return nil;
        }    
        
        _ssl = SSL_new(_ssl_context);
        if(!_ssl)
        {
            NSLog(@"Get SSL Socket failed");
            return nil;
        }    
        
        SSL_set_fd(_ssl, _socket);
        
        err = SSL_connect(_ssl);
        if(err == -1)
        {
            NSLog(@"SSL Server connection failed");
            return nil;
        }        
    }
    
    return self; 
}


- (SSL *)ssl;
{
    return _ssl;
}

- (void)safeClose;
{
    int err;
    
    err = SSL_shutdown(_ssl);
    if(err == -1)
    {
        NSLog(@"Shutdown SSL failed");
    }    
    
    err = close(_socket);
    if(err == -1)
    {
        NSLog(@"Close socket failed");
    }    
    
    _socket = -1;
    
    if(err >= 0)
    {
        SSL_free(_ssl);    
        SSL_CTX_free(_ssl_context); 
    }
}

- (void)dealloc;
{
    if(_socket != -1)
        [self safeClose];
}

@end

