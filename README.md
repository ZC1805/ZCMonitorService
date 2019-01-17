# ZCMonitorService
通知服务类

1.一步监听注册监听
2.一步发送多条广播
3.广播能获得更多传递数据
4.可设置何时监听活跃（需设置MONITOR_USE_PRIORITY_LAZY为YES）
5.可设置监听接收的优先级（需设置MONITOR_USE_PRIORITY_LAZY为YES）

//以UIViewController为例
- (void)viewDidLoad {
    [super viewDidLoad];
    
    //注册监听者
    [ZCMonitorService register_listener:self];
    
    //每秒都同时发送test1、test2广播
    if (self.navigationController.viewControllers.count == 2) {
        [self scheduledGlobalTimer:^(BOOL * _Nonnull stop) {
            main_imp(^{
                [ZCMonitorService issue_broadcast:ZCMonitorTypeTest1 | ZCMonitorTypeTest2 issuer:nil];
            });
        }];
    }
}

- (void)dealloc {
    //移除监听者（此方法会自动执行，可不手动调用）
    [ZCMonitorService remove_listener:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //设置此时监听处于活跃状态，开始接收之前的存储的旧广播，且将时时接收新广播
    [ZCMonitorService open_lazyReceive:self type:ZCMonitorTypeNone];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    //设置此时监听处于非活跃状态，存储接收到的广播，且暂停接收新的广播（与上一方法成对出现）
    [ZCMonitorService close_lazyReceive:self type:ZCMonitorTypeNone];
}

//ZCMonitorService代理方法
//接收到广播的回调方法，可在此做具体的分类实现，此方法第一次将会接收到None类型广播，以便我们将返回数据作为此监听者需要监听的广播类型
- (ZCMonitorType)monitorForwardBroadcast:(ZCMonitorBroadcast *)broadcast {
    if (broadcast.type == ZCMonitorTypeTest1) {
        //to do test1
    }
    if (broadcast.type == ZCMonitorTypeTest2) {
        //to do test2
    }
    return ZCMonitorTypeTest1 | ZCMonitorTypeTest2;
}

//此方法调用一次，确定对每种类型的广播此观察者接收的优先级
- (ZCMonitorPriority)monitorPriorityWithType:(ZCMonitorType)type {
    return ZCMonitorPriorityHigh;
}

//此方法调用一次，确定此广播类型在此接收者看来是不是属于懒广播（非一直活跃状态）
- (BOOL)monitorLazyReceiveWithType:(ZCMonitorType)type {
    return YES;
}
