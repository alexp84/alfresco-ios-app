//
//  LocalAuthenticationManager.m
//  AlfrescoApp
//
//  Created by Alexandru Posmangiu on 16/12/15.
//  Copyright © 2015 Alfresco. All rights reserved.
//

#import "LocalAuthenticationManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "AppDelegate.h"
#import "UserAccount.h"

@implementation LocalAuthenticationManager
{
    LocalAuthenticationCompletionBlock _completionBlock;
    UserAccount *_userAccount;
}

+ (LocalAuthenticationManager *) sharedManager
{
    static LocalAuthenticationManager *sharedManager;
    
    if (sharedManager == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            sharedManager = [LocalAuthenticationManager new];
        });
    }
    
    return sharedManager;
}

- (void) authenticateForAccount:(UserAccount *)account completionBlock:(LocalAuthenticationCompletionBlock)completionBlock
{
    _userAccount = [account copy];
    _completionBlock = completionBlock;
    
    if ([self canEvaluatePolicy])
        [self evaluatePolicy];
    else
        [self fallback];
}

- (BOOL)canEvaluatePolicy
{
    LAContext *context = [[LAContext alloc] init];
    NSError *error;
    
    // test if we can evaluate the policy, this test will tell us if Touch ID is available and enrolled
    BOOL success = [context canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
    
    NSString *message = @"Touch ID is available.";
    
    if (success == NO)
        message = [NSString stringWithFormat:@"Touch ID is not available. Error: %@", error.localizedDescription];

    NSLog(@"%@", message);
    
    return success;
}

- (void)evaluatePolicy
{
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"Enter account password";
    __block  NSString *message;
    
    // Show the authentication UI with the reason string.
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:@"Please use your fingerprint to confirm account delete!"
                      reply:^(BOOL success, NSError *authenticationError)
     {
         if (success)
         {
             if (_completionBlock)
                 _completionBlock (YES, nil);
             
             [self cleanup];
         }
         else
         {
             message = [NSString stringWithFormat:@"evaluatePolicy: %@", authenticationError.localizedDescription];
             NSLog(@"%@", message);
             
             switch (authenticationError.code)
             {
                 case kLAErrorUserFallback:
                 case kLAErrorTouchIDLockout:
                 case kLAErrorAuthenticationFailed:
                 {
                     [self fallback];
                 }
                     break;
                     
                case kLAErrorUserCancel:
                 {
                     _completionBlock(NO, authenticationError);
                     [self cleanup];
                 }
                     break;
                     
                 default:
                     break;
             }
         }
     }];
}

- (void) fallback
{
    NSString *message = [NSString stringWithFormat:@"Please enter the password for '%@' account!", _userAccount.username];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField)
    {
        textField.secureTextEntry = YES;
    }];
    
    // add cancel action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action)
    {
        NSError *error = [NSError errorWithDomain:@"The user canceled the fallback mechanism." code:-1 userInfo:nil];
        _completionBlock(NO, error);
        [self cleanup];
    }];
    [alertController addAction:cancelAction];
    
    // add done action
    UIAlertAction *doneAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action)
    {
        UITextField *passwordTextField = alertController.textFields.firstObject;
        
        if ([passwordTextField.text isEqualToString:_userAccount.password])
        {
            NSLog(@"password match -> procede with completion block");
            _completionBlock (YES, nil);
            [self cleanup];
        }
        else
        {
            [self fallback];
        }
    }];
    [alertController addAction:doneAction];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [delegate.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    });
}

- (void) cleanup
{
    _userAccount = nil;
    _completionBlock = nil;
}

@end