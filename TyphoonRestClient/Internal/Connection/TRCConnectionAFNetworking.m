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



#import "TRCConnectionAFNetworking.h"
#import "AFURLRequestSerialization.h"
#import "AFURLResponseSerialization.h"
#import "AFHTTPRequestOperationManager.h"
#import "TRCUtils.h"


NSError *NSErrorWithDictionaryUnion(NSError *error, NSDictionary *dictionary);
NSString *NSStringFromHttpRequestMethod(TRCRequestMethod method);
Class ClassFromHttpRequestSerialization(TRCRequestSerialization serialization);
Class ClassFromHttpResponseSerialization(TRCResponseSerialization serialization);
BOOL IsBodyAllowedInHttpMethod(TRCRequestMethod method);

//============================================================================================================================

@interface AFStringResponseSerializer : AFHTTPResponseSerializer
@end

@implementation AFStringResponseSerializer
- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    data = [super responseObjectForResponse:response data:data error:error];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
@end

//=============================================================================================================================

@interface TRCAFNetworkingConnectionProgressHandler : NSObject <TRCProgressHandler>

@property (nonatomic, weak) AFHTTPRequestOperation *operation;

@property (atomic, strong) TRCUploadProgressBlock uploadProgressBlock;
@property (atomic, strong) TRCDownloadProgressBlock downloadProgressBlock;

@end

@implementation TRCAFNetworkingConnectionProgressHandler
- (void)setOperation:(AFHTTPRequestOperation *)operation
{
    [_operation setUploadProgressBlock:nil];
    [_operation setDownloadProgressBlock:nil];

    _operation = operation;

    [_operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long int totalBytesWritten, long long int totalBytesExpectedToWrite) {
        if (self.uploadProgressBlock) {
            self.uploadProgressBlock(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }
    }];

    [_operation setDownloadProgressBlock:^(NSUInteger bytesWritten, long long int totalBytesWritten, long long int totalBytesExpectedToWrite) {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }
    }];
}
- (void)pause
{
    [_operation pause];
}
- (void)resume
{
    [_operation resume];
}
- (void)cancel
{
    [_operation cancel];
}
@end

@interface TRCAFNetworkingConnectionResponseInfo : NSObject <TRCResponseInfo>
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSData *responseData;
+ (instancetype)infoWithOperation:(AFHTTPRequestOperation *)operation;
@end
@implementation TRCAFNetworkingConnectionResponseInfo
+ (instancetype)infoWithOperation:(AFHTTPRequestOperation *)operation
{
    TRCAFNetworkingConnectionResponseInfo *object = [TRCAFNetworkingConnectionResponseInfo new];
    object.response = operation.response;
    object.responseData = operation.responseData;
    return object;
}
@end

//=============================================================================================================================

@implementation TRCConnectionAFNetworking
{
    NSCache *requestSerializersCache;
    NSCache *responseSerializersCache;

    AFHTTPRequestOperationManager *operationManager;
    NSRegularExpression *catchUrlArgumentsRegexp;
}

- (instancetype)initWithBaseUrl:(NSURL *)baseUrl
{
    self = [super init];
    if (self) {
        _baseUrl = baseUrl;
        operationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseUrl];
        responseSerializersCache = [NSCache new];
        requestSerializersCache = [NSCache new];
        catchUrlArgumentsRegexp = [[NSRegularExpression alloc] initWithPattern:@"\\{.*?\\}" options:0 error:nil];
    }
    return self;
}

#pragma mark - HttpWebServiceConnection protocol

