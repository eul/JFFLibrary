#import <JFFAsyncOperations/JFFAsyncOperationsBlockDefinitions.h>

#import <Foundation/Foundation.h>

@class JFFDidFinishAsyncOperationBlockHolder;

@interface JFFAsyncOperationManager : NSObject

@property ( nonatomic, assign ) BOOL finishAtLoading;
@property ( nonatomic, assign ) BOOL failAtLoading;

@property ( nonatomic, copy, readonly ) JFFAsyncOperation loader;
@property ( nonatomic, copy, readonly ) JFFDidFinishAsyncOperationBlockHolder* loaderFinishBlock;

@property ( nonatomic, assign, readonly ) BOOL finished;
@property ( nonatomic, assign, readonly ) BOOL canceled;
@property ( nonatomic, assign, readonly ) BOOL cancelFlag;

-(void)clear;

@end