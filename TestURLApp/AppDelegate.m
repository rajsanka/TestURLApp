//
//  AppDelegate.m
//  TestURLApp
//
//  Created by Raji Sankar on 11/10/22.
//  Copyright © 2022 Raji Sankar. All rights reserved.
//

#import "AppDelegate.h"

@import HTMLReader;

@interface AppDelegate ()

@end

@interface DataHandler : NSObject {
    
}

- (void)handleTitle: (NSString *)title;
- (void)handleContent: (NSString *)element content:(NSString *)content index:(int)index;

@end


@interface WebCrawl:NSObject {
    NSMutableData *_responseData;
}

- (id)init;
- (void)crawlURL:(NSString *)url handler:(DataHandler *)handler;
@end

@interface URLScrap:NSObject {
    HTMLDocument *_document;
}

- (id)initWithDocument:(HTMLDocument *)document;
- (void)scrapTitle:(void (^)(NSString *title))titleHandler;
- (void)scrapContent:(NSString *)element contentHandler:(void (^) (NSString *element, NSString *textContent, int index))contentHandler;
- (void)scrapAttributes:(NSString *)element attributes:(NSArray *)attributes attributeHandler:(void (^) (NSString *element, int index, NSString *name, NSString *value))attributeHandler;
- (void)scrapContentWithId:(NSString *)name elemType:(NSString *)elemType contentHandler:(void (^)(HTMLElement *element, NSString *name, NSString *type, int index))contentHandler;

@end

@implementation WebCrawl

- (id)init {
    self = [super init];
    return self;
}

- (void)crawlURL:(NSString *)url handler:(DataHandler *)handler {
    NSURL *nsurl = [NSURL URLWithString:url];
    //create a request for the URL
    NSURLRequest *request = [NSURLRequest requestWithURL:nsurl];
    //singleton shared session provided by NSSession. We use this here, given it is a static page.
    NSURLSession * sess = [NSURLSession sharedSession];
    //creates and calls the completionHandler block when contents are loaded
    NSURLSessionDataTask *task = [sess dataTaskWithRequest:request
                                         completionHandler:
        ^(NSData *data, NSURLResponse *response, NSError *error) {

         if (error) {
             //handle transport errors here
             NSLog(@"Error in transport %@", error);
             return;
         }
         
         NSHTTPURLResponse *resp = (NSHTTPURLResponse *)response;
         //handle other codes
         if ([resp statusCode] != 200) {
             NSLog(@"HTTP Error %d", (int)[resp statusCode]);
             return;
         }
         self->_responseData = [[NSMutableData alloc] init];
         [self->_responseData appendData:data];
         NSString *contentType = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
            contentType = headers[@"Content-Type"];
        }
        HTMLDocument *home = [HTMLDocument documentWithData:data
                                          contentTypeHeader:contentType];
        
        URLScrap *scrap = [[URLScrap alloc]initWithDocument:home];
        [scrap scrapTitle:
          ^(NSString *title) {
             //NSLog(@"%@", title);
             [handler handleTitle:title];
         }];
        [scrap scrapContent:@"span[class=\"mw-headline\"]" contentHandler:
          ^(NSString *element, NSString *content, int index) {
             //NSLog(@"%@:%@", element, content);
             [handler handleContent:element content:content index:index];
         }];
        
        /*HTMLElement *div = [home firstNodeMatchingSelector:@"title"];
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *title = [div.textContent stringByTrimmingCharactersInSet:whitespace];
        NSLog(@"%@", title);

        NSArray *links = [home nodesMatchingSelector:@"a"];
        NSEnumerator *enumerate = [links objectEnumerator];
        HTMLElement *alink;
        while (alink = [enumerate nextObject]) {
            NSString *href = [alink.attributes objectForKey:@"href"];

             //process the <a> nodes here
             NSLog(@"%@ %@", [alink textContent], href);
        }*/
        
    }];
    [task resume];
}

@end


@implementation URLScrap

- (id)initWithDocument:(HTMLDocument *)document {
    self->_document = document;
    return self;
}

- (void)scrapTitle:(void (^) (NSString *title))titleHandler {
    HTMLElement *div = [self->_document firstNodeMatchingSelector:@"title"];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *title = [div.textContent stringByTrimmingCharactersInSet:whitespace];
    //NSLog(@"%@", title);
    titleHandler(title);
}


- (void)scrapContent:(NSString *)element contentHandler:(void (^)(NSString * element, NSString * content, int index))contentHandler {
    NSArray *tables = [self->_document nodesMatchingSelector:@"table"];
    NSEnumerator *enumerate = [tables objectEnumerator];
    HTMLElement *table;
    int count = 0;
    while (table = [enumerate nextObject]) {
        //NSLog(@"%@", [table textContent]);
        contentHandler(element, [table textContent], count);
        count++;
    }

}

- (void)scrapContentWithId:(NSString *)name elemType:(NSString *)elemType contentHandler:(void (^)(HTMLElement *element, NSString *name, NSString *type, int index))contentHandler {
    NSString *search = [NSString stringWithFormat:@"%@[id=\"%@\"]", elemType, name];
    NSArray *elems = [self->_document nodesMatchingSelector:search];
    NSEnumerator *enumerate = [elems objectEnumerator];
    HTMLElement *elem;
    int count = 0;
    while (elem = [enumerate nextObject]) {
        //NSLog(@"%@", [table textContent]);
        contentHandler(elem, name, elemType, count);
        count++;
    }
}

- (void)scrapAttributes:(NSString *)element attributes:(NSArray *)attributes
       attributeHandler:(void (^)(NSString *, int, NSString *, NSString *))attributeHandler {
    NSArray *elems = [self->_document nodesMatchingSelector: element];
    NSEnumerator *enumerate = [elems objectEnumerator];
    HTMLElement *anElem;
    int count = 0;
    while (anElem = [enumerate nextObject]) {
        NSEnumerator *attrEnumerate = [attributes objectEnumerator];
        NSString *attr;
        while (attr = [attrEnumerate nextObject]) {
            NSString *attrval = [anElem.attributes objectForKey:attr];
            NSLog(@"%@ %@", attr, attrval);
            attributeHandler(element, count, attr, attrval);
        }
        count++;
    }

}

@end

@implementation DataHandler

- (void)handleTitle: (NSString *)title {
    NSLog(@"In Handler: %@", title);
}

- (void)handleContent: (NSString *)element content:(NSString *)content index:(int)index {
    NSLog(@"In Handler: %@ %@ %d", element, content, index);
}

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    DataHandler *handle = [DataHandler alloc];
    WebCrawl *webscrap = [[WebCrawl alloc]init];
    [webscrap crawlURL:@"https://en.wikipedia.org/wiki/Physics" handler:handle];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
