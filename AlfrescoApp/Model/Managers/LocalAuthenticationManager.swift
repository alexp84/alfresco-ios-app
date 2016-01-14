//
//  LocalAuthenticationManager.swift
//  AlfrescoApp
//
//  Created by Alexandru Posmangiu on 11/01/16.
//  Copyright © 2016 Alfresco. All rights reserved.
//

import Foundation
import LocalAuthentication
import UIKit

@objc class LocalAuthenticationManager2 : NSObject
{
    static let sharedManager = LocalAuthenticationManager2()
    
    typealias LocalAuthenticationCompletionBlock = (error: NSError?) -> Void
    private(set) var completion: LocalAuthenticationCompletionBlock?
    
    private(set) var userAccount: UserAccount?
    
    /**
    *  Authenticates the user in order to delete an account. It's designed to use Touch ID to localy authenticate the iDevice owner. If the device doesn't have Touch ID, or no fingers are added in Settings, a fallback mechanism is triggered. The fallback mechanism consists in an alert prompt asking for the password of the account that should be deleted. If Touch ID is supported and used, in case of errors validating fingers, the user may choose to use the fallback mechanism.
    *
    *  @param account         The account that the user wants to delete.
    *  @param completion      The completion block to be executed after.
    */
    static func authenticate(account: UserAccount, completion: LocalAuthenticationCompletionBlock)
    {
        sharedManager.userAccount = account
        sharedManager.completion = completion
        
        if sharedManager.canEvaluatePolicy()
        {
            sharedManager.evaluatePolicy()
        }
        else
        {
            sharedManager.fallback()
        }
    }
    
    func canEvaluatePolicy() -> Bool
    {
        var error: NSError?
        let success = LAContext().canEvaluatePolicy(.DeviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if success == false
        {
            print("Touch ID is not available. Error: " + error!.localizedDescription)
        }
        else
        {
            print("Touch ID is available")
        }
        
        return success
    }
    
    private func evaluatePolicy()
    {
        let reason = "Please use your fingerprint to confirm account delete!"
        
        let context = LAContext()
        context.localizedFallbackTitle = "Enter account password"
        context.evaluatePolicy(.DeviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { (success: Bool, error: NSError?) -> Void in
            if success && self.completion != nil
            {
                self.completion?(error: nil)
                self.cleanup()
            }
            else
            {
                print("evaluatePolicy error: " + (error?.localizedDescription)!)
                
                switch error!.code
                {
                case LAError.UserFallback.rawValue, LAError.AuthenticationFailed.rawValue:
                    self.fallback()
                    //                    case LAError.TouchIDLockout.rawValue:
                    //                        self.fallback()
                default:
                    self.completion?(error: error)
                    self.cleanup()
                }
            }
        }
    }
    
    private func fallback()
    {
        let message = "Please enter the password for '" + userAccount!.username! + "' account!"
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .Alert)
        
        alertController.addTextFieldWithConfigurationHandler { (textField) -> Void in
            textField.secureTextEntry = true
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action: UIAlertAction) -> Void in
            let error = NSError(domain: "The user canceled the fallback mechanism", code: -1, userInfo: nil)
            self.completion?(error: error)
            self.cleanup()
        }
        alertController.addAction(cancelAction)
        
        let doneAction = UIAlertAction(title: "Ok", style: .Default) { (action: UIAlertAction) -> Void in
            let passwordTextField: UITextField = (alertController.textFields?.first)! as UITextField
            
            if passwordTextField.text == self.userAccount?.password
            {
                print("password match -> procede with completion block")
                self.completion?(error: nil)
                self.cleanup()
            }
            else
            {
                self.fallback()
            }
        }
        alertController.addAction(doneAction)

        dispatch_async(dispatch_get_main_queue())
        {
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    private func cleanup()
    {
        userAccount = nil
        completion = nil
    }
}