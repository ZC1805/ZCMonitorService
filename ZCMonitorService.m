//
//  ZCMonitorService.h
//  ZCKit
//
//  Created by admin on 2019/1/11.
//  Copyright © 2018 Squat in house. All rights reserved.
//

#import "ZCMonitorService.h"
#import <UIKit/UIKit.h>

#define MONITOR_USE_PRIORITY_LAZY  0  /* 是否使用优先级&懒广播，暂不使用 */

#pragma mark - Class - ZCMonitorBroadcast
@implementation ZCMonitorBroadcast

- (instancetype)initWithType:(ZCMonitorType)type issuer:(id)issuer {
    if (self = [super init]) {
        _rank = 0;
        _type = type;
        _issuer = issuer;
        _ids = [NSArray array];
        _infos = [NSDictionary dictionary];
        _priority = ZCMonitorPriorityNormal;
    }
    return self;
}

- (void)resetObject:(id)object ids:(NSArray <NSString *>*)ids infos:(NSDictionary *)infos {
    _object = object;
    if (ids) _ids = ids;
    if (infos) _infos = infos;
}

- (void)resetRank:(int)rank priority:(ZCMonitorPriority)priority {
    _rank = rank;
    _priority = priority;
}

+ (instancetype)broadcastType:(ZCMonitorType)type issuer:(id)issuer {
    ZCMonitorBroadcast *broadcast = [[ZCMonitorBroadcast alloc] initWithType:type issuer:issuer];
    return broadcast;
}

+ (instancetype)broadcastType:(ZCMonitorType)type issuer:(id)issuer copy:(ZCMonitorBroadcast *)origin {
    ZCMonitorBroadcast *broadcast = [[ZCMonitorBroadcast alloc] initWithType:type issuer:issuer];
    [broadcast resetObject:origin.object ids:origin.ids infos:origin.infos];
    return broadcast;
}

@end


#pragma mark - Class - ZCMonitorLazy
@interface ZCMonitorLazy : NSObject

@property (nonatomic, assign) BOOL isOpen;  /**< 懒广播时是否是允许时时接收 */

@property (nonatomic, strong) NSMutableArray <ZCMonitorBroadcast *>*cache;  /**< 懒广播缓存 */

@end

@implementation ZCMonitorLazy

- (NSMutableArray <ZCMonitorBroadcast *>*)cache {
    if (!_cache) {
        _cache = [NSMutableArray array];
    }
    return _cache;
}

@end


#pragma mark - Class - ZCMonitorListener
@interface ZCMonitorListener : NSObject

@property (nonatomic, weak) id <ZCMonitorProtocol> listener;  /**< 广播接收者 */

@property (nonatomic, assign) ZCMonitorType listenType;  /**< 广播接收类型 */

@property (nonatomic, assign) NSUInteger mask1;  /**< mask * 2e+0 */

@property (nonatomic, assign) NSUInteger mask2;  /**< mask * 2e+1 */

@property (nonatomic, assign) NSUInteger mask3;  /**< mask * 2e+0 */

@property (nonatomic, strong) NSMutableDictionary <NSNumber *, ZCMonitorLazy *>*lazyMap;  /**< lazy类型映射 */

@end

@implementation ZCMonitorListener

- (instancetype)initWith_listener:(id <ZCMonitorProtocol>)listener {
    if (self = [super init]) {
        self.listener = listener;
    }
    return self;
}

- (void)open_caches:(ZCMonitorType)types {
    if (MONITOR_USE_PRIORITY_LAZY) {
        NSUInteger n = types; NSUInteger i = 0;
        if (types == ZCMonitorTypeNone) n = _mask3;
        while (n > 0) {
            NSUInteger y = n % 2; n >>= 1;
            if (y == 1) {
                ZCMonitorType type = 1 << i;
                ZCMonitorLazy *lazy = [self addMapType:type];
                lazy.isOpen = YES;
                [self issue_lazy:lazy];
            }
            i += 1;
        }
    }
}

- (void)close_caches:(ZCMonitorType)types {
    if (MONITOR_USE_PRIORITY_LAZY) {
        NSUInteger n = types; NSUInteger i = 0;
        if (types == ZCMonitorTypeNone) n = _mask3;
        while (n > 0) {
            NSUInteger y = n % 2; n >>= 1;
            if (y == 1) {
                [self addMapType:(1 << i)].isOpen = NO;
            }
            i += 1;
        }
    }
}

