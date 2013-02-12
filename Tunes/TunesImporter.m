//
//  TunesImporter.m
//  Tunes
//
//  Created by Jens Alfke on 7/20/11.
//  Copyright 2011-2013 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.
//

#import "TunesImporter.h"
#import <CouchbaseLite/CouchbaseLite.h>


#define kBatchSize 500


@implementation TunesImporter


+ (NSURL*) currentITunesLibraryURL {
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSArray *dbs = [[NSUserDefaults standardUserDefaults]
                     persistentDomainForName: @"com.apple.iApps"][@"iTunesRecentDatabases"];
    if( [dbs count] > 0 ) {
        NSURL *url = [NSURL URLWithString: dbs[0]];
        if( [url isFileURL] )
            return url;
    }
    NSLog(@"Couldn't find location of iTunes library; iTunesRecentDatabases pref = %@",
         [dbs description]);
    return nil;
}


- (id) initWithLibraryURL: (NSURL*)libraryURL database: (CBLDatabase*)database {
    self = [super init];
    if (self) {
        _libraryURL = libraryURL;
        _database = database;
    }
    
    return self;
}


- (void) addDocument: (NSMutableDictionary*)properties withID: (NSString*)documentID {
    NSError* error;
    if (![[_database documentWithID: documentID] putProperties: properties error: &error])
        NSAssert(NO, @"Couldn't save doc: %@", error);
}


- (BOOL) run {
    @autoreleasepool {
        NSDictionary* library = [NSDictionary dictionaryWithContentsOfURL: _libraryURL];
        if (![library isKindOfClass: [NSDictionary class]])
            return NO;
        
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        __block unsigned count = 0;
        [_database inTransaction: ^BOOL {
            for (NSDictionary* track in [library[@"Tracks"] allValues]) {
                NSString* trackType = track[@"Track Type"];
                if (![trackType isEqual: @"File"] && ![trackType isEqual: @"Remote"])
                    continue;
                @autoreleasepool {
                    NSString* documentID = track[@"Persistent ID"];
                    if (!documentID)
                        continue;
                    NSMutableDictionary* props = [NSMutableDictionary dictionary];
                    for(NSString* key in _keysToCopy) {
                        id value = track[key];
                        if (value)
                            props[key] = value;
                    }
                    ++count;
                    /*NSLog(@"#%4u: %@ \"%@\"",
                     count, [props objectForKey: @"Artist"], [props objectForKey: @"Name"]);*/
                    [self addDocument: props withID: documentID];
                }
            }
            return YES;
        }];
        NSLog(@"Importing %u tracks took %.3f sec", count, (CFAbsoluteTimeGetCurrent() - startTime));
    }
    return YES;
}


@end