- (NSMutableURLRequest *)requestWithMethod:(TRCRequestMethod)httpMethod path:(NSString *)path pathParams:(NSDictionary *)pathParams body:(id)bodyObject serialization:(TRCRequestSerialization)serialization headers:(NSDictionary *)headers error:(NSError **)requestComposingError
{
    NSError *urlComposingError = nil;
    NSURL *url = [self urlFromPath:path parameters:pathParams error:&urlComposingError];

    if (urlComposingError && requestComposingError) {
        *requestComposingError = urlComposingError;
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = NSStringFromHttpRequestMethod(httpMethod);

    if (!IsBodyAllowedInHttpMethod(httpMethod)) {
        bodyObject = nil;
    }

    if ([bodyObject isKindOfClass:[NSData class]]) {
        [request setHTTPBody:bodyObject];
    } else if ([bodyObject isKindOfClass:[NSString class]]) {
        [request setHTTPBody:[bodyObject dataUsingEncoding:NSUTF8StringEncoding]];
    } else if ([bodyObject isKindOfClass:[NSInputStream class]]) {
        [request setHTTPBodyStream:bodyObject];
    } else if ([bodyObject isKindOfClass:[NSArray class]] || [bodyObject isKindOfClass:[NSDictionary class]]) {
        id<AFURLRequestSerialization> serializer = [self requestSerializerForType:serialization];
        request = [[serializer requestBySerializingRequest:request withParameters:bodyObject error:requestComposingError] mutableCopy];
    }

    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
            [request setValue:value forHTTPHeaderField:field];
        }
    }];

    return request;
}

- (id<TRCProgressHandler>)sendRequest:(NSURLRequest *)request responseSerialization:(TRCResponseSerialization)serialization outputStream:(NSOutputStream *)outputStream completion:(TRCConnectionCompletion)completion
{
    AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    requestOperation.responseSerializer = [self responseSerializerForType:serialization];

    requestOperation.outputStream = outputStream;

    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (completion) {
            completion(operation.responseObject, nil, [TRCAFNetworkingConnectionResponseInfo infoWithOperation:operation]);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (error) {
            NSInteger httpCode = operation.response.statusCode;
            error = NSErrorWithDictionaryUnion(error, @{@"TRCHttpStatusCode": @(httpCode)});
        }
        if (completion) {
            completion(operation.responseObject, error, [TRCAFNetworkingConnectionResponseInfo infoWithOperation:operation]);
        }
    }];

    TRCAFNetworkingConnectionProgressHandler *progressHandler = [TRCAFNetworkingConnectionProgressHandler new];
    progressHandler.operation = requestOperation;

    [operationManager.operationQueue addOperation:requestOperation];

    return progressHandler;
}

#pragma mark - URL composing

- (NSURL *)urlFromPath:(NSString *)path parameters:(NSDictionary *)parameters error:(NSError **)error
{
    NSURL *result = nil;

    NSArray *arguments = [catchUrlArgumentsRegexp matchesInString:path options:0 range:NSMakeRange(0, [path length])];

    NSMutableDictionary *mutableParams = [parameters mutableCopy];

    // Applying arguments
    if ([arguments count] > 0) {
        if ([mutableParams count] == 0) {
            if (error) {
                *error = NSErrorWithFormat(@"Can't process path '%@', since it has arguments (%@) but no parameters specified ", path, [arguments componentsJoinedByString:@", "]);
            }
            return nil;
        }
        NSMutableString *mutablePath = [path mutableCopy];

        for (NSTextCheckingResult *argumentMatch in arguments) {
            NSString *argument = [path substringWithRange:argumentMatch.range];
            NSString *argumentKey = [argument substringWithRange:NSMakeRange(1, argument.length-2)];
            id value = mutableParams[argumentKey];
            if (![self isValidPathArgumentValue:value]) {
                if (error) {
                    *error = NSErrorWithFormat(@"Can't process path '%@', since value for argument %@ missing or invalid (must be NSNumber or non-empty NSString)", path, argument);
                }
                return nil;
            }
            if ([value isKindOfClass:[NSNumber class]]) {
                value = [value description];
            }
            [mutablePath replaceOccurrencesOfString:argument withString:value options:0 range:NSMakeRange(0, [mutablePath length])];
            [mutableParams removeObjectForKey:argumentKey];
        }
        path = mutablePath;
    }

    if ([mutableParams count] > 0) {
        //Applying variables
        id<AFURLRequestSerialization> serializer = [self requestSerializerForType:TRCRequestSerializationHttp];

        static NSMutableURLRequest *request;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            request = [[NSMutableURLRequest alloc] init];
            request.HTTPMethod = @"GET";
        });

        request.URL = [self absoluteUrlFromPath:path];
        result = [[serializer requestBySerializingRequest:request withParameters:mutableParams error:error] URL];
    } else {
        result = [self absoluteUrlFromPath:path];
    }

    return result;
}

