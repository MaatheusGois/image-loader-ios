/*
 * This file is part of the ImageLoader package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "ImageLoaderPrefetcher.h"
#import "SDAsyncBlockOperation.h"
#import "SDCallbackQueue.h"
#import "SDInternalMacros.h"
#import <stdatomic.h>

@interface SDCallbackQueue ()

@property (nonatomic, strong, nonnull) dispatch_queue_t queue;

@end

@interface ImageLoaderPrefetchToken () {
    @public
    // Though current implementation, `ImageLoaderManager` completion block is always on main queue. But however, there is no guarantee in docs. And we may introduce config to specify custom queue in the future.
    // These value are just used as incrementing counter, keep thread-safe using memory_order_relaxed for performance.
    atomic_ulong _skippedCount;
    atomic_ulong _finishedCount;
    atomic_flag  _isAllFinished;
    
    unsigned long _totalCount;
    
    // Used to ensure NSPointerArray thread safe
    SD_LOCK_DECLARE(_prefetchOperationsLock);
    SD_LOCK_DECLARE(_loadOperationsLock);
}

@property (nonatomic, copy, readwrite) NSArray<NSURL *> *urls;
@property (nonatomic, strong) NSPointerArray *loadOperations;
@property (nonatomic, strong) NSPointerArray *prefetchOperations;
@property (nonatomic, weak) ImageLoaderPrefetcher *prefetcher;
@property (nonatomic, assign) ImageLoaderOptions options;
@property (nonatomic, copy, nullable) ImageLoaderContext *context;
@property (nonatomic, copy, nullable) ImageLoaderPrefetcherCompletionBlock completionBlock;
@property (nonatomic, copy, nullable) ImageLoaderPrefetcherProgressBlock progressBlock;

@end

@interface ImageLoaderPrefetcher ()

@property (strong, nonatomic, nonnull) ImageLoaderManager *manager;
@property (strong, atomic, nonnull) NSMutableSet<ImageLoaderPrefetchToken *> *runningTokens;
@property (strong, nonatomic, nonnull) NSOperationQueue *prefetchQueue;
@property (strong, nonatomic, nullable) SDCallbackQueue *callbackQueue;

@end

@implementation ImageLoaderPrefetcher

+ (nonnull instancetype)sharedImagePrefetcher {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithImageManager:[ImageLoaderManager new]];
}

- (nonnull instancetype)initWithImageManager:(ImageLoaderManager *)manager {
    if ((self = [super init])) {
        _manager = manager;
        _runningTokens = [NSMutableSet set];
        _options = ImageLoaderLowPriority;
        _prefetchQueue = [NSOperationQueue new];
        self.maxConcurrentPrefetchCount = 3;
    }
    return self;
}

- (void)setMaxConcurrentPrefetchCount:(NSUInteger)maxConcurrentPrefetchCount {
    self.prefetchQueue.maxConcurrentOperationCount = maxConcurrentPrefetchCount;
}

- (NSUInteger)maxConcurrentPrefetchCount {
    return self.prefetchQueue.maxConcurrentOperationCount;
}

- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue {
    // Deprecate and translate to SDCallbackQueue
    _callbackQueue = [[SDCallbackQueue alloc] initWithDispatchQueue:delegateQueue];
    _callbackQueue.policy = SDCallbackPolicyDispatch;
}

- (dispatch_queue_t)delegateQueue {
    // Deprecate and translate to SDCallbackQueue
    return (_callbackQueue ?: SDCallbackQueue.mainQueue).queue;
}

#pragma mark - Prefetch
- (nullable ImageLoaderPrefetchToken *)prefetchURLs:(nullable NSArray<NSURL *> *)urls {
    return [self prefetchURLs:urls progress:nil completed:nil];
}

- (nullable ImageLoaderPrefetchToken *)prefetchURLs:(nullable NSArray<NSURL *> *)urls
                                          progress:(nullable ImageLoaderPrefetcherProgressBlock)progressBlock
                                         completed:(nullable ImageLoaderPrefetcherCompletionBlock)completionBlock {
    return [self prefetchURLs:urls options:self.options context:self.context progress:progressBlock completed:completionBlock];
}

- (nullable ImageLoaderPrefetchToken *)prefetchURLs:(nullable NSArray<NSURL *> *)urls
                                           options:(ImageLoaderOptions)options
                                           context:(nullable ImageLoaderContext *)context
                                          progress:(nullable ImageLoaderPrefetcherProgressBlock)progressBlock
                                         completed:(nullable ImageLoaderPrefetcherCompletionBlock)completionBlock {
    if (!urls || urls.count == 0) {
        if (completionBlock) {
            completionBlock(0, 0);
        }
        return nil;
    }
    ImageLoaderPrefetchToken *token = [ImageLoaderPrefetchToken new];
    token.prefetcher = self;
    token.urls = urls;
    token.options = options;
    token.context = context;
    token->_skippedCount = 0;
    token->_finishedCount = 0;
    token->_totalCount = token.urls.count;
    atomic_flag_clear(&(token->_isAllFinished));
    token.loadOperations = [NSPointerArray weakObjectsPointerArray];
    token.prefetchOperations = [NSPointerArray weakObjectsPointerArray];
    token.progressBlock = progressBlock;
    token.completionBlock = completionBlock;
    [self addRunningToken:token];
    [self startPrefetchWithToken:token];
    
    return token;
}

- (void)startPrefetchWithToken:(ImageLoaderPrefetchToken * _Nonnull)token {
    for (NSURL *url in token.urls) {
        @weakify(self);
        SDAsyncBlockOperation *prefetchOperation = [SDAsyncBlockOperation blockOperationWithBlock:^(SDAsyncBlockOperation * _Nonnull asyncOperation) {
            @strongify(self);
            if (!self || asyncOperation.isCancelled) {
                return;
            }
            id<ImageLoaderOperation> operation = [self.manager loadImageWithURL:url options:token.options context:token.context progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, LoadImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                @strongify(self);
                if (!self) {
                    return;
                }
                if (!finished) {
                    return;
                }
                atomic_fetch_add_explicit(&(token->_finishedCount), 1, memory_order_relaxed);
                if (error) {
                    // Add last failed
                    atomic_fetch_add_explicit(&(token->_skippedCount), 1, memory_order_relaxed);
                }
                
                // Current operation finished
                [self callProgressBlockForToken:token imageURL:imageURL];
                
                if (atomic_load_explicit(&(token->_finishedCount), memory_order_relaxed) == token->_totalCount) {
                    // All finished
                    if (!atomic_flag_test_and_set_explicit(&(token->_isAllFinished), memory_order_relaxed)) {
                        [self callCompletionBlockForToken:token];
                        [self removeRunningToken:token];
                    }
                }
                [asyncOperation complete];
            }];
            NSAssert(operation != nil, @"Operation should not be nil, [ImageLoaderManager loadImageWithURL:options:context:progress:completed:] break prefetch logic");
            SD_LOCK(token->_loadOperationsLock);
            [token.loadOperations addPointer:(__bridge void *)operation];
            SD_UNLOCK(token->_loadOperationsLock);
        }];
        SD_LOCK(token->_prefetchOperationsLock);
        [token.prefetchOperations addPointer:(__bridge void *)prefetchOperation];
        SD_UNLOCK(token->_prefetchOperationsLock);
        [self.prefetchQueue addOperation:prefetchOperation];
    }
}

#pragma mark - Cancel
- (void)cancelPrefetching {
    @synchronized(self.runningTokens) {
        NSSet<ImageLoaderPrefetchToken *> *copiedTokens = [self.runningTokens copy];
        [copiedTokens makeObjectsPerformSelector:@selector(cancel)];
        [self.runningTokens removeAllObjects];
    }
}

- (void)callProgressBlockForToken:(ImageLoaderPrefetchToken *)token imageURL:(NSURL *)url {
    if (!token) {
        return;
    }
    BOOL shouldCallDelegate = [self.delegate respondsToSelector:@selector(imagePrefetcher:didPrefetchURL:finishedCount:totalCount:)];
    NSUInteger tokenFinishedCount = [self tokenFinishedCount];
    NSUInteger tokenTotalCount = [self tokenTotalCount];
    NSUInteger finishedCount = atomic_load_explicit(&(token->_finishedCount), memory_order_relaxed);
    NSUInteger totalCount = token->_totalCount;
    SDCallbackQueue *queue = token.context[ImageLoaderContextCallbackQueue];
    if (!queue) {
        queue = self.callbackQueue;
    }
    [(queue ?: SDCallbackQueue.mainQueue) async:^{
        if (shouldCallDelegate) {
            [self.delegate imagePrefetcher:self didPrefetchURL:url finishedCount:tokenFinishedCount totalCount:tokenTotalCount];
        }
        if (token.progressBlock) {
            token.progressBlock(finishedCount, totalCount);
        }
    }];
}

- (void)callCompletionBlockForToken:(ImageLoaderPrefetchToken *)token {
    if (!token) {
        return;
    }
    BOOL shoulCallDelegate = [self.delegate respondsToSelector:@selector(imagePrefetcher:didFinishWithTotalCount:skippedCount:)] && ([self countOfRunningTokens] == 1); // last one
    NSUInteger tokenTotalCount = [self tokenTotalCount];
    NSUInteger tokenSkippedCount = [self tokenSkippedCount];
    NSUInteger finishedCount = atomic_load_explicit(&(token->_finishedCount), memory_order_relaxed);
    NSUInteger skippedCount = atomic_load_explicit(&(token->_skippedCount), memory_order_relaxed);
    SDCallbackQueue *queue = token.context[ImageLoaderContextCallbackQueue];
    if (!queue) {
        queue = self.callbackQueue;
    }
    [(queue ?: SDCallbackQueue.mainQueue) async:^{
        if (shoulCallDelegate) {
            [self.delegate imagePrefetcher:self didFinishWithTotalCount:tokenTotalCount skippedCount:tokenSkippedCount];
        }
        if (token.completionBlock) {
            token.completionBlock(finishedCount, skippedCount);
        }
    }];
}

#pragma mark - Helper
- (NSUInteger)tokenTotalCount {
    NSUInteger tokenTotalCount = 0;
    @synchronized (self.runningTokens) {
        for (ImageLoaderPrefetchToken *token in self.runningTokens) {
            tokenTotalCount += token->_totalCount;
        }
    }
    return tokenTotalCount;
}

- (NSUInteger)tokenSkippedCount {
    NSUInteger tokenSkippedCount = 0;
    @synchronized (self.runningTokens) {
        for (ImageLoaderPrefetchToken *token in self.runningTokens) {
            tokenSkippedCount += atomic_load_explicit(&(token->_skippedCount), memory_order_relaxed);
        }
    }
    return tokenSkippedCount;
}

- (NSUInteger)tokenFinishedCount {
    NSUInteger tokenFinishedCount = 0;
    @synchronized (self.runningTokens) {
        for (ImageLoaderPrefetchToken *token in self.runningTokens) {
            tokenFinishedCount += atomic_load_explicit(&(token->_finishedCount), memory_order_relaxed);
        }
    }
    return tokenFinishedCount;
}

- (void)addRunningToken:(ImageLoaderPrefetchToken *)token {
    if (!token) {
        return;
    }
    @synchronized (self.runningTokens) {
        [self.runningTokens addObject:token];
    }
}

- (void)removeRunningToken:(ImageLoaderPrefetchToken *)token {
    if (!token) {
        return;
    }
    @synchronized (self.runningTokens) {
        [self.runningTokens removeObject:token];
    }
}

- (NSUInteger)countOfRunningTokens {
    NSUInteger count = 0;
    @synchronized (self.runningTokens) {
        count = self.runningTokens.count;
    }
    return count;
}

@end

@implementation ImageLoaderPrefetchToken

- (instancetype)init {
    self = [super init];
    if (self) {
        SD_LOCK_INIT(_prefetchOperationsLock);
        SD_LOCK_INIT(_loadOperationsLock);
    }
    return self;
}

- (void)cancel {
    SD_LOCK(_prefetchOperationsLock);
    [self.prefetchOperations compact];
    for (id operation in self.prefetchOperations) {
        id<ImageLoaderOperation> strongOperation = operation;
        if (strongOperation) {
            [strongOperation cancel];
        }
    }
    self.prefetchOperations.count = 0;
    SD_UNLOCK(_prefetchOperationsLock);
    
    SD_LOCK(_loadOperationsLock);
    [self.loadOperations compact];
    for (id operation in self.loadOperations) {
        id<ImageLoaderOperation> strongOperation = operation;
        if (strongOperation) {
            [strongOperation cancel];
        }
    }
    self.loadOperations.count = 0;
    SD_UNLOCK(_loadOperationsLock);
    
    self.completionBlock = nil;
    self.progressBlock = nil;
    [self.prefetcher removeRunningToken:self];
}

@end
