@interface JFFConectionTest : GHAsyncTestCase

@property ( nonatomic, retain ) id< JNUrlConnection > connection;

@end

@implementation JFFConectionTest

@synthesize connection = _connection;

-(void)dealloc
{
   [ _connection release ];
   
   [ super dealloc ];
}

-(void)testValidDownloadCompletesCorrectly
{
   [ self prepare ];
   
   //Our build server
   NSURL* data_url_ = [ NSURL URLWithString: @"http://10.28.9.57:9000/about/" ];
   
  
   JNConnectionsFactory* factory_ = [ [ JNConnectionsFactory alloc ] initWithUrl: data_url_
                                                                        postData: nil
                                                                         headers: nil ];
   [ factory_ autorelease ];
   
   
   
   id< JNUrlConnection > connection_ = [ factory_ createFastConnection ];
   NSMutableData* total_data_ = [ NSMutableData data ];
   
   connection_.didReceiveResponseBlock = ^( id response_ )
   {
      //IDLE
   };
   connection_.didReceiveDataBlock = ^( NSData* data_chunk_ )
   {
      [ total_data_ appendData: data_chunk_ ];
   };
   
   connection_.didFinishLoadingBlock = ^( NSError* error_ )
   {
      self.connection = nil;

      GHAssertNil( error_, @"Unexpected error" );

      NSData* expected_data_ = [ NSData dataWithContentsOfURL: data_url_ ];
      GHAssertTrue( [expected_data_ length] == [ total_data_ length ] , @"data mismatch" );
      
      [ self notify: kGHUnitWaitStatusSuccess
        forSelector: _cmd ]; //@selector( testValidDownloadCompletesCorrectly )];
   };
   
   self.connection = connection_;
   [ connection_ start ];
   [ self waitForStatus: kGHUnitWaitStatusSuccess
                timeout: 30. ];
}


-(void)testInValidDownloadCompletesWithError
{
   [ self prepare ];
   
   NSURL* data_url_ = [ NSURL URLWithString: @"http://kdjsfhjkfhsdfjkdhfjkds.com" ];
   
   JNConnectionsFactory* factory_ = [ [ JNConnectionsFactory alloc ] initWithUrl: data_url_
                                                                        postData: nil
                                                                         headers: nil ];
   [ factory_ autorelease ];
   
   
   
   id< JNUrlConnection > connection_ = [ factory_ createFastConnection ];
   
   connection_.didReceiveResponseBlock = ^( id response_ )
   {
      //IDLE
   };
   connection_.didReceiveDataBlock = ^( NSData* data_chunk_ )
   {
   };
   connection_.didFinishLoadingBlock = ^( NSError* error_ )
   {
      self.connection = nil;
      
      if ( nil != error_ )
      {
         [ self notify: kGHUnitWaitStatusSuccess
           forSelector: _cmd ];
         return;
      }
      
      [ self notify: kGHUnitWaitStatusFailure 
        forSelector: _cmd ];
   };
   
   self.connection = connection_;
   [ connection_ start ];
   [ self waitForStatus: kGHUnitWaitStatusSuccess
                timeout: 30. ];
}


@end
