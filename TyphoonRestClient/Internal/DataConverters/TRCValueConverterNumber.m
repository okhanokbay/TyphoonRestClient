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





#import "TRCValueConverterNumber.h"
#import "TRCUtils.h"


@implementation TRCValueConverterNumber

- (NSNumberFormatter *)sharedNumberFormatter
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    });
    return formatter;
}

- (id)objectFromResponseValue:(id)value error:(NSError **)error
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    } else {
        NSNumber *number = [[self sharedNumberFormatter] numberFromString:value];
        if (!number && error) {
            *error = NSErrorWithFormat(@"Can't convert string '%@' to NSNumber", value);
        }
        return number;
    }
    return nil;
}

- (id)requestValueFromObject:(id)object error:(NSError **)error
{
    if ([object isKindOfClass:[NSNumber class]]) {
        return object;
    } else if ([object isKindOfClass:[NSString class]]) {
        NSNumber *number = [[self sharedNumberFormatter] numberFromString:object];
        if (!number && error) {
            *error = NSErrorWithFormat(@"Can't convert string '%@' to NSNumber", object);
        }
        return number;
    } else {
        if (error) {
            *error = NSErrorWithFormat(@"Can't convert '%@' into string", [object class]);
        }
        return nil;
    }
}

- (TRCValueConverterType)types
{
    return TRCValueConverterTypeNumber | TRCValueConverterTypeString;
}


@end