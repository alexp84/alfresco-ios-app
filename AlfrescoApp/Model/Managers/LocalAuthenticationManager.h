//
//  LocalAuthenticationManager.h
//  AlfrescoApp
//
//  Created by Alexandru Posmangiu on 16/12/15.
//  Copyright © 2015 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^LocalAuthenticationCompletionBlock)(BOOL success, NSError *error);

@interface LocalAuthenticationManager : NSObject

+ (LocalAuthenticationManager *) sharedManager;

/**
 *  Authenticates the user in order to delete an account. It's designed to use Touch ID to localy authenticate the iDevice owner. If the device doesn't have Touch ID, or no fingers are added in Settings, a fallback mechanism is triggered. The fallback mechanism consists in an alert prompt asking for the password of the account that should be deleted. If Touch ID is supported and used, in case of errors validating fingers, the user may choose to use the fallback mechanism.
 *
 *  @param account         The account that the user wants to delete.
 *  @param completionBlock The completion block to be executed after.
 */
- (void) authenticateForAccount:(UserAccount *)account
                completionBlock:(LocalAuthenticationCompletionBlock)completionBlock;

@end