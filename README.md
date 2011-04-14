## Example ##

	/*
		APNSNotification makes use of JSONKit (https://github.com/johnezang/JSONKit) to create the JSON aps string.
		But you can also use sendNotification:deviceToken: without APNSNotification.
		The Notification must be a aps json formatted string.
	*/
	
	APNSConnection *connection = [[APNSConnection alloc] initWithCertificate:@"/path/to/apns_cert.pem" 
	                                                          keyPEMFilePath:@"/path/to/apns_key.pem" 
	                                                                password:@"my apns passwd"
	                                                                 sandbox:YES];

	[connection connect];

	APNSNotification *apn = [[APNSNotification notificationWithDeviceToken:@"4a8e6c8f 4a8e6c8f ..."] retain];

	[apn setAlert:@"I have a message for you"];	//for more see setAlertBody: ...
	[apn setBadge:1];
	[apn setSound:@"beep.wav"];
	[apn setAcme1:@"bar"];
	[apn setAcme2:[NSNumber numberWithInteger:42]];

	[connection sendNotification:[apn notification] deviceToken:[apn deviceToken]];
	[apn release];

	[connection disconnect];

	[connection release];