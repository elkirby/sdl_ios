//
//  SDLConfiguration.m
//  SmartDeviceLink-iOS
//
//  Created by Joel Fischer on 10/13/15.
//  Copyright © 2015 smartdevicelink. All rights reserved.
//

#import "SDLConfiguration.h"

#import "SDLLifecycleConfiguration.h"
#import "SDLLockScreenConfiguration.h"
#import "SDLLogConfiguration.h"
#import "SDLStreamingMediaConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SDLConfiguration

- (instancetype)initWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfiguration {
    return [self initWithLifecycle:lifecycleConfiguration lockScreen:nil logging:nil];
}

+ (instancetype)configurationWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfiguration {
    return [[self alloc] initWithLifecycle:lifecycleConfiguration lockScreen:nil logging:nil];
}

- (instancetype)initWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig {
    return [self initWithLifecycle:lifecycleConfig lockScreen:lockScreenConfig logging:nil];
}

+ (instancetype)configurationWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig {
    return [[self alloc] initWithLifecycle:lifecycleConfig lockScreen:lockScreenConfig];
}

- (instancetype)initWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig logging:(nullable SDLLogConfiguration *)logConfig {
    self = [super init];
    if (!self) {
        return nil;
    }

    _lifecycleConfig = lifecycleConfig;
    _lockScreenConfig = lockScreenConfig ?: [SDLLockScreenConfiguration enabledConfiguration];
    _loggingConfig = logConfig ?: [SDLLogConfiguration defaultConfiguration];

    return self;
}

+ (instancetype)configurationWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig logging:(nullable SDLLogConfiguration *)logConfig {
    return [[self alloc] initWithLifecycle:lifecycleConfig lockScreen:lockScreenConfig logging:logConfig];
}

- (instancetype)initWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig logging:(nullable SDLLogConfiguration *)logConfig streamingMedia:(nullable SDLStreamingMediaConfiguration *)streamingMediaConfig {
    self = [super init];
    if (!self) {
        return nil;
    }

    _lifecycleConfig = lifecycleConfig;
    _lockScreenConfig = lockScreenConfig ?: [SDLLockScreenConfiguration enabledConfiguration];
    _loggingConfig = logConfig ?: [SDLLogConfiguration defaultConfiguration];

    if (_streamingMediaConfig != nil) {
        NSAssert(!([_lifecycleConfig.appType isEqualToEnum:SDLAppHMITypeNavigation] || [_lifecycleConfig.appType isEqualToEnum:SDLAppHMITypeProjection]), @"You should only set a streaming media configuration if your app is a NAVIGATION or PROJECTION HMI type");
        _streamingMediaConfig = streamingMediaConfig;
    } else {
        NSAssert(([_lifecycleConfig.appType isEqualToEnum:SDLAppHMITypeNavigation] || [_lifecycleConfig.appType isEqualToEnum:SDLAppHMITypeProjection]), @"If your app is a NAVIGATION or PROJECTION HMI type, you must set a streaming media configuration on SDLConfiguration");
    }

    return self;
}

+ (instancetype)configurationWithLifecycle:(SDLLifecycleConfiguration *)lifecycleConfig lockScreen:(nullable SDLLockScreenConfiguration *)lockScreenConfig logging:(nullable SDLLogConfiguration *)logConfig streamingMedia:(nullable SDLStreamingMediaConfiguration *)streamingMediaConfig {
    return [[self alloc] initWithLifecycle:lifecycleConfig lockScreen:lockScreenConfig logging:logConfig streamingMedia:streamingMediaConfig];
}

#pragma mark - NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    SDLConfiguration *new = [[SDLConfiguration allocWithZone:zone] initWithLifecycle: _lifecycleConfig lockScreen: _lockScreenConfig logging:_loggingConfig];

    return new;
}

@end

NS_ASSUME_NONNULL_END
