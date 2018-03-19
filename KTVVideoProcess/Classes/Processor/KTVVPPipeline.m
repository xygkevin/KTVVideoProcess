//
//  KTVVPPipeline.m
//  KTVVideoProcessDemo
//
//  Created by Single on 2018/3/19.
//  Copyright © 2018年 Single. All rights reserved.
//

#import "KTVVPPipeline.h"
#import "KTVVPFilter.h"
#import "KTVVPMessageLoop.h"

@interface KTVVPPipeline () <KTVVPMessageLoopDelegate, KTVVPInput>

@property (nonatomic, assign) BOOL didSetup;
@property (nonatomic, strong) NSArray <KTVVPFilter *> * filters;
@property (nonatomic, strong) EAGLContext * glContext;
@property (nonatomic, strong) KTVVPMessageLoop * messageLoop;
@property (nonatomic, copy) void(^completionHandler)(KTVVPFrame * frame);

@end

@implementation KTVVPPipeline

- (instancetype)initWithContext:(KTVVPContext *)context
                  filterClasses:(NSArray <Class> *)filterClasses
{
    if (self = [super init])
    {
        _context = context;
        _filterClasses = filterClasses;
    }
    return self;
}

- (void)setupIfNeed
{
    if (!_didSetup)
    {
        [self setup];
    }
}

- (void)setup
{
    _didSetup = YES;
    
    _messageLoop = [[KTVVPMessageLoop alloc] init];
    _messageLoop.delegate = self;
    [_messageLoop putMessage:[KTVVPMessage messageWithType:KTVVPMessageTypeOpenGLSetupContext object:nil]];
    [_messageLoop run];
}

// input
- (void)processFrame:(KTVVPFrame *)frame completionHandler:(void (^)(KTVVPFrame *))completionHandler
{
    [self setupIfNeed];
    _processing = YES;
    _completionHandler = completionHandler;
    [frame lock];
    [self.messageLoop putMessage:[KTVVPMessage messageWithType:KTVVPMessageTypeOpenGLDrawing object:frame]];
}

// result
- (void)putFrame:(KTVVPFrame *)frame
{
    if (_completionHandler)
    {
        _completionHandler(frame);
    }
}


#pragma mark - KTVVPMessageLoopDelegate

- (void)messageLoop:(KTVVPMessageLoop *)messageLoop processingMessage:(KTVVPMessage *)message
{
    if (message.type == KTVVPMessageTypeOpenGLSetupContext)
    {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                           sharegroup:self.context.mainGLContext.sharegroup];
        [EAGLContext setCurrentContext:_glContext];
        
        NSMutableArray * filters = [NSMutableArray arrayWithCapacity:self.filterClasses.count];
        id <KTVVPOutput> lastOutput = nil;
        for (Class filterClass in _filterClasses)
        {
            __kindof KTVVPFilter * obj = [filterClass alloc];
            obj = [obj initWithContext:_context glContext:_glContext];
            [lastOutput addInput:obj];
            lastOutput = obj;
            [filters addObject:obj];
        }
        [lastOutput addInput:self];
        _filters = filters;
    }
    else if (message.type == KTVVPMessageTypeOpenGLDrawing)
    {
        KTVVPFrame * frame = (KTVVPFrame *)message.object;
        if (frame)
        {
            if ([EAGLContext currentContext] != _glContext)
            {
                [EAGLContext setCurrentContext:_glContext];
            }
            [_filters.firstObject putFrame:frame];
            [frame unlock];
            _completionHandler = nil;
            _processing = NO;
        }
    }
}

@end
