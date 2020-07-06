//
//  SDLWindowStatusSpec.m
//  SmartDeviceLinkTests
//

#import <Foundation/Foundation.h>
#import <Nimble/Nimble.h>
#import <Quick/Quick.h>
#import "SDLGrid.h"
#import "SDLRPCParameterNames.h"
#import "SDLWindowState.h"
#import "SDLWindowStatus.h"

const UInt8 approximatePosition = 13;
const UInt8 deviation = 42;

QuickSpecBegin(SDLWindowStatusSpec)

describe(@"Getter/Setter Tests", ^ {
    it(@"Should set and get correctly", ^ {
        SDLWindowState *state = [[SDLWindowState alloc] initWithApproximatePosition:approximatePosition deviation:deviation];
        SDLGrid *location = [[SDLGrid alloc] init];
        SDLWindowStatus *testStruct = [[SDLWindowStatus alloc] initWithLocation:location state:state];

        expect(testStruct.location).to(equal(location));
        expect(testStruct.state).to(equal(state));
    });

    it(@"Should get correctly when initialized", ^ {
        SDLWindowState *state = [[SDLWindowState alloc] initWithApproximatePosition:approximatePosition deviation:deviation];
        SDLGrid *location = [[SDLGrid alloc] init];
        NSDictionary *dict = @{SDLRPCParameterNameLocation:location,
                                SDLRPCParameterNameState:state
                                };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        SDLWindowStatus *testStruct = [[SDLWindowStatus alloc] initWithDictionary:dict];
#pragma clang diagnostic pop

        expect(testStruct.location).to(equal(location));
        expect(testStruct.state).to(equal(state));
    });

    it(@"Should return nil if not set", ^ {
        SDLWindowStatus *testStruct = [[SDLWindowStatus alloc] init];

        expect(testStruct.location).to(beNil());
        expect(testStruct.state).to(beNil());
    });
});

QuickSpecEnd
