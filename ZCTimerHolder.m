//
//  ZCTimerHolder.m
//  ZCKit
//
//  Created by admin on 2019/1/11.
//  Copyright © 2018 Squat in house. All rights reserved.
//

#import "ZCTimerHolder.h"
#import <UIKit/UIKit.h>

static long zc_max_allow_cache_count = 100;

#pragma mark - ~~~~~~~~~~ ZCTimerHolder ~~~~~~~~~~
@interface ZCTimerHolder () {
    NSTimer *_timer;
    BOOL _sleep;
    BOOL _repeats;
    NSUInteger _timeoutCount;
    NSUInteger _overtime;
}

@property (nonatomic, weak) id <ZCTimerHolderDelegate> timerDelegate;

@end

@implementation ZCTimerHolder

- (void)dealloc {
    [self invalidateTimer];
}

- (void)startTimer:(NSTimeInterval)seconds sleepTimeout:(NSUInteger)timeoutCount delegate:(id<ZCTimerHolderDelegate>)delegate {
    if (_timer) [self invalidateTimer];
    NSTimeInterval interval = seconds <= 0 ? 1 : seconds;
    _timeoutCount = timeoutCount;
    _repeats = timeoutCount != 0;
    _timerDelegate = delegate;
    _overtime = 0;
    _sleep = NO;
    _timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(onTimer:) userInfo:nil repeats:_repeats];
}

- (void)onTimer:(NSTimer *)timer {
    if (!_repeats) {
        [self invalidateTimer];
    }
    BOOL valid = NO;
    if (_timerDelegate && [_timerDelegate respondsToSelector:@selector(timerHolderFired:)]) {
        valid = [_timerDelegate timerHolderFired:self];
    }
    if (valid && _overtime != 0) {
        _overtime = 0;
    } else if (!valid) {
        _overtime = _overtime + 1;
    }
    if (_overtime >= _timeoutCount) {
        [self sleepTimer];
    }
}

- (void)sleepTimer {
    _sleep = YES;
    if (_timer) [_timer setFireDate:[NSDate distantFuture]];
    if (_timerDelegate && [_timerDelegate respondsToSelector:@selector(timerHolderSleep:)]) {
        [_timerDelegate timerHolderSleep:self];
    }
}

- (void)rebootTimer {
    _sleep = NO;
    _overtime = 0;
    if (_timer) [_timer setFireDate:[NSDate distantPast]];
}

- (void)invalidateTimer {
    if (_timer) [_timer invalidate];
    _timer = nil;
    _timerDelegate = nil;
}

#pragma mark - get
- (BOOL)isSleeping {
    return _sleep;
}

- (BOOL)isInvalid {
    return (_timer == nil);
}

- (NSUInteger)overtimeCount {
    return _overtime;
}

@end


#pragma mark - ~~~~~~~~~~ ZCAssemblePart ~~~~~~~~~~
@interface ZCAssemblePart ()

@property (nonatomic, strong) NSMutableArray <id>*contents;

@property (nonatomic, strong) NSMutableArray <NSString *>*fireIds;

@end

@implementation ZCAssemblePart

- (instancetype)initWithType:(ZCMonitorType)type fireId:(NSString *)fireId content:(id)content {
    if (self = [super init]) {
        _type = type;
        _fireId = fireId ? fireId : @"";
        _content = content ? content : [NSNull null];
    }
    return self;
}

- (NSArray <NSString *>*)fireIdsAssemble {
    return self.fireIds;
}

- (NSArray <id>*)contentsAssemble {
    return self.contents;
}

- (NSMutableArray <NSString *>*)fireIds {
    if (!_fireIds) {
        _fireIds = [NSMutableArray array];
    }
    return _fireIds;
}

- (NSMutableArray <id>*)contents {
    if (!_contents) {
        _contents = [NSMutableArray array];
    }
    return _contents;
}

@end


#pragma mark - ~~~~~~~~~~ ZCAssembleFirer ~~~~~~~~~~
@interface ZCAssembleFirer () <ZCTimerHolderDelegate>