- (BOOL)joinLazyBroadcast:(ZCMonitorBroadcast *)broadcast {
    ZCMonitorLazy *lazy = [self addMapType:broadcast.type];
    if (!lazy.isOpen) {
        [lazy.cache addObject:broadcast];
        return YES;
    }
    return NO;
}

- (ZCMonitorPriority)listenPriority:(ZCMonitorType)type {
    return (2 * ((self.mask2 & type) ? 1 : 0) + ((self.mask1 & type) ? 1 : 0));
}

#pragma mark - Private
- (void)setListener:(id<ZCMonitorProtocol>)listener {
    _listener = listener;
    if ([listener respondsToSelector:@selector(monitorForwardBroadcast:)]) {
        _listenType = [listener monitorForwardBroadcast:[ZCMonitorBroadcast broadcastType:ZCMonitorTypeNone issuer:nil]];
    }
    if (MONITOR_USE_PRIORITY_LAZY) {
        _mask1 = 0; _mask2 = 0; _mask3 = 0; [_lazyMap removeAllObjects];
        NSUInteger n = _listenType; NSUInteger i = 0;
        while (n > 0) {
            NSUInteger y = n % 2; n >>= 1;
            if (y == 1) {
                NSUInteger type = 1 << i;
                if ([listener respondsToSelector:@selector(monitorPriorityWithType:)]) {
                    ZCMonitorPriority priority = [listener monitorPriorityWithType:type];
                    if (priority & 1) _mask1 = _mask1 | type;
                    if (priority & 2) _mask2 = _mask2 | type;
                } else {
                    _mask1 = _mask1 | type;
                }
                if ([listener respondsToSelector:@selector(monitorLazyReceiveWithType:)] && [listener monitorLazyReceiveWithType:type]) {
                    _mask3 = _mask3 | type;
                }
            }
            i += 1;
        }
    }
}

- (void)issue_lazy:(ZCMonitorLazy *)lazy {
    for (ZCMonitorBroadcast *subbro in lazy.cache) {
        if ([self.listener respondsToSelector:@selector(monitorForwardBroadcast:)]) {
            [subbro resetRank:0 priority:[self listenPriority:subbro.type]];
            [self.listener monitorForwardBroadcast:subbro];
        }
    }
    [lazy.cache removeAllObjects];
}

- (ZCMonitorLazy *)addMapType:(ZCMonitorType)type {
    NSNumber *number = [NSNumber numberWithUnsignedInteger:type];
    ZCMonitorLazy *lazy = [self.lazyMap objectForKey:number];
    if (!lazy) {
        lazy = [[ZCMonitorLazy alloc] init];
        [self.lazyMap setObject:lazy forKey:number];
    }
    return lazy;
}

- (NSMutableDictionary <NSNumber *, ZCMonitorLazy *>*)lazyMap {
    if (!_lazyMap) {
        _lazyMap = [NSMutableDictionary dictionary];
    }
    return _lazyMap;
}

@end


#pragma mark - Class - ZCMonitorService
@interface ZCMonitorService ()

@property (nonatomic, strong) NSMutableArray <ZCMonitorListener *>*listeners;

@end

@implementation ZCMonitorService

+ (instancetype)instance {
    static ZCMonitorService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ZCMonitorService alloc] init];
    });
    return instance;
}

- (NSMutableArray <ZCMonitorListener *>*)listeners {
    if (!_listeners) {
        _listeners = [NSMutableArray array];
    }
    return _listeners;
}

- (void)dealloc {
    [_listeners removeAllObjects];
}

- (ZCMonitorListener *)find_listener:(id <ZCMonitorProtocol>)listener {
    if (!listener) return nil;
    ZCMonitorListener *find = nil;
    for (ZCMonitorListener *lis in self.listeners) {
        if (lis.listener && [lis.listener isEqual:listener]) {
            find = lis; break;
        }
    }
    return find;
}

