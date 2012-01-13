This Project is ARC enabled and based on OpenSSL

How to build a static openssl library for iOS and Mac OS
	https://github.com/sjlombardo/openssl-xcode
	
More Informations about Apple Push Service
	http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ApplePushService/ApplePushService.html


## Example ##

	NXAPNServiceProvider *connection = [[NXAPNServiceProvider alloc] initWithCertificate: @"/path/to/apns_cert.pem" 
	                                                          			  keyPEMFilePath: @"/path/to/apns_key.pem" 
	                                                              				password: @"my apns passwd"
																				 sandbox: YES];

	[apns pushTextMessage: @"Test Text Message" 
			  deviceToken: @"4a8e6c8f 4a8e6c8f ..."];


	//Or use NXAPNotification
	NXAPNNotification *notification = [NXAPNNotification new];

	//Default Text Message
	[notification setAlertMessage: @"I have a message for you"];
	//Or use
    [notification setAlertMessageWithBody: @"I have a message for you body"
                             actionLocKey: @"The Slider Value" 
                                   locKey: @"LocalizableKey" 
                          locKeyArguments: @"my argument" 
                              launchImage: @"image_.png"];
							  
	//Optional call
	[notification setBadgeCount :1];
	[notification setSoundFile: @"beep.wav"];
	[notification setAcme1:@"bar"];
	[notification setAcme2: 42];
	
	[apns pushNotification: [notification serialized] 
			   deviceToken: @"4a8e6c8f 4a8e6c8f ..."];
	
	[connection close];