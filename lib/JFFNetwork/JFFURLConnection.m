#import "JFFURLConnection.h"

#import "JFFURLResponse.h"

#import <JFFUtils/JFFError.h>

#include <CFNetwork/CFNetwork.h>

@interface JFFURLConnection ()

@property ( nonatomic, retain ) NSData* postData;
@property ( nonatomic, retain ) NSDictionary* headers;

@property ( nonatomic, assign ) BOOL responseHandled;
@property ( nonatomic, retain ) NSURL* url;

-(void)startConnectionWithPostData:( NSData* )data_
                           headers:( NSDictionary* )headers_;

-(void)cancel;

-(void)closeReadStream;

-(void)handleResponseForReadStream:( CFReadStreamRef )stream_;
-(void)handleData:( void* )buffer_ length:( NSUInteger )length_;
-(void)handleFinish:( NSError* )error_;

@end

static void readStreamCallback( CFReadStreamRef stream_, CFStreamEventType event_, void* self_context_ )
{
   JFFURLConnection* self_ = self_context_;
   switch( event_ )
   {
      case kCFStreamEventHasBytesAvailable:
      {
         [ self_ handleResponseForReadStream: stream_ ];

         static const NSUInteger max_buf_size_ = 1024*4;
         UInt8 buffer_[ max_buf_size_ ];
         CFIndex bytes_read_ = CFReadStreamRead( stream_, buffer_, max_buf_size_ );
         if ( bytes_read_ > 0 )
            [ self_ handleData: buffer_ length: bytes_read_ ];
         break;
      }
      case kCFStreamEventErrorOccurred:
      {
         [ self_ handleResponseForReadStream: stream_ ];

         CFStreamError error_ = CFReadStreamGetError( stream_ );
         NSString* error_description_ = [ NSString stringWithFormat: @"CFStreamError domain: %d", error_.domain ];

         [ self_ closeReadStream ];
         [ self_ handleFinish: [ JFFError errorWithDescription: error_description_
                                                          code: error_.error ] ];
         break;
      }
      case kCFStreamEventEndEncountered:
      {
         [ self_ handleResponseForReadStream: stream_ ];

         [ self_ closeReadStream ];
         [ self_ handleFinish: nil ];
         break;
      }
   }
}

@implementation JFFURLConnection

@synthesize postData = _post_data;
@synthesize headers = _headers;

@synthesize url = _url;
@synthesize responseHandled = _response_handled;
@synthesize didReceiveResponseBlock = _did_receive_response_block;
@synthesize didReceiveDataBlock = _did_receive_data_block;
@synthesize didFinishLoadingBlock = _did_finish_loading_block;

-(void)dealloc
{
   [ self cancel ];

   [ _post_data release ];
   [ _headers release ];

   [ _url release ];
   [ _did_receive_response_block release ];
   [ _did_receive_data_block release ];
   [ _did_finish_loading_block release ];

   [ super dealloc ];
}

-(id)initWithURL:( NSURL* )url_
        postData:( NSData* )data_
         headers:( NSDictionary* )headers_
{
   self = [ super init ];

   if ( self )
   {
      self.url = url_;
      self.postData = data_;
      self.headers = headers_;
   }

   return self;
}

-(void)start
{
   [ self startConnectionWithPostData: self.postData headers: self.headers ];
}

+(id)connectionWithURL:( NSURL* )url_
              postData:( NSData* )data_
           contentType:( NSString* )content_type_
{
   NSDictionary* headers_ = [ NSDictionary dictionaryWithObject: content_type_
                                                         forKey: @"Content-Type" ];
   return [ self connectionWithURL: url_
                          postData: data_
                           headers: headers_ ];
}

+(id)connectionWithURL:( NSURL* )url_
              postData:( NSData* )data_
               headers:( NSDictionary* )headers_
{
   return [ [ [ self alloc ] initWithURL: url_
                                postData: data_
                                 headers: headers_ ] autorelease ];
}

-(void)applyCookiesForHTTPRequest:( CFHTTPMessageRef )http_request_
{
   NSArray* available_cookies_ = [ [ NSHTTPCookieStorage sharedHTTPCookieStorage ] cookiesForURL: self.url ];

   NSDictionary* headers_ = [ NSHTTPCookie requestHeaderFieldsWithCookies: available_cookies_ ];

   for ( NSString* key_ in headers_ )
   {
      NSString* value_ = [ headers_ objectForKey: key_ ];
      CFHTTPMessageSetHeaderFieldValue ( http_request_, (CFStringRef)key_, (CFStringRef)value_ );
   }
}

