//
//  MATRequestsQueuePart.m
//  MobileAppTrackeriOS
//
//  Created by Pavel Yurchenko on 7/26/12.
//  Copyright (c) 2012 Scopic Software. All rights reserved.
//

#import "MATRequestsQueuePart.h"

const NSUInteger REQUESTS_MAX_COUNT_IN_PART         =  50;
 

@interface MATRequestsQueuePart()

@property (nonatomic, retain) NSMutableArray * requests;

@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) NSUInteger loadedRequestsCount;

- (NSString*)generateFileName;

@end


@implementation MATRequestsQueuePart

@dynamic index;
@dynamic requestsLimitReached;
@dynamic empty;
@dynamic queuedRequestsCount;

@synthesize modified = modified_;
@synthesize fileName = fileName_;
@synthesize filePathName = filePathName_;

@synthesize requests = requests_;
@synthesize loaded = loaded_;
@synthesize shouldLoadOnRequest = shouldLoadOnRequest_;
@synthesize loadedRequestsCount = loadedRequestsCount_;

- (NSInteger)index
{
    return index_;
}

- (void)setIndex:(NSInteger)index
{
    index_ = index;
    [self generateFileName];
    self.modified = YES;
}

- (BOOL)requestsLimitReached
{
    return ([self.requests count] >= REQUESTS_MAX_COUNT_IN_PART);
}

- (BOOL)empty
{
    return ([self.requests count] == 0);
}

- (NSUInteger)queuedRequestsCount
{
    if (self.requests && [self.requests count] > 0)
    {
        return [self.requests count];
    }
    
    return self.loadedRequestsCount;
}

- (void)setQueuedRequestsCount:(NSUInteger)count
{
    self.loadedRequestsCount = count;
}

+ (id)partWithIndex:(NSInteger)index
{
    return [[[MATRequestsQueuePart alloc] initWithIndex:index] autorelease];
}

- (id)initWithIndex:(NSInteger)index
{
    self = [super init];
    
    if (self)
    {
        index_ = index;
        [self generateFileName];
        modified_ = NO;
        requests_ = [[NSMutableArray alloc] init];
    }
    
    return self;
}


- (BOOL)push:(NSDictionary*)requestData
{
    if (self.requestsLimitReached) { return NO; }
    
    [requests_ addObject:requestData];
    self.modified = YES;
    
    return YES;
}

- (NSDictionary*)pop
{
    NSDictionary * requestData = nil;
    
    /// Load requests from file if should load is set
    if ([requests_ count] == 0 && self.shouldLoadOnRequest)
    {
        [self load];        
    }     
    
    if ([requests_ count] > 0)
    {
        requestData = [requests_ objectAtIndex:0];
        
        [requestData retain];
        
        [requests_ removeObjectAtIndex:0];        
        self.modified = YES;
    }
    
    return [requestData autorelease];
}

- (BOOL)load
{
    if (!self.loaded)
    {
        NSData * fileData = [NSData dataWithContentsOfFile:self.filePathName];
        if (fileData)
        {
            NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:fileData];
            [xmlParser setDelegate:self];
            [xmlParser parse];
            
            self.loaded = YES;
            self.shouldLoadOnRequest = NO;

            [xmlParser release]; xmlParser = nil;
        }
    }
    
    return self.loaded;
}

- (void)save
{
    NSError * error = nil;
    
    // serialize the request queue
    NSMutableString *strDescr = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<QueuePart>"];
    
    for (NSDictionary * request in self.requests)
    {
        /// Store it's information
        [strDescr appendFormat:@"<Request url=\"%@\" json=\"%@\"></Request>", [request valueForKey:@"url"], [request valueForKey:@"json"]];
    }
    
    [strDescr appendString:@"</QueuePart>"];
    
    // store the serialized request data to a file
    [strDescr writeToFile:self.filePathName atomically:YES encoding:NSUTF8StringEncoding error:&error];    
    
    if (error)
    {
        NSLog(@"%@", [error localizedDescription]);
    }
    
    self.modified = NO;
}

- (void)dealloc
{
    self.requests = nil;
    self.fileName = nil;
    self.filePathName = nil;
    [super dealloc];
}

- (NSString*)generateFileName
{
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];

    self.fileName = [NSString stringWithFormat:@"queue_part_%d.xml", self.index];
    
    NSString * filePathName = [documentsDirectory stringByAppendingPathComponent:@"queue"];
    filePathName = [filePathName stringByAppendingPathComponent:self.fileName];    
    self.filePathName = filePathName;
    
    return self.fileName;
}

- (NSComparisonResult) indexComparator:(MATRequestsQueuePart*)other
{
    if (self.index < other.index)
    {
        return NSOrderedAscending;
    }
    else if (self.index > other.index)
    {
        return NSOrderedDescending;
    }

    return NSOrderedSame;
}

#pragma mark -
#pragma mark NSXMLParser Delegate Methods

// sent when the parser finds an element start tag.
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if(0 == [elementName compare:@"Request"])
    {
        [self push:[NSDictionary dictionaryWithDictionary:attributeDict]];
    }
}

@end