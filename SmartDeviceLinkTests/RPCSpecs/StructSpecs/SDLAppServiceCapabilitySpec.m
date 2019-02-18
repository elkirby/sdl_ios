//
//  SDLAppServiceCapabilitySpec.m
//  SmartDeviceLinkTests
//
//  Created by Nicole on 1/30/19.
//  Copyright © 2019 smartdevicelink. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "SDLAppServiceCapability.h"
#import "SDLNames.h"

QuickSpecBegin(SDLAppServiceCapabilitySpec)

describe(@"Getter/Setter Tests", ^{
    __block SDLServiceUpdateReason testUpdateReason = nil;
    __block SDLAppServiceRecord *testUpdatedAppServiceRecord = nil;

    beforeEach(^{
        testUpdateReason = SDLServiceUpdateActivated;
        testUpdatedAppServiceRecord = [[SDLAppServiceRecord alloc] initWithDictionary:@{SDLNameServiceID:@"1234", SDLNameServicePublished:@YES}];
    });

    it(@"Should set and get correctly", ^{
        SDLAppServiceCapability *testStruct = [[SDLAppServiceCapability alloc] init];
        testStruct.updateReason = testUpdateReason;
        testStruct.updatedAppServiceRecord = testUpdatedAppServiceRecord;

        expect(testStruct.updateReason).to(equal(testUpdateReason));
        expect(testStruct.updatedAppServiceRecord).to(equal(testUpdatedAppServiceRecord));
    });

    it(@"Should initWithUpdateReason:updatedAppServiceRecord correctly", ^{
        SDLAppServiceCapability *testStruct = [[SDLAppServiceCapability alloc] initWithUpdateReason:testUpdateReason updatedAppServiceRecord:testUpdatedAppServiceRecord];

        expect(testStruct.updateReason).to(equal(testUpdateReason));
        expect(testStruct.updatedAppServiceRecord).to(equal(testUpdatedAppServiceRecord));
    });

    it(@"Should get correctly when initialized with a dictionary", ^{
        NSDictionary *dict = @{SDLNameUpdateReason:testUpdateReason,
                               SDLNameUpdatedAppServiceRecord:testUpdatedAppServiceRecord
                               };

        SDLAppServiceCapability *testStruct = [[SDLAppServiceCapability alloc] initWithDictionary:dict];
        expect(testStruct.updateReason).to(equal(testUpdateReason));
        expect(testStruct.updatedAppServiceRecord).to(equal(testUpdatedAppServiceRecord));
    });

    it(@"Should return nil if not set", ^{
        SDLAppServiceCapability *testStruct = [[SDLAppServiceCapability alloc] init];

        expect(testStruct.updateReason).to(beNil());
        expect(testStruct.updatedAppServiceRecord).to(beNil());
    });
});

QuickSpecEnd
