////////////////////////////////////////////////////////////////////////////////
//
//  TYPHOON REST CLIENT
//  Copyright 2015, Typhoon Rest Client Contributors
//  All Rights Reserved.
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////


#import <Foundation/Foundation.h>

@protocol TRCObjectMapper<NSObject>

@optional

//-------------------------------------------------------------------------------------------
#pragma mark - Parsing from Request
//-------------------------------------------------------------------------------------------

- (NSString *)responseValidationSchemaName;

- (id)objectFromResponseObject:(id)responseObject error:(NSError **)error;

//-------------------------------------------------------------------------------------------
#pragma mark - Composing for Request
//-------------------------------------------------------------------------------------------

- (NSString *)requestValidationSchemaName;

- (id)requestObjectFromObject:(id)object error:(NSError **)error;

@end