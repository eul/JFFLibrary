#import "JFFPageSlider.h"

#import "JFFStripeViewDelegate.h"
#import "UIView+AddSubviewAndScale.h"

#include <math.h>

@interface JFFPageSlider () < UIScrollViewDelegate >

@property ( nonatomic, strong ) UIScrollView* scrollView;
@property ( nonatomic, assign ) NSInteger activeIndex;
@property ( nonatomic, assign ) NSInteger firstIndex;

@property ( nonatomic, strong ) NSMutableDictionary* viewByIndex;
@property ( nonatomic, assign ) NSInteger cachedNumberOfElements;
@property ( nonatomic, assign ) NSRange previousVisiableIndexesRange;

-(void)initialize;
-(void)reloadData;

@end

@implementation JFFPageSlider

@synthesize scrollView
, activeIndex
, firstIndex
, delegate
, viewByIndex
, cachedNumberOfElements
, previousVisiableIndexesRange;

-(void)dealloc
{
   self.scrollView.delegate = nil;
}

-(id)initWithFrame:( CGRect )frame_
          delegate:( id< JFFPageSliderDelegate > )delegate_
{
   self = [ super initWithFrame: frame_ ];

   if ( self )
   {
      self.delegate = delegate_;
      [ self initialize ];
   }

   return self;
}

-(void)initialize
{
   viewByIndex = [ NSMutableDictionary new ];

   scrollView = [ [ UIScrollView alloc ] initWithFrame: self.bounds ];
   scrollView.backgroundColor = [ UIColor clearColor ];
   scrollView.delegate = self;
   scrollView.clipsToBounds = YES;
   scrollView.pagingEnabled = YES;
   scrollView.bounces = NO;
   scrollView.scrollEnabled = NO;
   [ self addSubviewAndScale: scrollView ];

   previousVisiableIndexesRange = NSMakeRange( 0, 1 );

   if ( self.delegate )
      [ self reloadData ];
}

-(void)awakeFromNib
{
   [ self initialize ];
}

-(CGRect)elementFrameForIndex:( NSInteger )index_
{
   CGFloat x_ = self.bounds.size.width * ( index_ - firstIndex );
   return CGRectMake( x_, 0.f, self.bounds.size.width, self.bounds.size.height );
}

-(void)removeAllElements
{
   for( UIView* view_ in [ viewByIndex allValues ] )
   {
      [ view_ removeFromSuperview ];
   }
   [ viewByIndex removeAllObjects ];
}

-(void)updateScrollViewContentSize
{
   //calls layoutSubviews
   scrollView.contentSize = CGSizeMake( self.bounds.size.width * cachedNumberOfElements,
                                       self.bounds.size.height );
}

-(UIView*)viewAtIndex:( NSInteger )index_
{
   NSNumber* index_number_ = [ [ NSNumber alloc ] initWithInteger: index_ ];
   return [ viewByIndex objectForKey: index_number_ ];
}

-(void)cacheAndPositionView:( UIView* )view_
                    toIndex:( NSInteger )index_
{
   NSNumber* index_number_ = [ [ NSNumber alloc ] initWithInteger: index_ ];
   [ viewByIndex setObject: view_ forKey: index_number_ ];
   view_.frame = [ self elementFrameForIndex: index_ ];
}

-(void)addViewForIndex:( NSInteger )index_
{
   UIView* view_ = [ self.delegate stripeView: self
                               elementAtIndex: index_ ];

   [ scrollView addSubview: view_ ];

   [ self cacheAndPositionView: view_
                       toIndex: index_ ];
}

-(void)reloadData
{
   [ self removeAllElements ];

   cachedNumberOfElements = [ delegate numberOfElementsInStripeView: self ];
   if ( 0 == cachedNumberOfElements )
   {
      scrollView.contentSize = CGSizeZero;
      return;
   }

   self.activeIndex = fmin( activeIndex, self.lastIndex );

   [ self addViewForIndex: activeIndex ];

   [ self updateScrollViewContentSize ];
}

-(CGPoint)offsetForIndex:( NSInteger )index_
{
   return CGPointMake( ( index_ - firstIndex ) * scrollView.bounds.size.width
                      , scrollView.contentOffset.y );
}

-(void)layoutSubviews
{
   [ super layoutSubviews ];

   for ( NSNumber* index_ in viewByIndex )
   {
      UIView* view_ = [ viewByIndex objectForKey: index_ ];
      view_.frame = [ self elementFrameForIndex: [ index_ integerValue ] ];
   }

   [ self updateScrollViewContentSize ];
   CGPoint offset_ = [ self offsetForIndex: activeIndex ];
   [ scrollView setContentOffset: offset_ animated: NO ];
}

-(UIView*)elementAtIndex:( NSInteger )index_
{
   NSNumber* number_index_ = [ [ NSNumber alloc ] initWithInteger: index_ ];
   return [ viewByIndex objectForKey: number_index_ ];
}

-(NSArray*)visibleElements
{
   [ self doesNotRecognizeSelector: _cmd ];
   return nil;
}

-(void)slideForward
{
   [ self doesNotRecognizeSelector: _cmd ];
}

