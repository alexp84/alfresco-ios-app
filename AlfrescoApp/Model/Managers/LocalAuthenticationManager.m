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
#import "ABPadLockScreenSetupViewController.h"
#import "ABPadLockScreenViewController.h"


@interface LocalAuthenticationManager () <ABPadLockScreenSetupViewControllerDelegate, ABPadLockScreenViewControllerDelegate>

@property (nonatomic, strong) UserAccount *userAccount;
@property (nonatomic, strong) LocalAuthenticationCompletionBlock completionBlock;
@property (nonatomic, strong) NSString *thePin;

@end


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
            sharedManager.thePin = [[NSUserDefaults standardUserDefaults] stringForKey:kPin];
        });
    }
    
    return sharedManager;
}

+ (void) setup
{
    [[NSNotificationCenter defaultCenter] removeObserver:[LocalAuthenticationManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:[LocalAuthenticationManager sharedManager] selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[LocalAuthenticationManager sharedManager] selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

+ (void) showPinScreen
{
    if ([[NSUserDefaults standardUserDefaults] stringForKey:kPin] == nil)
        [LocalAuthenticationManager showPinSetupScreen];
    else
        [LocalAuthenticationManager showPinScreenAndForceBiometrics:YES];
}

+ (void) showPinSetupScreen
{
    ABPadLockScreenSetupViewController *lockScreen = [[ABPadLockScreenSetupViewController alloc] initWithDelegate:[LocalAuthenticationManager sharedManager] complexPin:YES subtitleLabelText:@"Please setup a PIN to continue."];
    lockScreen.tapSoundEnabled = YES;
    lockScreen.errorVibrateEnabled = YES;
    lockScreen.modalPresentationStyle = UIModalPresentationFullScreen;
    lockScreen.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.window.rootViewController presentViewController:lockScreen animated:YES completion:nil];
}

+ (void) showPinScreenAndForceBiometrics: (BOOL) showBiometrics
{
    ABPadLockScreenViewController *lockScreen = [[ABPadLockScreenViewController alloc] initWithDelegate:[LocalAuthenticationManager sharedManager] complexPin:YES];
    [lockScreen setAllowedAttempts:3];
    lockScreen.modalPresentationStyle = UIModalPresentationFullScreen;
    lockScreen.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [lockScreen cancelButtonDisabled:YES];

    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.window.rootViewController presentViewController:lockScreen animated:YES completion:nil];

    if (showBiometrics)
        [[LocalAuthenticationManager sharedManager] applicationWillEnterForeground:nil];
}

+ (void) authenticateForAccount:(UserAccount *)account completionBlock:(LocalAuthenticationCompletionBlock)completionBlock
{
    LocalAuthenticationManager *manager = [LocalAuthenticationManager sharedManager];
    
    manager.userAccount = [account copy];
    manager.completionBlock = completionBlock;
    
    if ([manager canEvaluatePolicy])
        [manager evaluatePolicy];
    else
        [manager fallback];
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
    context.localizedFallbackTitle = @"";// @"Enter account password";
    __block  NSString *message;
    
    // Show the authentication UI with the reason string.
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:@"Please use your fingerprint to continue!"
                      reply:^(BOOL success, NSError *authenticationError)
     {
         if (success)
         {
             if (_completionBlock)
                 _completionBlock (nil);
             
             AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
             [delegate.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
             
             [self cleanup];
         }
         else
         {
             message = [NSString stringWithFormat:@"evaluatePolicy: %@", authenticationError.localizedDescription];
             NSLog(@"%@", message);
             
             switch (authenticationError.code)
             {
                 case kLAErrorUserFallback:
                 case kLAErrorAuthenticationFailed:
//                 case kLAErrorTouchIDLockout:
                 {
                     [self fallback];
                 }
                     break;
                     
                case kLAErrorUserCancel:
                case kLAErrorSystemCancel:
                default:
                 {
                     if (_completionBlock)
                         _completionBlock(authenticationError);
                     [self cleanup];
                 }
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
        _completionBlock(error);
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
            _completionBlock (nil);
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

#pragma mark - Notifications Handlers

- (void) applicationWillEnterForeground: (NSNotification *) notification
{
    LocalAuthenticationManager *manager = [LocalAuthenticationManager sharedManager];
    
    if ([manager canEvaluatePolicy])
        [manager evaluatePolicy];
}

- (void) applicationDidEnterBackground: (NSNotification *) notification
{
    [LocalAuthenticationManager showPinScreenAndForceBiometrics:NO];
}

#pragma mark - ABPadLockScreenSetupViewControllerDelegate Methods

- (void)pinSet:(NSString *)pin padLockScreenSetupViewController:(ABPadLockScreenSetupViewController *)padLockScreenViewController
{
    //    [self dismissViewControllerAnimated:YES completion:nil];
    self.thePin = pin;
    NSLog(@"Pin set to pin %@", self.thePin);
    
    [[NSUserDefaults standardUserDefaults] setObject:pin forKey:kPin];
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ABLockScreenDelegate Methods

- (BOOL)padLockScreenViewController:(ABPadLockScreenViewController *)padLockScreenViewController validatePin:(NSString*)pin;
{
    NSLog(@"Validating pin %@", pin);
    
    return [self.thePin isEqualToString:pin];
}

- (void)unlockWasSuccessfulForPadLockScreenViewController:(ABPadLockScreenViewController *)padLockScreenViewController
{
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"Pin entry successfull");
}

- (void)unlockWasUnsuccessful:(NSString *)falsePin afterAttemptNumber:(NSInteger)attemptNumber padLockScreenViewController:(ABPadLockScreenViewController *)padLockScreenViewController
{
    NSLog(@"Failed attempt number %ld with pin: %@", (long)attemptNumber, falsePin);
}

- (void)unlockWasCancelledForPadLockScreenViewController:(ABPadLockScreenAbstractViewController *)padLockScreenViewController
{
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [delegate.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"Pin entry cancelled");
}

@end