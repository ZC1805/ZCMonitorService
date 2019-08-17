//
//  ZCTimerHolder.h
//  ZCKit
//
//  Created by admin on 2019/1/11.
//  Copyright © 2018 Squat in house. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZCMonitorService.h"

NS_ASSUME_NONNULL_BEGIN

@class ZCTimerHolder;

@protocol ZCTimerHolderDelegate <NSObject>  /**< 回调可实现的方法 */

@optional

- (BOOL)timerHolderFired:(ZCTimerHolder *)holder;  /**< return本次是否是有效计数，返回YES会重置超时计数，不实现则计一次超时计数 */

- (void)timerHolderSleep:(ZCTimerHolder *)holder;  /**< 主动调用sleep或overtime自动sleep回调 */

@end


@interface ZCTimerHolder : NSObject  /**< 需外部强引用，通过timeoutCount可控制是否进入睡眠状态 */

@property (nonatomic, assign, readonly) BOOL isSleeping;  /**< 是否睡眠状态 */

@property (nonatomic, assign, readonly) BOOL isInvalid;  /**< 是否无效状态 */

@property (nonatomic, assign, readonly) NSUInteger overtimeCount;  /**< 当前超时计数 */

/** 都会按延迟时间执行。timeoutCount为0时Timer将不会重复，timeoutCount允许超时计数，当到达允许超时计数时，timer将sleep。second不能为0，默认1。*/
- (void)startTimer:(NSTimeInterval)seconds sleepTimeout:(NSUInteger)timeoutCount delegate:(nullable id<ZCTimerHolderDelegate>)delegate;

- (void)sleepTimer;  /**< 睡眠timer */

- (void)rebootTimer;  /**< 重启timer */

- (void)invalidateTimer;  /**< 销毁timer，无法再重启 */

@end



@interface ZCAssemblePart : NSObject  /**< 监听收到的broadcast的Ids为Assemble.fireId的数组、object为Assemble、type为Assemble.type */

@property (nonatomic, assign, readonly) ZCMonitorType type;  /**< 广播类型，单值 */

@property (nonatomic, copy, readonly) NSString *fireId;  /**< 内容标识，或者最新的内容标识，默认"" */

@property (nonatomic, strong, readonly) id content;  /**< 内容数据，或者最新的内容数据，默认NSNull */

- (NSArray <NSString *>*)fireIdsAssemble;  /**< 集合发送出来的fireId集合 */

- (NSArray <id>*)contentsAssemble;  /**< 集合发送出来的content集合 */

@end


@interface ZCAssembleFirer : NSObject  /**< 需外部强引用，多次未收到fire时会进入睡眠，收到后会启动，可用于定时或聚集到最大数量时发送广播集合 */

@property (nonatomic, assign, readonly) BOOL isSleeping;  /**< 是否正在睡眠状态 */

@property (nonatomic, assign, readonly) NSUInteger maxAssemble;  /**< 最大一次性发送量 */

@property (nonatomic, assign) BOOL isAllowOverflowIssue;  /**< 非时时发送下，是否允许溢出提前发布，默认NO */

@property (nonatomic, assign) BOOL isOnlyReachMaxIssue;  /**< 非时时发送下，是否当聚集达到最大值时才发布，默认NO */

@property (nonatomic, assign) BOOL isOnlyActivateIssue;  /**< 非时时发送下，是否仅在前台时允许发布，设置YES时切换状态将发布所有缓存广播，默认NO */

/** timeoutCount不能小于1，既超时多少次会进入睡眠状态，interval是每次发送广播的时间间隔，maxAssemble小于2时将会视为时时发送 */
- (instancetype)initWithSleepTimeoutCount:(NSUInteger)timeoutCount interval:(NSTimeInterval)interval maxAssemble:(NSUInteger)maxAssemble;

/** 聚集广播，broadcast的Ids为fireId的数组、object为ZCAssemblePart对象，type可以是复合值 */
- (void)fireAssemblePart:(ZCMonitorType)type fireId:(nullable NSString *)fireId content:(nullable id)content;

/** 按类型发布聚集的所有广播，type为None时将发布所有类型广播来清空，type可以是复合值 */
- (void)issueAllAssembleParts:(ZCMonitorType)type;

/** 重新存储值，保存为待发送中 */
- (void)cacheAssemblePart:(ZCAssemblePart *)assemblePart;

@end

NS_ASSUME_NONNULL_END