//TODO add timeout
//TODO test invalid url
//TODO test no internet connection
-(void)startConnectionWithPostData:( NSData* )data_
                           headers:( NSDictionary* )headers_
{
   CFStringRef method_ = (CFStringRef) ( data_ ? @"POST" : @"GET" );

   CFHTTPMessageRef http_request_ = CFHTTPMessageCreateRequest( NULL, method_, (CFURLRef)self.url, kCFHTTPVersion1_1 );

   [ self applyCookiesForHTTPRequest: http_request_ ];

   if ( data_ )
   {
      CFHTTPMessageSetBody ( http_request_, (CFDataRef)data_ );
   }

   for ( NSString* header_ in headers_ )
   {
      CFHTTPMessageSetHeaderFieldValue( http_request_
                                       ,(CFStringRef)header_
                                       ,(CFStringRef)[ headers_ objectForKey: header_ ] );
   }

   //   CFReadStreamCreateForStreamedHTTPRequest( CFAllocatorRef alloc,
   //                                             CFHTTPMessageRef requestHeaders,
   //                                             CFReadStreamRef	requestBody )
   _read_stream = CFReadStreamCreateForHTTPRequest( NULL, http_request_ );
   CFRelease( http_request_ );

   typedef void* (*retain)( void* info_ );
   typedef void (*release)( void* info_ );
   CFStreamClientContext stream_context_ = { 0, self, (retain)CFRetain, (release)CFRelease, NULL };

   CFOptionFlags registered_events_ = kCFStreamEventHasBytesAvailable
      | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
   if ( CFReadStreamSetClient( _read_stream, registered_events_, readStreamCallback, &stream_context_ ) )
   {
      CFReadStreamScheduleWithRunLoop( _read_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
   }

   CFReadStreamOpen( _read_stream );
}

-(void)closeReadStream
{
   if ( _read_stream )
   {
      CFReadStreamUnscheduleFromRunLoop( _read_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
      CFReadStreamClose( _read_stream );
      CFRelease( _read_stream );
      _read_stream = NULL;
   }
}

-(void)closeStreams
{
   [ self closeReadStream ];
}

-(void)clearCallbacks
{
   self.didReceiveResponseBlock = nil;
   self.didReceiveDataBlock = nil;
   self.didFinishLoadingBlock = nil;
}

-(void)cancel
{
   [ self closeStreams ];
   [ self clearCallbacks ];
}

-(void)handleData:( void* )buffer_ length:( NSUInteger )length_
{
   if ( self.didReceiveDataBlock )
   {
      self.didReceiveDataBlock( [ NSData dataWithBytes: buffer_ length: length_ ] );
   }
}

-(BOOL)checkFinished
{
   return NULL == _read_stream/* && _write_stream */;
}

-(void)handleFinish:( NSError* )error_
{
   BOOL finished_ = [ self checkFinished ] || error_ != nil;
   if ( !finished_ )
      return;

   if ( self.didFinishLoadingBlock )
   {
      self.didFinishLoadingBlock( error_ );
   }
   [ self clearCallbacks ];
}

-(void)acceptCookiesForHeaders:( NSDictionary* )headers_
{
   NSArray* cookies_ = [ NSHTTPCookie cookiesWithResponseHeaderFields: headers_ forURL: self.url ];
   for ( NSHTTPCookie* cookie_ in cookies_ )
   {
      [ [ NSHTTPCookieStorage sharedHTTPCookieStorage ] setCookie: cookie_ ];
   }
}

-(void)handleResponseForReadStream:( CFReadStreamRef )stream_
{
   if ( self.responseHandled )
      return;

   CFHTTPMessageRef response_ = (CFHTTPMessageRef)CFReadStreamCopyProperty( stream_
                                                                           , kCFStreamPropertyHTTPResponseHeader );
   if ( response_ )
   {
      self.responseHandled = YES;

      CFDictionaryRef all_headers_ = CFHTTPMessageCopyAllHeaderFields( response_ );
      [ self acceptCookiesForHeaders: (NSDictionary*)all_headers_ ];

      if ( self.didReceiveResponseBlock )
      {
         UInt32 error_code_ = CFHTTPMessageGetResponseStatusCode( response_ );
         JFFURLResponse* url_response_ = [ JFFURLResponse new ];
         url_response_.statusCode = error_code_;

         url_response_.allHeaderFields = (NSDictionary*)all_headers_;

         self.didReceiveResponseBlock( url_response_ );
         self.didReceiveResponseBlock = nil;

         [ url_response_ release ];
      }

      CFRelease( all_headers_ );
      CFRelease( response_ );
   }
}

@end