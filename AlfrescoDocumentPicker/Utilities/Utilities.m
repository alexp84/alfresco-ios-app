/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Mobile iOS App.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ******************************************************************************/

#import "Utilities.h"

static NSString * const kWorkspaceNodePrefix = @"workspace://SpacesStore/";

@implementation Utilities

#pragma mark - Public Methods

+ (NSString *)filenameWithVersionFromFilename:(NSString *)filename nodeIdentifier:(NSString *)nodeIdentifier
{
    NSRange versionStartRange = [nodeIdentifier rangeOfString:@";"];
    
    if (nodeIdentifier.length > versionStartRange.location)
    {
        NSString *versionNumber = [nodeIdentifier substringFromIndex:(versionStartRange.location + 1)];
    
        NSString *pathExtension = filename.pathExtension;
        filename = [filename stringByDeletingPathExtension];
        filename = [filename stringByAppendingString:[NSString stringWithFormat:@" v%@", versionNumber]]; // append the version number
        filename = [filename stringByAppendingPathExtension:pathExtension];
    }
    
    return filename;
}

+ (NSString *)nodeGUIDFromNodeIdentifierWithVersion:(NSString *)nodeIdentifier
{
    NSString *nodeGUID = [nodeIdentifier stringByReplacingOccurrencesOfString:kWorkspaceNodePrefix withString:@""];
    nodeGUID = [nodeGUID stringByReplacingOccurrencesOfString:@";" withString:@""];
    nodeGUID = [nodeGUID stringByReplacingOccurrencesOfString:@"." withString:@""];
    
    return nodeGUID;
}

+ (NSString *)serverURLStringFromAccount:(id<AKUserAccount>)account
{
    NSURLComponents *url = [[NSURLComponents alloc] init];
    url.scheme = account.protocol;
    url.host = account.serverAddress;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    url.port = [formatter numberFromString:account.serverPort];
    url.path = account.serviceDocument;
    
    return [url string];
}

@end