- (BOOL)isValidPathArgumentValue:(id)value
{
    return [value isKindOfClass:[NSNumber class]] || ([value isKindOfClass:[NSString class]] && [value length] > 0);
}

- (NSURL *)absoluteUrlFromPath:(NSString *)path
{
    BOOL isAlreadyAbsolute = [path hasPrefix:@"http://"] || [path hasPrefix:@"https://"];
    if (isAlreadyAbsolute) {
        return [[NSURL alloc] initWithString:path];
    } else {
        return [[NSURL alloc] initWithString:path relativeToURL:self.baseUrl];
    }
}

#pragma mark - Utils

- (id<AFURLRequestSerialization>)requestSerializerForType:(TRCRequestSerialization)serialization
{
    Class serializerClass = ClassFromHttpRequestSerialization(serialization);
    NSString *key = NSStringFromClass(serializerClass);
    id<AFURLRequestSerialization> cached = [requestSerializersCache objectForKey:key];
    if (!cached) {
        cached = (id<AFURLRequestSerialization>)[serializerClass new];
        [requestSerializersCache setObject:cached forKey:key];
    }
    return cached;
}

- (id<AFURLResponseSerialization>)responseSerializerForType:(TRCResponseSerialization)serialization
{
    Class serializerClass = ClassFromHttpResponseSerialization(serialization);
    NSString *key = NSStringFromClass(serializerClass);
    id<AFURLResponseSerialization> cached = [responseSerializersCache objectForKey:key];
    if (!cached) {
        cached = (id<AFURLResponseSerialization>)[serializerClass new];
        [responseSerializersCache setObject:cached forKey:key];
    }
    return cached;
}

NSString *NSStringFromHttpRequestMethod(TRCRequestMethod method)
{
    switch (method) {
        case TRCRequestMethodDelete: return @"DELETE";
        case TRCRequestMethodGet: return @"GET";
        case TRCRequestMethodHead: return @"HEAD";
        case TRCRequestMethodPatch: return @"PATCH";
        case TRCRequestMethodPost: return @"POST";
        case TRCRequestMethodPut: return @"PUT";
    }
    NSCAssert(NO, @"Unknown TRCRequestMethod: %d", (int)method);
    return @"";
}

BOOL IsBodyAllowedInHttpMethod(TRCRequestMethod method)
{
    return method == TRCRequestMethodPost || method == TRCRequestMethodPut || method == TRCRequestMethodPatch;
}

Class ClassFromHttpRequestSerialization(TRCRequestSerialization serialization)
{
    switch (serialization) {
        case TRCRequestSerializationJson: return [AFJSONRequestSerializer class];
        case TRCRequestSerializationHttp: return [AFHTTPRequestSerializer class];
        case TRCRequestSerializationPlist: return [AFPropertyListRequestSerializer class];
    }
    NSCAssert(NO, @"Unknown TRCRequestSerialization: %d", (int)serialization);
    return nil;
}

Class ClassFromHttpResponseSerialization(TRCResponseSerialization serialization)
{
    switch (serialization) {
        case TRCResponseSerializationJson: return [AFJSONResponseSerializer class];
        case TRCResponseSerializationData: return [AFHTTPResponseSerializer class];
        case TRCResponseSerializationImage: return [AFImageResponseSerializer class];
        case TRCResponseSerializationPlist: return [AFPropertyListResponseSerializer class];
        case TRCResponseSerializationXml: return [AFXMLParserResponseSerializer class];
        case TRCResponseSerializationString: return [AFStringResponseSerializer class];
    }
    NSCAssert(NO, @"Unknown TRCResponseSerialization: %d", (int)serialization);
    return nil;
}

NSError *NSErrorWithDictionaryUnion(NSError *error, NSDictionary *dictionary)
{
    NSMutableDictionary *userInfo = [[error userInfo] mutableCopy];
    [userInfo addEntriesFromDictionary:dictionary];
    return [NSError errorWithDomain:error.domain code:error.code userInfo:dictionary];
}

@end

@implementation NSError(HttpStatusCode)

- (NSInteger)httpStatusCode
{
    return [self.userInfo[@"TRCHttpStatusCode"] integerValue];
}


@end