#import "JFFAsyncOperationProgressBlockHolder.h"

@implementation JFFAsyncOperationProgressBlockHolder

@synthesize progressBlock = _progress_block;

-(void)dealloc
{
   [ _progress_block release ];

   [ super dealloc ];
}

+(id)asyncOperationProgressBlockHolder
{
   return [ [ [ self alloc ] init ] autorelease ];
}

-(void)performProgressBlockWithArgument:( id )progress_info_
{
   if ( self.progressBlock )
      self.progressBlock( progress_info_ );
}

@end
