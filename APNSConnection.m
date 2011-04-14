//
//  APNSConnection.m
//
//  Created by Raphael Bartolome on 12.04.11.
//  Copyright 2011 Raphael Bartolome. All rights reserved.
//

#import "APNSConnection.h"

@implementation APNSConnection


- (id)initWithCertificate:(NSString *)certPath 
           keyPEMFilePath:(NSString *)keyPath 
                 password:(NSString *)password
                  sandbox:(BOOL)sanbox;
{
    if((self = [super init]))
    {

        _certPath = [certPath copy];
        _keyPath = [keyPath copy];
        _path = [[keyPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"/%@",[_keyPath lastPathComponent]] 
													withString:@""] retain];
        _password = [password copy];
        _sandbox = sanbox;
                
        notificationQueue = [[NSOperationQueue alloc] init];
        [notificationQueue setName:@"APNSQueue"];
        [notificationQueue setMaxConcurrentOperationCount:1];
    }

    return self;
}

- (NSString *)password;
{
    return _password;
}


- (BOOL)connect;
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
        return NO;
    }
    
    /* Load the CA from Path */
    if(SSL_CTX_load_verify_locations(_ssl_context, NULL, [_path UTF8String]) <= 0)
    {
        /* Handle failed load here */
        NSLog(@"Failed to set CA location");
        ERR_print_errors_fp(stderr);
        return NO;
    }
    
    /* Load the client certificate into the SSL context */
    if (SSL_CTX_use_certificate_file(_ssl_context, [_certPath UTF8String], SSL_FILETYPE_PEM) <= 0) {
        NSLog(@"Using Certificate File failed");
        ERR_print_errors_fp(stderr);
        return NO;
    }
    
    SSL_CTX_set_default_passwd_cb_userdata(_ssl_context, (void *)[[self password] UTF8String]);
    
    /* Load the private-key corresponding to the client certificate */
    if (SSL_CTX_use_PrivateKey_file(_ssl_context, [_keyPath UTF8String], SSL_FILETYPE_PEM) <= 0) {
        NSLog(@"Using Private Key failed");
        ERR_print_errors_fp(stderr);
        return NO;
    }
    
    /* Check if the client certificate and private-key matches */
    if (!SSL_CTX_check_private_key(_ssl_context)) {
        NSLog(@"Private key does not match");
        return NO;
    }
    
    /* Set up a TCP socket */
    _socket = socket (PF_INET, SOCK_STREAM, IPPROTO_TCP);       
    if(_socket == -1)
    {
        NSLog(@"Get Socket failed");
        return NO;
    }
    
    
    memset(&_server_addr, '\0', sizeof(_server_addr));
    _server_addr.sin_family      = AF_INET;
    _server_addr.sin_port        = htons(_sandbox ? APPLE_SANDBOX_PORT : APPLE_PORT);
    _host_nfo = gethostbyname(_sandbox ? APPLE_SANDBOX_HOST : APPLE_HOST);

    if(_host_nfo)
    {
        struct in_addr *address = (struct in_addr*)_host_nfo->h_addr_list[0];
        _server_addr.sin_addr.s_addr = inet_addr(inet_ntoa(*address));
    }
    else
    {
        NSLog(@"Could not resolve hostname %@", _host);
    }
    
    err = connect(_socket, (struct sockaddr*) &_server_addr, sizeof(_server_addr)); 
    if(err == -1)
    {
        NSLog(@"Could not connect");
        return NO;
    }    
    
    _ssl = SSL_new(_ssl_context);
    if(!_ssl)
    {
        NSLog(@"Get SSL Socket failed");
        return NO;
    }    
    
    SSL_set_fd(_ssl, _socket);
    
    err = SSL_connect(_ssl);
    if(err == -1)
    {
        NSLog(@"SSL Server connection failed");
        return NO;
    }

    return YES;
}

- (BOOL)disconnect;
{
	int err;
    [notificationQueue waitUntilAllOperationsAreFinished];
    
    err = SSL_shutdown(_ssl);
    if(err == -1)
    {
        NSLog(@"Shutdown SSL failed");
        return NO;
    }    
    
    err = close(_socket);
    if(err == -1)
    {
        NSLog(@"Close socket failed");
        return NO;
    }    
    
    SSL_free(_ssl);    
    SSL_CTX_free(_ssl_context);
    
    return YES;
}


- (void)sendNotification:(NSString *)apn deviceToken:(NSString *)token;
{
    NSBlockOperation *sendOperation =
        [NSBlockOperation blockOperationWithBlock:^{   
            
            [apn retain];
            [token retain];
            
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
            
            if (SSL_write(_ssl, &message, (int)(pointer - message)) <= 0)
            {
                NSLog(@"Unable to push notification");
            }
            
            [apn release];
            [token release];
    }];
    
    [notificationQueue addOperation:sendOperation]; 
}

- (void)dealloc
{
    [notificationQueue release];
    [_path release];
    [_certPath release];
    [_keyPath release];
    [_password release];
    
    [super dealloc];
}

@end