- (void)issue_map:(ZCMonitorBroadcast *)subbro {
    NSMutableArray *maps = [NSMutableArray arrayWithCapacity:self.listeners.count];
    for (ZCMonitorListener *listen in self.listeners) {
        if (listen.listener && (listen.listenType & subbro.type)) {
            if ((listen.mask3 & subbro.type) && [listen joinLazyBroadcast:subbro]) {}
            else {[maps addObject:listen];}
        }
    }
    [maps sortUsingComparator:^NSComparisonResult(ZCMonitorListener *_Nonnull obj1, ZCMonitorListener *_Nonnull obj2) {
        ZCMonitorPriority pri1 = [obj1 listenPriority:subbro.type];
        ZCMonitorPriority pri2 = [obj2 listenPriority:subbro.type];
        if (pri1 == pri2) return NSOrderedSame;
        else if (pri1 > pri2) return NSOrderedAscending;
        else return NSOrderedDescending;
    }];
    int rank = 0;
    for (ZCMonitorListener *listen in maps) {
        if ([listen.listener respondsToSelector:@selector(monitorForwardBroadcast:)]) {
            [subbro resetRank:rank priority:[listen listenPriority:subbro.type]];
            [listen.listener monitorForwardBroadcast:subbro];
            rank += 1;
        }
    }
}

- (void)issue_api:(ZCMonitorBroadcast *)broadcast {
    if (!broadcast || broadcast.type == ZCMonitorTypeNone) {
        NSAssert(0, @"monitor type is mistake"); return;
    }
    NSMutableArray *subbros = [NSMutableArray array];
    NSUInteger n = broadcast.type; NSUInteger i = 0;
    while (n > 0) {
        NSUInteger y = n % 2; n >>= 1;
        if (y == 1) {
            [subbros addObject:[ZCMonitorBroadcast broadcastType:(1 << i) issuer:broadcast.issuer copy:broadcast]];
        }
        i += 1;
    }
    for (ZCMonitorBroadcast *subbro in subbros) {
        if (MONITOR_USE_PRIORITY_LAZY) {
            [self issue_map:subbro]; continue;
        }
        int rank = 0;
        for (ZCMonitorListener *listen in self.listeners) {
            if (listen.listener && (listen.listenType & subbro.type)) {
                if ([listen.listener respondsToSelector:@selector(monitorForwardBroadcast:)]) {
                    [subbro resetRank:rank priority:ZCMonitorPriorityNormal];
                    [listen.listener monitorForwardBroadcast:subbro];
                    rank += 1;
                }
            }
        }
    }
}

#pragma mark - API
+ (void)issue_broadcast:(ZCMonitorType)type issuer:(id)issuer {
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    ZCMonitorBroadcast *broadcast = [ZCMonitorBroadcast broadcastType:type issuer:issuer];
    [[ZCMonitorService instance] issue_api:broadcast];
}

+ (void)issue_broadcast:(ZCMonitorBroadcast *)broadcast {
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    [[ZCMonitorService instance] issue_api:broadcast];
}

+ (void)open_lazyReceive:(id <ZCMonitorProtocol>)listener type:(ZCMonitorType)type {
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    ZCMonitorListener *lis = [[ZCMonitorService instance] find_listener:listener];
    if (lis) [lis open_caches:type];
}

+ (void)close_lazyReceive:(id <ZCMonitorProtocol>)listener type:(ZCMonitorType)type {
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    ZCMonitorListener *lis = [[ZCMonitorService instance] find_listener:listener];
    if (lis) [lis close_caches:type];
}

+ (void)register_listener:(id <ZCMonitorProtocol>)listener {
    if (!listener) return;
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    ZCMonitorService *monitor = [ZCMonitorService instance];
    ZCMonitorListener *audience = nil;
    for (ZCMonitorListener *member in monitor.listeners) {
        if (member.listener && [member.listener isEqual:listener]) {
            audience = member; break;
        }
        if (!member.listener && !audience) {
            audience = member;
        }
    }
    if (audience) {
        if (!audience.listener) audience.listener = listener;
    } else {
        [monitor.listeners addObject:[[ZCMonitorListener alloc] initWith_listener:listener]];
    }
}

+ (void)remove_listener:(id <ZCMonitorProtocol>)listener {
    if (!listener) return;
    NSAssert([NSThread currentThread].isMainThread, @"current is not main thread");
    ZCMonitorService *monitor = [ZCMonitorService instance];
    ZCMonitorListener *removeAudience = nil;
    NSMutableArray *audiences = [NSMutableArray array];
    for (ZCMonitorListener *member in monitor.listeners) {
        if (!member.listener) {
            [audiences addObject:member];
        } else if ([member.listener isEqual:listener]) {
            removeAudience = member;
        }
    }
    if (audiences.count) {
        [monitor.listeners removeObjectsInArray:audiences];
    }
    if (removeAudience) {
        [monitor.listeners removeObject:removeAudience];
    }
}

@end
