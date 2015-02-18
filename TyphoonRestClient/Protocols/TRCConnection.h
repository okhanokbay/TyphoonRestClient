////////////////////////////////////////////////////////////////////////////////
//
//  AppsQuick.ly
//  Copyright 2015 AppsQuick.ly
//  All Rights Reserved.
//
//  NOTICE: This software is the proprietary information of AppsQuick.ly
//  Use is subject to license terms.
//
////////////////////////////////////////////////////////////////////////////////




#import <Foundation/Foundation.h>
#import "TRCRequest.h"

//=============================================================================================================================
#pragma mark - Connection
//=============================================================================================================================

@protocol TRCProgressHandler;
@protocol TRCResponseInfo;

typedef void (^TRCConnectionCompletion)(id responseObject, NSError *error, id<TRCResponseInfo> responseInfo);

@protocol TRCConnection

- (NSMutableURLRequest *)requestWithMethod:(TRCRequestMethod)httpMethod path:(NSString *)path pathParams:(NSDictionary *)pathParams body:(id)bodyObject serialization:(TRCRequestSerialization)serialization headers:(NSDictionary *)headers error:(NSError **)requestComposingError;

- (id<TRCProgressHandler>)sendRequest:(NSURLRequest *)request responseSerialization:(TRCResponseSerialization)serialization outputStream:(NSOutputStream *)outputStream completion:(TRCConnectionCompletion)completion;

@end

//=============================================================================================================================
#pragma mark - Progress Handler
//=============================================================================================================================

typedef void (^TRCUploadProgressBlock)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite);
typedef void (^TRCDownloadProgressBlock)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead);

@protocol TRCProgressHandler<NSObject>

- (void)setUploadProgressBlock:(TRCUploadProgressBlock)block;
- (TRCUploadProgressBlock)uploadProgressBlock;

- (void)setDownloadProgressBlock:(TRCDownloadProgressBlock)block;
- (TRCDownloadProgressBlock)downloadProgressBlock;

- (void)pause;
- (void)resume;

- (void)cancel;

@end

//=============================================================================================================================
#pragma mark - Response Info
//=============================================================================================================================

@protocol TRCResponseInfo<NSObject>

- (NSHTTPURLResponse *)response;

- (NSData *)responseData;

@end