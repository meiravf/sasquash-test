/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "AVAAvalanche.h"
#import "AVALoggerPrivate.h"
#import "AVAAvalancheDelegate.h"
#import "AVAChannel.h"
#import "AVASender.h"
#import "AVAStorage.h"
#import "AVAFeaturePrivate.h"

@class AVAFeature;

@interface AVAAvalanche () <AVAAvalancheDelegate>

@property (nonatomic) id<AVAChannel> channel;
@property (nonatomic) NSMutableArray<NSObject<AVAFeaturePrivate> *> *features;
@property (nonatomic, copy) NSString *appKey;
@property (nonatomic) NSString *installId;
@property (nonatomic) NSString *apiVersion;
@property BOOL featuresStarted;

- (NSString*)appKey;
- (NSUUID*)installId;
- (NSString*)apiVersion;
- (void)setInstallId;

@end