-(void)slideBackward
{
   [ self doesNotRecognizeSelector: _cmd ];
}

-(void)slideToIndex:( NSInteger )index_ animated:( BOOL )animated_
{
   self.activeIndex = index_;
   CGPoint offset_ = [ self offsetForIndex: index_ ];
   [ scrollView setContentOffset: offset_ animated: animated_ ];
}

-(void)removeViewAtIndex:( NSInteger )index_
{
   NSAssert( index_ != activeIndex, @"Can not remove View at active index" );

   if ( index_ < activeIndex )
   {
      self.firstIndex += 1;
   }

   NSNumber* numberIndex_ = [ NSNumber numberWithInteger: index_ ];
   UIView* view_ = [ viewByIndex objectForKey: numberIndex_ ];
   [ view_ removeFromSuperview ];
   [ viewByIndex removeObjectForKey: numberIndex_ ];
}

-(void)removeViewsInRange:( JSignedRange )range_
{
   for ( NSInteger index_ = range_.location;
        index_ < range_.location + range_.length;
        ++index_ )
   {
      [ self removeViewAtIndex: index_ ];
   }

   NSInteger last_elements_count_ = cachedNumberOfElements;
   cachedNumberOfElements = [ self.delegate numberOfElementsInStripeView: self ];
   NSAssert( cachedNumberOfElements == last_elements_count_ - range_.length, @"invalid elements count" );

   [ self updateScrollViewContentSize ];
   CGPoint offset_ = [ self offsetForIndex: activeIndex ];
   [ scrollView setContentOffset: offset_ animated: NO ];
}

-(void)slideToIndex:( NSInteger )index_
{
   [ self slideToIndex: index_ animated: NO ];
}

-(NSRange)visiableIndexesRange
{
   NSInteger first_index_ = floorf( scrollView.contentOffset.x / scrollView.bounds.size.width ) + firstIndex;
   NSInteger last_index_ = ceilf( scrollView.contentOffset.x / scrollView.bounds.size.width ) + firstIndex;
   last_index_ = fmin( last_index_, self.lastIndex );

   previousVisiableIndexesRange = NSMakeRange( first_index_, last_index_ - first_index_ + 1 );
   return previousVisiableIndexesRange;
}

-(NSInteger)lastIndex
{
   return firstIndex + cachedNumberOfElements - 1;
}

-(void)shiftRightElementsFromIndex:( NSInteger )shift_from_index_
                           toIndex:( NSInteger )to_index_
{
   for ( NSInteger index_ = to_index_; index_ >= shift_from_index_; --index_ )
   {
      UIView* view_ = [ self elementAtIndex: index_ ];
      if ( !view_ )
         continue;

      [ self cacheAndPositionView: view_ toIndex: index_ ];
   }
}

-(void)inserElementAtIndex:( NSInteger )index_
{
   NSInteger prev_last_index_ = self.lastIndex;

   NSInteger last_elements_count_ = cachedNumberOfElements;
   cachedNumberOfElements = [ self.delegate numberOfElementsInStripeView: self ];

   NSAssert( cachedNumberOfElements - 1 == last_elements_count_, @"invalid elements count" );
   NSAssert( ( index_ >= firstIndex - 1 ) && ( index_ <= self.lastIndex + 1 ), @"invalid index" );

   self.firstIndex = fmin( firstIndex, index_ );
   if ( index_ <= prev_last_index_ )
      [ self shiftRightElementsFromIndex: index_ toIndex: prev_last_index_ ];

   [ self addViewForIndex: index_ ];

   [ self updateScrollViewContentSize ];

   [ self slideToIndex: activeIndex ];
}

-(void)pushFrontElement
{
   [ self inserElementAtIndex: self.lastIndex + 1 ];
}

-(void)pushBackElement
{
   [ self inserElementAtIndex: self.firstIndex - 1 ];
}

#pragma mark UIScrollViewDelegate

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
   NSRange previuos_range_ = previousVisiableIndexesRange;
   NSRange index_range_ = [ self visiableIndexesRange ];

   if ( NSEqualRanges( previuos_range_, index_range_ ) )
      return;

   NSInteger to_index_ = index_range_.location + index_range_.length;
   for ( NSInteger index_ = index_range_.location; index_ < to_index_; ++index_ )
   {
      if ( [ self elementAtIndex: index_ ] )
         continue;

      [ self addViewForIndex: index_ ];
   }
}

-(void)syncContentOffsetWithActiveElement
{
   self.activeIndex = floor( scrollView.contentOffset.x / scrollView.bounds.size.width ) + firstIndex;

   [ self updateScrollViewContentSize ];
   CGPoint offset_ = [ self offsetForIndex: activeIndex ];
   [ scrollView setContentOffset: offset_ animated: NO ];
}

-(void)scrollViewDidEndDecelerating:( UIScrollView* )scrollView_
{
   [ self syncContentOffsetWithActiveElement ];
}

-(void)scrollViewDidEndScrollingAnimation:( UIScrollView* )scrollView_
{
   [ self syncContentOffsetWithActiveElement ];
}

@end