@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSMutableArray <ZCAssemblePart *>*>*cachePool;

@property (nonatomic, strong) NSMutableArray <NSNumber *>*clearsTypes;

@property (nonatomic, strong) ZCTimerHolder *timer;

@property (nonatomic, assign) BOOL isInstantSent;

@property (nonatomic, assign) BOOL isActive;

@end

@implementation ZCAssembleFirer

- (instancetype)initWithSleepTimeoutCount:(NSUInteger)timeoutCount interval:(NSTimeInterval)interval maxAssemble:(NSUInteger)maxAssemble {
    if (self = [super init]) {
        [self startTimer:timeoutCount interval:interval maxAssemble:maxAssemble];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(lostActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(becomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (BOOL)isSleeping {
    return self.timer.isSleeping;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.timer invalidateTimer];
}

- (void)startTimer:(NSUInteger)timeoutCount interval:(NSTimeInterval)interval maxAssemble:(NSUInteger)maxAssemble {
    if (timeoutCount <= 0) timeoutCount = 1;
    _isActive = YES;
    _maxAssemble = maxAssemble;
    _isOnlyActivateIssue = NO;
    _isOnlyReachMaxIssue = NO;
    _isAllowOverflowIssue = NO;
    _isInstantSent = maxAssemble < 2;
    _timer = [[ZCTimerHolder alloc] init];
    _clearsTypes = [NSMutableArray array];
    _cachePool = [NSMutableDictionary dictionary];
    [_timer startTimer:interval sleepTimeout:timeoutCount delegate:self];
    if (_isInstantSent) [_timer sleepTimer];
}

- (void)lostActive:(id)sender {
    if (!self.isInstantSent && self.isOnlyActivateIssue && self.isActive) [self clearAssembleParts:ZCMonitorTypeNone];
    if (!self.isInstantSent && !self.timer.isSleeping && self.isOnlyActivateIssue) [self.timer sleepTimer];
    self.isActive = NO;
}

- (void)becomeActive:(id)sender {
    if (!self.isInstantSent && self.isOnlyActivateIssue && !self.isActive) [self clearAssembleParts:ZCMonitorTypeNone];
    if (!self.isInstantSent && self.timer.isSleeping && self.cachePool.count) [self.timer rebootTimer];
    self.isActive = YES;
}

#pragma mark - api
- (void)fireAssemblePart:(ZCMonitorType)type fireId:(NSString *)fireId content:(id)content {
    NSAssert([NSThread currentThread].isMainThread, @"ZCKit: info must be fired in main thread");
    if (type == ZCMonitorTypeNone) return;
    [self fire:type fireId:fireId content:content];
    if (!self.isInstantSent && self.timer.isSleeping && (self.isActive || !self.isOnlyActivateIssue)) {
        [self.timer rebootTimer];
    }
}

- (void)issueAllAssembleParts:(ZCMonitorType)type {
    NSAssert([NSThread currentThread].isMainThread, @"ZCKit: info must be fired in main thread");
    if (self.isInstantSent) return;
    [self clearAssembleParts:type];
}

- (void)cacheAssemblePart:(ZCAssemblePart *)assemblePart {
    NSAssert([NSThread currentThread].isMainThread, @"ZCKit: info must be fired in main thread");
    if (!assemblePart || assemblePart.type == ZCMonitorTypeNone) return;
    NSNumber *key = [NSNumber numberWithUnsignedInteger:assemblePart.type];
    NSMutableArray *parts = [self.cachePool objectForKey:key];
    if (!parts) {parts = [NSMutableArray array]; [self.cachePool setObject:parts forKey:key];}
    NSArray <id>* cons = [assemblePart contents];
    NSArray <NSString *>* fids = [assemblePart fireIds];
    for (int i = 0; i < fids.count; i ++) {
        if (parts.count > zc_max_allow_cache_count) break;
        [parts addObject:[[ZCAssemblePart alloc] initWithType:assemblePart.type fireId:fids[i] content:cons[i]]];
    }
}

#pragma mark - private
- (void)fire:(ZCMonitorType)type fireId:(NSString *)fireId content:(id)content {
    NSUInteger n = type; NSUInteger i = 0;
    while (n > 0) {
        NSUInteger y = n % 2; n >>= 1;
        if (y == 1) {
            ZCAssemblePart *part = [[ZCAssemblePart alloc] initWithType:(1 << i) fireId:fireId content:content];
            [self partsForType:part.type addPart:part];
        }
        i += 1;
    }
}

- (void)partsForType:(ZCMonitorType)type addPart:(ZCAssemblePart *)part {
    if (self.isInstantSent) {[self issueAssembleParts:@[part]]; return;}
    NSNumber *key = [NSNumber numberWithUnsignedInteger:type];
    NSMutableArray *parts = [self.cachePool objectForKey:key];
    if (!parts) {parts = [NSMutableArray array]; [self.cachePool setObject:parts forKey:key];}
    if (parts.count <= zc_max_allow_cache_count) [parts addObject:part];
    if (self.isActive || !self.isOnlyActivateIssue) {
        if (self.isAllowOverflowIssue && parts.count > (NSUInteger)floor(self.maxAssemble * 1.5)) {
            NSArray <ZCAssemblePart *>* subParts = [parts subarrayWithRange:NSMakeRange(0, self.maxAssemble)];
            [parts removeObjectsInRange:NSMakeRange(0, self.maxAssemble)];
            [self issueAssembleParts:subParts];
        }
    }
}

- (void)issueAssembleParts:(NSArray <ZCAssemblePart *>*)parts {
    if (!parts || !parts.count) return;
    ZCAssemblePart *last = parts.lastObject;
    for (ZCAssemblePart *part in parts) {[last.fireIds addObject:part.fireId]; [last.contents addObject:part.content];}
    ZCMonitorBroadcast *broadcast = [ZCMonitorBroadcast broadcastType:last.type issuer:nil];
    [broadcast resetObject:last ids:last.fireIds infos:nil];
    [ZCMonitorService issue_broadcast:broadcast];
}

- (void)clearAssembleParts:(ZCMonitorType)type {
    if ([self firedAssembleParts:type clear:YES]) {
        [self clearAssembleParts:type];
    }
}

- (BOOL)firedAssembleParts:(ZCMonitorType)type clear:(BOOL)isClear {
    if (!self.cachePool.count) return NO;
    __block BOOL isIssue = NO;
    [self.cachePool enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSMutableArray<ZCAssemblePart *> * _Nonnull obj, BOOL * _Nonnull stop) {
        if (type == ZCMonitorTypeNone || (type & [key unsignedIntegerValue])) {
            NSArray <ZCAssemblePart *>* subParts = nil;
            if (obj.count > self.maxAssemble) {
                subParts = [obj subarrayWithRange:NSMakeRange(0, self.maxAssemble)];
                [obj removeObjectsInRange:NSMakeRange(0, self.maxAssemble)];
            } else if (obj.count == self.maxAssemble) {
                subParts = [NSArray arrayWithArray:obj];
                [self.clearsTypes addObject:key];
            } else if (!self.isOnlyReachMaxIssue) {
                subParts = [NSArray arrayWithArray:obj];
                [self.clearsTypes addObject:key];
            } else if (isClear) {
                subParts = [NSArray arrayWithArray:obj];
                [self.clearsTypes addObject:key];
            }
            [self issueAssembleParts:subParts];
            if (!isIssue && subParts && subParts.count) {
                isIssue = YES;
            }
        }
    }];
    if (self.clearsTypes.count) {
        [self.cachePool removeObjectsForKeys:self.clearsTypes];
        [self.clearsTypes removeAllObjects];
    }
    return isIssue;
}

#pragma mark - ZCTimerHolderDelegate
- (BOOL)timerHolderFired:(ZCTimerHolder *)holder {
    return [self firedAssembleParts:ZCMonitorTypeNone clear:NO];
}

@end
