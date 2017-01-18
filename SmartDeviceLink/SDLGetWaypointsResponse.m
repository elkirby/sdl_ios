//  SDLGetWaypointsResponse.m
//

#import "SDLGetWaypointsResponse.h"

#import "SDLLocationDetails.h"
#import "SDLNames.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SDLGetWayPointsResponse

- (instancetype)init {
    if (self = [super initWithName:SDLNameGetWaypoints]) {
    }
    return self;
}

- (void)setWaypoints:(nullable NSArray<SDLLocationDetails *> *)waypoints {
    if (waypoints != nil) {
        parameters[SDLNameWaypoints] = waypoints;
    } else {
        [parameters removeObjectForKey:SDLNameWaypoints];
    }
}

- (nullable NSArray<SDLLocationDetails *> *)waypoints {
    NSMutableArray *array = [parameters objectForKey:SDLNameWaypoints];
    if ([array count] < 1 || [[array objectAtIndex:0] isKindOfClass:SDLLocationDetails.class]) {
        return [array copy];
    } else {
        NSMutableArray *newList = [NSMutableArray arrayWithCapacity:[array count]];
        for (NSDictionary *dict in array) {
            [newList addObject:[[SDLLocationDetails alloc] initWithDictionary:(NSMutableDictionary *)dict]];
        }
        return [newList copy];
    }
}

@end

@implementation SDLGetWaypointsResponse

@end

NS_ASSUME_NONNULL_END
